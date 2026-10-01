import Foundation
import CoreGraphics

struct ScreenPoint: Codable, Equatable { var x: Double; var y: Double }
struct ScreenMark: Codable {
    var kind: String
    var points: [ScreenPoint]
    var label: String
    func validate() throws {
        guard ["circle", "rectangle", "arrow", "line", "text"].contains(kind), !points.isEmpty, points.count <= 128, label.count <= 160,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }),
              kind == "text" || points.count >= 2 else { throw AsterError.message("Las marcas recibidas no corresponden a la pantalla.") }
    }
}
struct CoachAnswer: Codable {
    var answer: String
    var marks: [ScreenMark]
    func validate() throws {
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, answer.count <= 18000, marks.count <= 12 else { throw AsterError.message("No se ha recibido una explicación válida.") }
        try marks.forEach { try $0.validate() }
    }
    static let tool: [String: Any] = {
        let point: [String: Any] = ["type": "object", "properties": ["x": ["type": "number"], "y": ["type": "number"]], "required": ["x", "y"], "additionalProperties": false]
        let mark: [String: Any] = ["type": "object", "properties": ["kind": ["type": "string", "enum": ["circle", "rectangle", "arrow", "line", "text"]], "points": ["type": "array", "items": point], "label": ["type": "string"]], "required": ["kind", "points", "label"], "additionalProperties": false]
        return ["type": "function", "name": "aster_explain_screen", "description": "Explain the screen and optionally draw teaching marks. Normalized coordinates 0..1, origin top-left of the supplied screenshot. For circle/rectangle use two opposite bounding corners; arrow uses start and target; line uses a polyline; text uses one point. Maximum 12 marks, 128 points each. This does not click or edit the app.", "parameters": ["type": "object", "properties": ["answer": ["type": "string"], "marks": ["type": "array", "items": mark]], "required": ["answer", "marks"], "additionalProperties": false], "strict": true]
    }()
    static func decode(_ response: [String: Any]) throws -> CoachAnswer {
        guard response["status"] as? String == "completed", let items = response["output"] as? [[String: Any]] else { throw AsterError.message("La explicación no se ha completado. Vuelve a intentarlo.") }
        let calls = items.filter { $0["type"] as? String == "function_call" }
        guard calls.count == 1, calls[0]["name"] as? String == "aster_explain_screen", let raw = calls[0]["arguments"] as? String else { throw AsterError.message("No se ha recibido una explicación para esta pantalla.") }
        let answer = try JSONDecoder().decode(CoachAnswer.self, from: Data(raw.utf8)); try answer.validate(); return answer
    }
}
