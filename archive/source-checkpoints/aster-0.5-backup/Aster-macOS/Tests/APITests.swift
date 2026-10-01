import Foundation

final class MockAgentProtocol: URLProtocol {
    static var handler: (URLRequest) throws -> (Int, [String: Any]) = { _ in (500, [:]) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, object) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: object))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
@main struct APITests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
    static func main() async throws {
        var settings = IntelligenceSettings(); settings.delegation = true; settings.maxAgents = 3
        for specialist in Specialist.defaults {
            let configuration = AgentAPI.configuration(for: specialist, settings: settings)
            let delegation = configuration["multi_agent"] as! [String: Any]
            check(delegation["enabled"] as? Bool == (specialist.id == "director"), "Only the director coordinates subagents")
            if specialist.id == "director" { check(delegation["max_concurrent_subagents"] as? Int == 3, "Enabled delegation uses the selected concurrency") }
            else { check(delegation["max_concurrent_subagents"] == nil, "The API rejects concurrency when delegation is disabled") }
        }
        settings.delegation = false
        let solo = AgentAPI.configuration(for: Specialist.defaults[0], settings: settings)["multi_agent"] as! [String: Any]
        check(solo["enabled"] as? Bool == false && solo["max_concurrent_subagents"] == nil, "The director also supports delegation disabled")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("aster-mock-" + UUID().uuidString)
        try "OPENAI_API_KEY=placeholder-for-isolated-tests\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [MockAgentProtocol.self]
        let api = try AgentAPI(environmentFile: file.path, baseURL: "https://aster.test/v1", transport: URLSession(configuration: config))
        MockAgentProtocol.handler = { request in
            check(request.value(forHTTPHeaderField: "OpenAI-Beta") == "agents=v1", "Raw HTTP needs the public beta header")
            return (200, ["data": [["id": "gpt-6-astra"]]])
        }
        let models = try await api.availableModels(); check(models == ["gpt-6-astra"], "Model access check uses current API data")
        var requests: [String] = []
        MockAgentProtocol.handler = { request in
            let url = request.url!; requests.append(url.absoluteString)
            if url.path.hasSuffix("/turns") {
                if url.query?.contains("after=") == true { return (200, ["data": [["id": "intended-turn", "status": "completed", "subagent_id": NSNull()]], "has_more": false]) }
                return (200, ["data": [["id": "other-turn", "status": "completed", "subagent_id": NSNull()]], "has_more": true, "last_id": "cursor-turn"])
            }
            if url.path.hasSuffix("/items") {
                if url.query?.contains("after=") == true { return (200, ["data": [["role": "assistant", "turn_id": "intended-turn", "content": [["text": "Segundo párrafo"]]]], "has_more": false]) }
                return (200, ["data": [["role": "assistant", "turn_id": "other-turn", "content": [["text": "No mezclar"]]], ["role": "assistant", "turn_id": "intended-turn", "subagent_id": "worker", "content": [["text": "No incluir trabajador"]]], ["role": "assistant", "turn_id": "intended-turn", "content": [["text": "Primero"]]]], "has_more": true, "last_id": "cursor-item"])
            }
            return (404, ["error": ["message": "Missing fixture"]])
        }
        let restored = try await api.recover("session", turnID: "intended-turn")
        check(restored.0 == "completed" && restored.1 == "Primero\n\nSegundo párrafo", "Recovery follows pagination and isolates root output of the exact turn")
        check(requests.count == 4, "Both turns and items must follow pagination")
        MockAgentProtocol.handler = { _ in (200, ["data": [["id": "different-turn", "status": "completed"]], "has_more": false]) }
        do { _ = try await api.recover("session", turnID: "missing-turn"); fatalError("Must not substitute an unrelated turn") } catch {}
        MockAgentProtocol.handler = { request in
            if request.url?.query?.contains("after=") == true { return (200, ["data": [["id": "new", "path": "/workspace/outputs/new.md", "turn_id": "intended"]], "has_more": false]) }
            return (200, ["data": [["id": "old", "path": "/workspace/outputs/old.md", "turn_id": "old-turn"]], "has_more": true, "last_id": "artifact-cursor"])
        }
        let files = try await api.artifacts("sid", turnID: "intended")
        check(files.count == 1 && files[0].id == "new" && files[0].sessionID == "sid", "Artifact downloads retain owning session and intended turn")
        MockAgentProtocol.handler = { request in
            let body = try JSONSerialization.jsonObject(with: request.httpBody ?? request.httpBodyStream.map { stream -> Data in
                stream.open(); defer { stream.close() }; var data = Data(); var buffer = [UInt8](repeating: 0, count: 2048)
                while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }; return data
            } ?? Data()) as! [String: Any]
            let events = body["events"] as! [[String: Any]]
            check(request.httpMethod == "POST" && events[0]["type"] as? String == "agent.session.input.cancel", "Cancellation uses the public input.cancel event")
            return (200, ["object": "list", "data": []])
        }
        try await api.cancel("sid")
        MockAgentProtocol.handler = { _ in (429, ["error": ["code": "usage_limit_exceeded", "message": "Billing limit"]]) }
        do { _ = try await api.availableModels(); fatalError("Quota failure must not report success") } catch { check(error.localizedDescription.contains("facturación"), "API failure is actionable") }
        let data = Data(#"{"type":"agent.session.requires_action","session":{"id":"s","required_actions":[{"type":"function_call","turn_id":"t","call_id":"c","name":"aster_create_task","arguments":{"title":"Propuesta"}}]}}"#.utf8)
        if case .actions(let sid, let actions)? = AgentEvent.decode(data) { check(sid == "s" && actions.count == 1 && actions[0].arguments["title"] as? String == "Propuesta", "Required actions decode the public function contract") } else { fatalError("Function call must reach responder") }
        print("PASS: public API headers, model access, exact-turn pagination and recovery, worker isolation, artifact ownership, cancellation, quota errors and pending function actions.")
    }
}
