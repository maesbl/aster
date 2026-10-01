import AVFoundation
import NaturalLanguage
import Foundation
import Combine

struct AsterVoice: Identifiable {
    var id: String
    var label: String
    static let all: [AsterVoice] = [
        .init(id: "marin", label: "Marin · cálida y natural"), .init(id: "cedar", label: "Cedar · serena y profunda"),
        .init(id: "coral", label: "Coral · luminosa"), .init(id: "sage", label: "Sage · tranquila"),
        .init(id: "ash", label: "Ash · cercana"), .init(id: "ballad", label: "Ballad · expresiva"),
        .init(id: "alloy", label: "Alloy · equilibrada"), .init(id: "echo", label: "Echo · clara"),
        .init(id: "fable", label: "Fable · narrativa"), .init(id: "nova", label: "Nova · viva"),
        .init(id: "onyx", label: "Onyx · grave"), .init(id: "shimmer", label: "Shimmer · suave"),
        .init(id: "verse", label: "Verse · versátil")
    ]
    static func defaultID(_ agent: String) -> String {
        ["director": "marin", "personal": "coral", "builder": "cedar", "study": "sage", "growth": "verse", "strategy": "onyx"][agent] ?? "marin"
    }
}

enum VoiceText {
    static func clean(_ value: String) -> String {
        let noCode = value.replacingOccurrences(of: #"(?s)```.*?```"#, with: "", options: .regularExpression)
        let links = noCode.replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
        return links.replacingOccurrences(of: #"(?m)^\s*[#>*-]+\s*"#, with: "", options: .regularExpression).replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func chunks(_ value: String, maximum: Int = 1700) -> [String] {
        var rest = value; var output: [String] = []
        while !rest.isEmpty {
            let prefix = String(rest.prefix(maximum))
            let separator = prefix.lastIndex(where: { ".!?\n".contains($0) }) ?? prefix.lastIndex(of: " ")
            let cut = prefix.count == rest.count ? prefix.endIndex : separator.map { prefix.index(after: $0) } ?? prefix.endIndex
            let chunk = String(prefix[..<cut]); let count = max(1, chunk.count)
            output.append(String(rest.prefix(count)).trimmingCharacters(in: .whitespacesAndNewlines)); rest = String(rest.dropFirst(count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return output.filter { !$0.isEmpty }
    }
    static func language(_ text: String, fallback: String) -> String {
        let recognizer = NLLanguageRecognizer(); recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? fallback
    }
}

@MainActor final class VoicePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    @Published private(set) var active = false
    @Published private(set) var preparing = false
    var stateChanged: ((Bool) -> Void)?
    var failed: ((String) -> Void)?
    private var job: Task<Void, Never>?
    private var preload: Task<Data, Error>?
    private var player: AVAudioPlayer?
    private var generation = UUID()
    private var currentUtterance: AVSpeechUtterance?
    private let synth = AVSpeechSynthesizer()
    private var completion: CheckedContinuation<Void, Error>?
    override init() { super.init(); synth.delegate = self }
    func stop() {
        generation = UUID(); currentUtterance = nil; job?.cancel(); job = nil; preload?.cancel(); preload = nil; player?.stop(); player = nil; synth.stopSpeaking(at: .immediate)
        completion?.resume(throwing: CancellationError()); completion = nil; setActive(false); preparing = false
    }
    private func setActive(_ value: Bool) { active = value; stateChanged?(value) }
    func say(_ text: String, natural: Bool, voice: String, language: String, tone: String) {
        stop(); let clean = VoiceText.clean(text); guard !clean.isEmpty else { return }; setActive(true)
        if !natural { native(clean, language: language); return }
        preparing = true; let token = generation
        job = Task { [weak self] in
            guard let self else { return }
            do {
                let api = try AgentAPI(); let chunks = VoiceText.chunks(clean)
                let instructions = "Speak naturally in the language of the supplied text (\(language)). Clear pronunciation, conversational pacing and a \(tone) tone. Do not translate or add words."
                guard let first = chunks.first else { return }
                var next = Task { try await api.speech(first, voice: voice, instructions: instructions) }; self.preload = next
                for index in chunks.indices {
                    let data = try await next.value; try Task.checkCancellation(); guard self.generation == token else { throw CancellationError() }
                    if index + 1 < chunks.count { let following = chunks[index + 1]; next = Task { try await api.speech(following, voice: voice, instructions: instructions) }; self.preload = next }
                    self.preparing = false; try await self.play(data); try Task.checkCancellation()
                }
                self.preload = nil; self.job = nil; self.setActive(false)
            } catch is CancellationError { }
            catch { guard self.generation == token else { return }; self.preparing = false; self.failed?(error.localizedDescription); self.job = nil; self.setActive(false) }
        }
    }
    func narrate(_ text: String, language: String) { stop(); setActive(true); native(text, language: language) }
    private func native(_ text: String, language: String) {
        let utterance = AVSpeechUtterance(string: text)
        let options = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(language) }.sorted { $0.quality.rawValue > $1.quality.rawValue }
        utterance.voice = options.first ?? AVSpeechSynthesisVoice(language: language); utterance.rate = 0.48
        currentUtterance = utterance; synth.speak(utterance)
    }
    private func play(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { continuation in
            do { player = try AVAudioPlayer(data: data); player?.delegate = self; player?.prepareToPlay(); completion = continuation; if player?.play() != true { completion = nil; continuation.resume(throwing: AsterError.message("No se ha podido reproducir la voz.")) } }
            catch { continuation.resume(throwing: error) }
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in guard let self, self.player === player else { return }; let continuation = self.completion; self.completion = nil; if flag { continuation?.resume() } else { continuation?.resume(throwing: AsterError.message("La reproducción se ha interrumpido.")) } }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { Task { @MainActor [weak self] in if self?.currentUtterance === utterance { self?.currentUtterance = nil; self?.setActive(false) } } }
}
