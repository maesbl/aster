import SwiftUI
import AppKit

struct MessageBlock: Identifiable {
    enum Kind { case text, code(String), heading(Int) }
    var id: Int
    var kind: Kind
    var text: String
    static func parse(_ text: String) -> [MessageBlock] {
        let lines = text.components(separatedBy: "\n"); var blocks: [MessageBlock] = []; var buffer: [String] = []; var code: String?
        func flush() {
            guard !buffer.isEmpty else { return }
            blocks.append(.init(id: blocks.count, kind: code.map(Kind.code) ?? .text, text: buffer.joined(separator: "\n"))); buffer = []
        }
        for line in lines {
            if line.hasPrefix("```") {
                if code != nil { flush(); code = nil } else { flush(); code = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
            } else if code == nil, line.hasPrefix("#"), let space = line.firstIndex(of: " "), line[..<space].allSatisfy({ $0 == "#" }) {
                flush(); blocks.append(.init(id: blocks.count, kind: .heading(min(4, line[..<space].count)), text: String(line[line.index(after: space)...])))
            } else { buffer.append(line) }
        }
        flush(); return blocks
    }
}

struct RichMessage: View, Equatable {
    var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(MessageBlock.parse(text)) { block in
                switch block.kind {
                case .code(let language):
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(language.isEmpty ? L("Código") : language).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                            Spacer(); Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(block.text, forType: .string) } label: { Label(L("Copiar"), systemImage: "doc.on.doc").font(.system(size: 10)) }.buttonStyle(.plain)
                        }.padding(.horizontal, 13).padding(.vertical, 9).background(.primary.opacity(0.035))
                        ScrollView(.horizontal) { Text(verbatim: block.text).font(.system(size: 11, design: .monospaced)).lineSpacing(4).textSelection(.enabled).padding(14).frame(maxWidth: .infinity, alignment: .leading) }
                    }.background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12)).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.07)))
                case .heading(let level): Text(.init(block.text)).font(.system(size: level == 1 ? 21 : level == 2 ? 17 : 14, weight: .semibold, design: .rounded)).textSelection(.enabled).padding(.top, 5)
                case .text: Text(.init(block.text)).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
