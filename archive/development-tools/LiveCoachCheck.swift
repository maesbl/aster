import Foundation
@main struct LiveCoachCheck {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let api = try AgentAPI(environmentFile: root.appendingPathComponent(".env.local").path)
        let frame = DesktopFrame(jpeg: try Data(contentsOf: root.appendingPathComponent("work/aster-vision-fixture.jpg")), geometry: .init(displayID: 1, frame: CGRect(x: 0, y: 0, width: 1280, height: 800), imageWidth: 1280, imageHeight: 800), context: "Synthetic test image, not a private screen.")
        let response = try await api.response(["model": "gpt-6-luna", "input": [ComputerPrompt.screenshotInput(frame, instruction: "Describe en español el único botón visible y dibuja un rectángulo alrededor del botón. Coordenadas normalizadas 0..1, origen arriba a la izquierda. Responde con aster_explain_screen y máximo 25 palabras de explicación.")], "tools": [CoachAnswer.tool], "tool_choice": ["type": "function", "name": "aster_explain_screen"], "parallel_tool_calls": false, "reasoning": ["effort": "low"], "max_output_tokens": 1600])
        let answer = try CoachAnswer.decode(response)
        guard answer.answer.uppercased().contains("TOTAL"), let rectangle = answer.marks.first(where: { $0.kind == "rectangle" }), rectangle.points.count >= 2 else { fatalError("Vision did not explain and annotate the visible target") }
        let a = rectangle.points[0], b = rectangle.points[1]
        guard min(a.x,b.x) < 0.35, max(a.x,b.x) > 0.5, min(a.y,b.y) < 0.4, max(a.y,b.y) > 0.45, max(a.x,b.x) < 0.65, max(a.y,b.y) < 0.6 else { fatalError("Annotation missed the visible button") }
        try JSONEncoder().encode(answer).write(to: root.appendingPathComponent("work/coach-vision-live-result.json"), options: .atomic)
        print("PASS: real vision read TOTAL and returned valid normalized rectangle coordinates enclosing the target. Synthetic fixture only; no desktop capture.")
    }
}
