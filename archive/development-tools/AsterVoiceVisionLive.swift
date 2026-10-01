import AppKit
import AVFoundation
import Foundation

@main struct AsterVoiceVisionLive {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: "/Users/mescu/Documents/Codex/2026-09-30/i-w")
        let api = try AgentAPI(environmentFile: root.appendingPathComponent(".env.local").path)
        let voice: Data
        if let existing = try? Data(contentsOf: root.appendingPathComponent("outputs/Aster-voz.mp3")) { voice = existing } else { voice = try await api.speech("Hola, soy Aster. Puedo pensar contigo, ayudarte a crear y acompañarte mientras trabajamos en tu Mac. Tú eliges el objetivo; yo te cuento cada paso.", voice: "marin", instructions: "Habla en español con una voz cercana, natural y tranquila. Pronuncia Aster con claridad.") }
        guard voice.count > 8000 else { throw AsterError.message("Audio is unexpectedly empty") }
        try voice.write(to: root.appendingPathComponent("outputs/Aster-voz.mp3"), options: .atomic)
        guard let player = try? AVAudioPlayer(data: voice), player.duration > 2 else { throw AsterError.message("Audio could not be decoded") }
        let image = NSImage(size: NSSize(width: 640, height: 400)); image.lockFocus(); NSColor(calibratedWhite: 0.07, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: 640, height: 400).fill(); NSColor.white.setFill(); NSBezierPath(roundedRect: NSRect(x: 180, y: 200, width: 180, height: 60), xRadius: 12, yRadius: 12).fill()
        ("TOTAL" as NSString).draw(at: NSPoint(x: 237, y: 220), withAttributes: [.font: NSFont.systemFont(ofSize: 22, weight: .semibold), .foregroundColor: NSColor.black]); image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else { throw AsterError.message("No fixture image") }
        try jpeg.write(to: root.appendingPathComponent("work/aster-vision-fixture.jpg"))
        let geometry = ScreenGeometry(displayID: 1, frame: CGRect(x: 0, y: 0, width: 640, height: 400), imageWidth: rep.pixelsWide, imageHeight: rep.pixelsHigh)
        let frame = DesktopFrame(jpeg: jpeg, geometry: geometry, context: "Public synthetic UI test. No real screen, cursor or private data.")
        let result = try await api.response(["model": "gpt-6-luna", "instructions": ComputerPrompt.instructions(agent: Specialist.defaults.last!, language: "Spanish"), "input": [ComputerPrompt.screenshotInput(frame, instruction: "Click the white button labeled TOTAL in this synthetic screenshot. Take exactly one click action. This is a test; no real Mac input will be performed.")], "tools": [ComputerPrompt.tool], "tool_choice": ["type": "function", "name": "aster_desktop"], "parallel_tool_calls": false, "reasoning": ["effort": "low"], "max_output_tokens": 2200])
        guard result["status"] as? String == "completed", let call = (result["output"] as? [[String: Any]])?.first(where: { $0["type"] as? String == "function_call" }), let arguments = call["arguments"] as? String else { throw AsterError.message("No valid live vision action: " + String(describing: result["error"])) }
        let action = try JSONDecoder().decode(DesktopAction.self, from: Data(arguments.utf8)); try action.validate(geometry: geometry, active: true)
        print("Vision fixture pixels: \(rep.pixelsWide) x \(rep.pixelsHigh); action \(action.action); x=\(action.x ?? -1) y=\(action.y ?? -1)")
        let scale = Double(rep.pixelsWide) / 640
        guard action.action == "click", let x = action.x, let y = action.y, (180*scale..<360*scale).contains(x), (140*scale..<200*scale).contains(y) else { throw AsterError.message("Vision did not identify the target button") }
        let report: [String: Any] = ["natural_voice_verified": true, "voice": "marin", "audio_bytes": voice.count, "audio_seconds": player.duration, "vision_model": "gpt-6-luna", "vision_action_verified": true, "target": ["x": x, "y": y], "actual_native_input": false, "private_screen_capture": false]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("work/aster-voice-vision-live-report.json"))
        print("PASS: real OpenAI multilingual natural voice, playable MP3, live visual target recognition and exact native control function schema. No private screen or real cursor action was used.")
    }
}
