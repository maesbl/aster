import Foundation

@main struct ProtocolTests {
    static func event(_ json: String) -> AgentEvent? { AgentEvent.decode(Data(json.utf8)) }
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
    static func main() throws {
        if case .completed? = event(#"{"type":"agent.session.turn.completed","turn":{"id":"root","subagent_id":null}}"#) {} else { fatalError("Root completion must terminate the intended turn") }
        check(event(#"{"type":"agent.session.turn.completed","turn":{"subagent_id":"worker"}}"#) == nil, "Subagent completion must not finish root")
        check(event(#"{"type":"agent.session.idle"}"#) == nil, "Idle is not completion")
        if case .failure(let text)? = event(#"{"type":"agent.session.turn.failed","turn":{"subagent_id":null,"error":{"code":"usage_limit_exceeded","message":"Billing limit"}}}"#) { check(text.contains("facturación"), "Translate billing failure") } else { fatalError("Root failure must surface") }
        if case .activity? = event(#"{"type":"agent.session.turn.failed","turn":{"subagent_id":"worker","error":{"message":"Failed"}}}"#) {} else { fatalError("A worker failure should not silently replace root outcome") }
        check(event(Data([0xFF]).base64EncodedString()) == nil, "Reject malformed JSON")
        var parser = SSEParser(); var output: [String] = []; var completions = 0
        let stream = ": keepalive\r\nevent: delta\r\ndata: {\"type\":\"agent.session.turn.output_text.delta\",\"item_id\":\"a\",\"delta\":\"Hola, creación ✨\"}\r\n\r\ndata: {\"type\":\"agent.session.turn.completed\",\"turn\":{\"subagent_id\":null}}\n\n"
        for byte in stream.utf8 {
            if let value = try parser.feed(byte) {
                if case .text(_, let text, _) = value { output.append(text) }
                if case .completed = value { completions += 1 }
            }
        }
        check(output == ["Hola, creación ✨"] && completions == 1, "Decode UTF8, CRLF and separate event frames")
        var identities = SSEParser()
        for byte in #"""
        data: {"type":"agent.session.turn.output_text.delta","turn_id":"intended","subagent_id":null,"delta":"Root"}

        data: {"type":"agent.session.turn.output_text.delta","turn_id":"worker-turn","subagent_id":"worker","delta":"Worker"}

        """#.utf8 { _ = try identities.feed(byte) }; _ = identities.finish()
        check(identities.rootTurnID == "intended", "Persist real output metadata without replacing root identity with worker turn")
        var multiline = SSEParser()
        check(multiline.append("data: {\"type\":") == nil, "Multiline waits for complete frame")
        _ = multiline.append("data: \"agent.session.idle\"}")
        check(multiline.append("") == nil, "Idle multiline event does not indicate success")
        var truncated = SSEParser()
        for b in #"data: {"type":"agent.session.turn.cancelled","turn":{"subagent_id":null}}"#.utf8 { _ = try truncated.feed(b) }
        if case .cancelled? = truncated.finish() {} else { fatalError("Recover final frame without newline") }
        var state = SavedState(); state.specialists[0].style = .init(form: .orbit, tint: .mint, size: 184, effects: false, motion: false)
        state.missions = [.init(title: "Misión", specialistID: "director", messages: [.init(role: "user", text: "Crear")], sessionID: "session", turnID: "turn", status: "Por recuperar")]
        let restored = try JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(state))
        check(restored.specialists[0].style == state.specialists[0].style, "Persist customization")
        check(restored.missions[0].sessionID == "session" && restored.missions[0].turnID == "turn", "Keep remote identity for recovery")
        check(!restored.preferences.watchMail && !restored.preferences.watchCalendar && !restored.preferences.autonomous, "Default private connectors and autonomous billing off")
        print("PASS: root outcomes, subagents, billing errors, UTF8/CRLF event frames, truncated frame recovery, persistence and default consent state.")
    }
}
