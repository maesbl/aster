import Foundation
import CoreGraphics

final class DesktopFixture: DesktopBackend {
    var captures = 0
    var actions: [DesktopAction] = []
    var beforeAction: (() -> Void)?
    let geometry = ScreenGeometry(displayID: 1, frame: CGRect(x: -1512, y: 0, width: 1512, height: 982), imageWidth: 756, imageHeight: 491)
    func capture() async throws -> DesktopFrame { captures += 1; return .init(jpeg: Data("fixture-frame-\(captures)".utf8), geometry: geometry, context: "Excel · isolated test fixture") }
    @MainActor func perform(_ action: DesktopAction, geometry: ScreenGeometry, allowed: @escaping @MainActor () -> Bool) async throws { beforeAction?(); try action.validate(geometry: geometry, active: allowed()); actions.append(action) }
}
final class DesktopMockProtocol: URLProtocol {
    static var handler: (URLRequest) throws -> [String: Any] = { _ in [:] }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let object = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed); client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: object)); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
    static func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream { stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating: 0, count: 4096); while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(buffer, count: count) } }
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
@main struct ComputerTests {
    static func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
    static func response(_ id: String, action: String, extra: [String: Any] = [:], duplicated: Bool = false) throws -> [String: Any] {
        var arguments: [String: Any] = ["action": action, "explanation": "Paso \(id)", "x": NSNull(), "y": NSNull(), "text": NSNull(), "key": NSNull(), "direction": NSNull(), "amount": NSNull(), "app": NSNull(), "reason": NSNull()]; arguments.merge(extra) { _, new in new }
        let call: [String: Any] = ["type": "function_call", "name": "aster_desktop", "call_id": "call-" + id, "arguments": String(decoding: try JSONSerialization.data(withJSONObject: arguments), as: UTF8.self)]
        return ["id": id, "status": "completed", "output": duplicated ? [call, call] : [call]]
    }
    @MainActor static func wait(_ controller: ComputerController) async throws { let end = Date().addingTimeInterval(5); while controller.active && Date() < end { try await Task.sleep(for: .milliseconds(20)) }; check(!controller.active, "Fixture must finish within bounded timeout") }
    @MainActor static func main() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("aster-desktop-key-" + UUID().uuidString); try "OPENAI_API_KEY=isolated-fixture\n".write(to: file, atomically: true, encoding: .utf8); defer { try? FileManager.default.removeItem(at: file) }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [DesktopMockProtocol.self]
        let api = try AgentAPI(environmentFile: file.path, baseURL: "https://aster.test/v1", transport: URLSession(configuration: config))
        let fixture = DesktopFixture(); let midpoint = try fixture.geometry.point(x: 378, y: 245.5)
        check(midpoint == CGPoint(x: -756, y: 491), "Retina and displays left of main map screenshot pixels to global points")
        for point in [(-1.0, 20.0), (756.0, 20.0), (20.0, Double.infinity)] { do { _ = try fixture.geometry.point(x: point.0, y: point.1); fatalError("Invalid point should fail") } catch {} }
        check(DesktopKeys.parse("cmd+shift+s") != nil && DesktopKeys.parse("cmd+unknown") == nil, "Only explicit supported key chords are allowed")
        var requests = 0
        DesktopMockProtocol.handler = { request in
            requests += 1; let body = try DesktopMockProtocol.body(request)
            check(request.url?.path == "/v1/responses" && request.value(forHTTPHeaderField: "OpenAI-Beta") == nil, "Desktop uses the documented Responses API without the Agents beta header")
            check(body["parallel_tool_calls"] as? Bool == false, "One visible action at a time")
            let input = body["input"] as! [[String: Any]]; let content = input.last!["content"] as! [[String: Any]]
            let image = content[1]["image_url"] as! String
            check(image.hasSuffix(Data("fixture-frame-\(requests)".utf8).base64EncodedString()), "Each model step sees a fresh screenshot after previous action")
            if requests == 1 { check(body["previous_response_id"] == nil, "New run starts independently"); return try response("response1", action: "click", extra: ["x": 100, "y": 120]) }
            check(body["previous_response_id"] as? String == "response1", "Follow-up retains response identity")
            check(input[0]["type"] as? String == "function_call_output" && input[0]["call_id"] as? String == "call-response1", "Return exact tool call result before next screenshot")
            return try response("response2", action: "finish", extra: ["text": "Tabla comprobada."])
        }
        let controller = ComputerController(); var finished: ComputerRun?; controller.onFinished = { finished = $0 }
        controller.start("Completar una tabla", agent: Specialist.defaults.last!, settings: .init(), api: api, backend: fixture, needsPermissions: false); try await wait(controller)
        check(requests == 2 && fixture.actions.count == 1 && fixture.captures == 2 && controller.result == "Tabla comprobada." && finished?.agentID == "study", "Capture, action, verification, narration and durable run result complete one flow")
        DesktopMockProtocol.handler = { _ in try response("duplicate", action: "click", extra: ["x": 10, "y": 10], duplicated: true) }
        let blocked = ComputerController(); let untouched = DesktopFixture(); blocked.start("Invalid fixture", agent: Specialist.defaults.last!, settings: .init(), api: api, backend: untouched, needsPermissions: false); try await wait(blocked)
        check(!blocked.error.isEmpty && untouched.actions.isEmpty, "Malformed parallel actions never move the cursor")
        DesktopMockProtocol.handler = { _ in try response("paused", action: "click", extra: ["x": 10, "y": 10]) }
        let cancelled = ComputerController(); let pausedFixture = DesktopFixture(); pausedFixture.beforeAction = { cancelled.stop() }
        cancelled.start("Cancellation fixture", agent: Specialist.defaults.last!, settings: .init(), api: api, backend: pausedFixture, needsPermissions: false); try await wait(cancelled)
        check(pausedFixture.actions.isEmpty, "Cancellation at action boundary prevents all input")
        let long = String(repeating: "Una frase clara. ", count: 500); let chunks = VoiceText.chunks(long)
        check(chunks.count > 1 && chunks.allSatisfy { $0.count <= 1700 } && chunks.joined(separator: " ") == long.trimmingCharacters(in: .whitespaces), "Voice segmentation preserves text and stays below API limits")
        check(VoiceText.clean("## Hola **mundo**\n```swift\nsecret code\n```\n[Fuente](https://example.com)").contains("Fuente") && !VoiceText.clean("```swift\nsecret code\n```").contains("secret"), "Spoken text omits code and reads link labels")
        print("PASS: Retina/multi-display coordinates, input bounds, key validation, real vision/function protocol, fresh-screen verification, single-action guard, cancellation, step history and multilingual voice segmentation. No native input or private capture was performed.")
    }
}
