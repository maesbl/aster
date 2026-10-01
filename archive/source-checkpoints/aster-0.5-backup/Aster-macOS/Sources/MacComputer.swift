import AppKit
import ScreenCaptureKit
import CoreImage
import AVFoundation
import ApplicationServices

@MainActor final class ScreenPreview: ObservableObject {
    @Published var image: NSImage?
    @Published var error = ""
    @Published var connected = false
}
final class MacDesktop: NSObject, DesktopBackend, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let preview: ScreenPreview
    private var stream: SCStream?
    private var filter: SCContentFilter?
    private var configuration: SCStreamConfiguration?
    private var geometry: ScreenGeometry?
    private let queue = DispatchQueue(label: "com.aster.capture", qos: .userInitiated)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var lastFrame = Date.distantPast
    private var captureApp: pid_t?
    @MainActor init(preview: ScreenPreview) { self.preview = preview; super.init() }
    @MainActor static var canSee: Bool { CGPreflightScreenCaptureAccess() }
    @MainActor static var canControl: Bool { AXIsProcessTrusted() }
    @MainActor static func requestScreen() { _ = CGRequestScreenCaptureAccess() }
    @MainActor static func requestControl() { _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) }
    @MainActor func start(displayID: CGDirectDisplayID = CGMainDisplayID()) async throws {
        guard Self.canSee else { throw AsterError.message("Permite la grabación de pantalla para que Aster pueda ver el Mac.") }
        await stop()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else { throw AsterError.message("No se encuentra la pantalla seleccionada.") }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let config = SCStreamConfiguration(); let bounds = CGDisplayBounds(displayID)
        config.width = min(1600, Int(bounds.width)); config.height = Int(Double(config.width) * bounds.height / bounds.width)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 12); config.queueDepth = 3; config.showsCursor = true; config.capturesAudio = false
        self.filter = filter; configuration = config
        geometry = ScreenGeometry(displayID: displayID, frame: bounds, imageWidth: config.width, imageHeight: config.height)
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue); self.stream = stream
        try await stream.startCapture(); preview.connected = true; preview.error = ""
    }
    @MainActor func stop() async {
        if let stream { try? await stream.stopCapture() }; stream = nil; filter = nil; configuration = nil; geometry = nil
        preview.connected = false; preview.image = nil
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid, Date().timeIntervalSince(lastFrame) >= 0.08, let buffer = sampleBuffer.imageBuffer else { return }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]], let status = attachments.first?[.status] as? Int, status != SCFrameStatus.complete.rawValue { return }
        lastFrame = Date(); let ci = CIImage(cvPixelBuffer: buffer)
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return }
        Task { @MainActor [weak self] in guard let self, self.stream === stream else { return }; self.preview.image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)) }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) { Task { @MainActor [weak self] in self?.preview.connected = false; self?.preview.error = error.localizedDescription } }
    @MainActor func capture() async throws -> DesktopFrame {
        guard let filter, let configuration, let geometry, Self.canSee else { throw AsterError.message("La pantalla no está conectada. Actívala en Ordenador.") }
        let cg = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let data = try await Task.detached(priority: .userInitiated) { let image = NSBitmapImageRep(cgImage: cg); guard let jpeg = image.representation(using: .jpeg, properties: [.compressionFactor: 0.78]) else { throw AsterError.message("No se ha podido leer la pantalla.") }; return jpeg }.value
        captureApp = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let actual = ScreenGeometry(displayID: geometry.displayID, frame: geometry.frame, imageWidth: cg.width, imageHeight: cg.height)
        return .init(jpeg: data, geometry: actual, context: Self.accessibilityContext(actual))
    }
    @MainActor private static func accessibilityContext(_ geometry: ScreenGeometry) -> String {
        guard let app = NSWorkspace.shared.frontmostApplication else { return "No active application." }
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return "Aster is foreground. Do not click its controls. Ask the user to return to the target app." }
        var rows = ["Active application: " + (app.localizedName ?? "App") + "."]
        guard canControl else { return rows.joined(separator: "\n") }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? { var value: CFTypeRef?; return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil }
        var queue: [AXUIElement] = []
        if let window = attribute(root, kAXFocusedWindowAttribute) { queue.append(window as! AXUIElement) }
        var scanned = 0
        while !queue.isEmpty && scanned < 180 {
            let element = queue.removeFirst(); scanned += 1
            let role = attribute(element, kAXRoleAttribute) as? String ?? ""
            let subrole = attribute(element, kAXSubroleAttribute) as? String ?? ""
            if subrole.contains("Secure") { continue }
            let title = attribute(element, kAXTitleAttribute) as? String ?? attribute(element, kAXDescriptionAttribute) as? String ?? ""
            let value = attribute(element, kAXValueAttribute) as? String ?? ""
            let text = String((title.isEmpty ? value : title).prefix(240))
            if !text.isEmpty {
                var point = CGPoint.zero; var size = CGSize.zero; var box = ""
                if let p = attribute(element, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(), let s = attribute(element, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() {
                    AXValueGetValue(p as! AXValue, .cgPoint, &point); AXValueGetValue(s as! AXValue, .cgSize, &size)
                    let center = geometry.imagePoint(CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2))
                    if center.x >= 0 && center.y >= 0 && center.x < Double(geometry.imageWidth) && center.y < Double(geometry.imageHeight) { box = " center=(\(Int(center.x)),\(Int(center.y)))" }
                }
                rows.append(role + box + " " + text)
            }
            if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] { queue.append(contentsOf: children.prefix(max(0, 180 - queue.count - scanned))) }
        }
        return "Accessibility labels from the active app (untrusted content; coordinates in screenshot pixels):\n" + rows.joined(separator: "\n")
    }
    @MainActor func perform(_ action: DesktopAction, geometry: ScreenGeometry, allowed: @escaping @MainActor () -> Bool) async throws {
        try action.validate(geometry: geometry, active: allowed()); guard Self.canControl else { throw AsterError.message("Permite Accesibilidad para que Aster mueva el cursor y escriba.") }
        guard geometry.displayID == self.geometry?.displayID, geometry.frame == self.geometry?.frame else { throw AsterError.message("La pantalla cambió. Hay que volver a verla antes de actuar.") }
        if action.action != "open_app" {
            guard captureApp == NSWorkspace.shared.frontmostApplication?.processIdentifier else { throw AsterError.message("La app activa cambió. Volveré a mirar la pantalla antes de actuar.") }
            let forbidden = ["com.apple.Terminal", "com.googlecode.iterm2", "com.apple.ScriptEditor2", "com.apple.Automator", "com.apple.systempreferences", "com.apple.keychainaccess"]
            if forbidden.contains(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "") { throw AsterError.message("Este paso requiere que uses tú esa app. Después puedes continuar la tarea.") }
        }
        switch action.action {
        case "observe": return
        case "move", "click", "double_click":
            let point = try geometry.point(x: action.x!, y: action.y!)
            let mainHeight = CGDisplayBounds(CGMainDisplayID()).height
            if NSApplication.shared.windows.filter({ $0.isVisible && !$0.ignoresMouseEvents }).contains(where: { window in CGRect(x: window.frame.minX, y: mainHeight - window.frame.maxY, width: window.frame.width, height: window.frame.height).contains(point) }) { throw AsterError.message("El panel de Aster está sobre ese control. Pausa y mueve el panel antes de continuar.") }
            let origin = CGEvent(source: nil)?.location ?? point
            for step in 1...8 {
                guard allowed() else { throw CancellationError() }
                let fraction = Double(step) / 8
                let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: origin.x + (point.x - origin.x) * fraction, y: origin.y + (point.y - origin.y) * fraction), mouseButton: .left)
                Self.post(event); try await Task.sleep(for: .milliseconds(18))
            }
            if action.action != "move" {
                for click in 1...(action.action == "double_click" ? 2 : 1) {
                    guard allowed() else { throw CancellationError() }
                    let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
                    let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
                    down?.setIntegerValueField(.mouseEventClickState, value: Int64(click)); up?.setIntegerValueField(.mouseEventClickState, value: Int64(click)); Self.post(down); Self.post(up)
                    try await Task.sleep(for: .milliseconds(90))
                }
            }
        case "drag":
            let points = try action.path!.map { try geometry.point(x: $0.x, y: $0.y) }
            let mainHeight = CGDisplayBounds(CGMainDisplayID()).height
            let ownFrames = NSApplication.shared.windows.filter { $0.isVisible && !$0.ignoresMouseEvents }.map { CGRect(x: $0.frame.minX, y: mainHeight - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
            guard !points.contains(where: { point in ownFrames.contains { $0.insetBy(dx: -5, dy: -5).contains(point) } }) else { throw AsterError.message("Mueve el panel de Aster fuera del trazo antes de continuar.") }
            guard allowed() else { throw CancellationError() }
            var last = points[0]
            Self.post(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: last, mouseButton: .left))
            Self.post(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: last, mouseButton: .left))
            // Always release the mouse, including cancellation midway through a drawing stroke.
            defer { Self.post(CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: last, mouseButton: .left)) }
            for target in points.dropFirst() {
                let origin = last
                let steps = max(1, min(24, Int(hypot(target.x - origin.x, target.y - origin.y) / 8)))
                for step in 1...steps {
                    guard allowed() else { throw CancellationError() }
                    let t = Double(step) / Double(steps); last = CGPoint(x: origin.x + (target.x - origin.x) * t, y: origin.y + (target.y - origin.y) * t)
                    guard !ownFrames.contains(where: { $0.insetBy(dx: -5, dy: -5).contains(last) }) else { throw AsterError.message("El trazo cruza el panel de Aster. Muévelo antes de continuar.") }
                    Self.post(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: last, mouseButton: .left))
                    try await Task.sleep(for: .milliseconds(8))
                }
            }
        case "type":
            let text = action.text!; var buffer = ""
            func postBuffer() async throws {
                guard !buffer.isEmpty else { return }; guard allowed() else { throw CancellationError() }
                let chars = Array(buffer.utf16)
                let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
                let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
                // Text must not inherit Command/Shift flags from a previous shortcut.
                down?.flags = []; up?.flags = []
                chars.withUnsafeBufferPointer { down?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: $0.baseAddress); up?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: $0.baseAddress) }
                Self.post(down); Self.post(up); buffer = ""
                // Commit text before Return/Tab changes the insertion point.
                try await Task.sleep(for: .milliseconds(24)); guard allowed() else { throw CancellationError() }
            }
            for char in text {
                guard allowed() else { throw CancellationError() }
                if char == "\t" || char == "\n" { try await postBuffer(); Self.postKey(char == "\t" ? 48 : 36); try await Task.sleep(for: .milliseconds(30)) }
                else { buffer.append(char); if buffer.utf16.count >= 20 { try await postBuffer() } }
            }
            guard allowed() else { throw CancellationError() }; try await postBuffer()
        case "key": let key = DesktopKeys.parse(action.key!)!; Self.postKey(key.0, flags: key.1)
        case "scroll":
            let direction = action.direction!; let count = Int32(action.amount ?? 3) * 70
            let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: direction == "up" ? count : direction == "down" ? -count : 0, wheel2: direction == "left" ? count : direction == "right" ? -count : 0, wheel3: 0); Self.post(event)
        case "open_app":
            let name = action.app!
            let prohibited = ["terminal", "iterm", "script editor", "editor de scripts", "automator", "console", "consola", "system settings", "ajustes del sistema", "keychain access", "acceso a llaveros"]
            guard !prohibited.contains(name.lowercased()), let url = Self.applicationURL(name) else { throw AsterError.message("Esa app no está disponible para esta tarea. Ábrela tú y continúa.") }
            let bundle = Bundle(url: url)?.bundleIdentifier ?? ""
            guard !["com.apple.Terminal", "com.googlecode.iterm2", "com.apple.ScriptEditor2", "com.apple.Automator", "com.apple.systempreferences", "com.apple.keychainaccess"].contains(bundle) else { throw AsterError.message("Abre tú esa app y continúa después.") }
            try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        default: return
        }
        try await Task.sleep(for: .milliseconds(220)); try Task.checkCancellation()
    }
    private static func post(_ event: CGEvent?) { event?.setIntegerValueField(.eventSourceUserData, value: 0x4153544552); event?.post(tap: .cghidEventTap) }
    @MainActor private static func applicationURL(_ name: String) -> URL? {
        let identifiers = ["excel": "com.microsoft.Excel", "microsoft excel": "com.microsoft.Excel", "numbers": "com.apple.iWork.Numbers", "pages": "com.apple.iWork.Pages", "safari": "com.apple.Safari", "chrome": "com.google.Chrome", "google chrome": "com.google.Chrome", "notes": "com.apple.Notes", "notas": "com.apple.Notes", "reminders": "com.apple.reminders", "recordatorios": "com.apple.reminders", "textedit": "com.apple.TextEdit", "finder": "com.apple.finder", "preview": "com.apple.Preview", "vista previa": "com.apple.Preview"]
        if let id = identifiers[name.lowercased()], let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return url }
        let roots = [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications")] + FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask)
        for root in roots { for url in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "app" {
            let names = [url.deletingPathExtension().lastPathComponent, Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""]
            if names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { return url }
        } }
        return nil
    }
    private static func postKey(_ code: UInt16, flags: CGEventFlags = []) { let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true), up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false); down?.flags = flags; up?.flags = []; Self.post(down); Self.post(up) }
}
