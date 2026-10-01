import AppKit
import Foundation
import UniformTypeIdentifiers

final class HealthExportReader: NSObject, XMLParserDelegate {
    private var latest: [String: HealthMetric] = [:]
    private var records = 0
    private var failure: String?
    static let labels = ["HKQuantityTypeIdentifierStepCount": "Pasos", "HKQuantityTypeIdentifierHeartRate": "Frecuencia cardiaca", "HKQuantityTypeIdentifierRestingHeartRate": "Frecuencia cardiaca en reposo", "HKQuantityTypeIdentifierBodyMass": "Peso", "HKQuantityTypeIdentifierHeight": "Altura", "HKQuantityTypeIdentifierActiveEnergyBurned": "Energía activa", "HKQuantityTypeIdentifierAppleExerciseTime": "Tiempo de ejercicio", "HKQuantityTypeIdentifierWalkingRunningDistance": "Distancia andando y corriendo", "HKQuantityTypeIdentifierOxygenSaturation": "Oxígeno en sangre", "HKQuantityTypeIdentifierRespiratoryRate": "Frecuencia respiratoria", "HKQuantityTypeIdentifierHeartRateVariabilitySDNN": "Variabilidad de frecuencia cardiaca", "HKCategoryTypeIdentifierSleepAnalysis": "Sueño"]
    static func read(_ url: URL) throws -> HealthSnapshot {
        let size = (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
        guard size <= 512 * 1024 * 1024, let parser = XMLParser(contentsOf: url) else { throw AsterError.message("Selecciona el archivo export.xml de Apple Salud, de hasta 512 MB.") }
        let delegate = HealthExportReader(); parser.delegate = delegate; parser.shouldResolveExternalEntities = false; parser.externalEntityResolvingPolicy = .never
        guard parser.parse(), !delegate.latest.isEmpty else { throw AsterError.message(delegate.failure ?? "No se han encontrado registros de Apple Salud en ese archivo XML.") }
        return .init(imported: Date(), filename: url.lastPathComponent, metrics: delegate.latest.values.sorted { $0.label < $1.label }, recordCount: delegate.records)
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        guard elementName == "Record" else { return }; records += 1
        guard records <= 3_000_000 else { failure = "El archivo contiene demasiados registros para esta importación. Exporta un periodo más corto."; parser.abortParsing(); return }
        guard let type = attributes["type"], let label = Self.labels[type], let value = attributes["value"], let date = attributes["endDate"].flatMap(Self.date) else { return }
        if latest[type] == nil || latest[type]!.date < date { latest[type] = .init(id: type, label: label, value: String(value.prefix(120)), unit: attributes["unit"] ?? "", date: date, source: String((attributes["sourceName"] ?? "Apple Salud").prefix(120))) }
    }
    private static func date(_ value: String) -> Date? {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"; return formatter.date(from: value)
    }
}
extension AsterStore {
    func importHealth() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.xml]; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.message = L("Elige export.xml de la exportación de Apple Salud en tu iPhone.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do { let snapshot = try await Task.detached(priority: .utility) { try HealthExportReader.read(url) }.value; state.health = snapshot; save(); notice = "Datos de Apple Salud importados. Puedes preguntarle a Aster por los últimos registros." }
            catch { notice = error.localizedDescription }
        }
    }
}
