import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: AsterStore!
    var window: NSWindow!
    var companion: NSPanel!
    var statusItem: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        store = AsterStore()
        let view = MainView(showCompanion: { [weak self] in self?.showCompanion() }).environmentObject(store)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 830), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Aster"; window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false; window.minSize = NSSize(width: 1020, height: 760)
        window.isOpaque = false; window.backgroundColor = .clear; window.titlebarSeparatorStyle = .none
        window.contentView = NSHostingView(rootView: view); window.center()
        companion = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 240, height: 260), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        companion.title = "Compañero Aster"; companion.isOpaque = false; companion.backgroundColor = .clear; companion.hasShadow = false
        companion.level = .floating; companion.isMovableByWindowBackground = true
        companion.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        companion.hidesOnDeactivate = false; companion.isReleasedWhenClosed = false
        companion.setFrameAutosaveName("AsterCompanion")
        companion.contentView = NSHostingView(rootView: FloatingView(open: { [weak self] in self?.openMain() }, hide: { [weak self] in self?.companion.orderOut(nil) }).environmentObject(store))
        if !companion.setFrameUsingName("AsterCompanion"), let screen = NSScreen.main { companion.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 280, y: screen.visibleFrame.minY + 35)) }
        store.onFloatingChange = { [weak self] in self?.resizeCompanion() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.dotted.circle.fill", accessibilityDescription: "Aster")
        let menu = NSMenu()
        menu.addItem(withTitle: "Abrir Aster", action: #selector(openMain), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Mostrar compañero", action: #selector(showCompanion), keyEquivalent: "").target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Salir de Aster", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        let mainMenu = NSMenu(); let appMenu = NSMenu(); let root = NSMenuItem(); root.submenu = appMenu; mainMenu.addItem(root)
        appMenu.addItem(withTitle: "Acerca de Aster", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "Ajustes…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(NSMenuItem.separator()); appMenu.addItem(withTitle: "Salir de Aster", action: #selector(quit), keyEquivalent: "q").target = self
        let edit = NSMenu(title: "Edición"); let editRoot = NSMenuItem(); editRoot.submenu = edit; mainMenu.addItem(editRoot)
        for (title, action, key) in [("Deshacer", "undo:", "z"), ("Cortar", "cut:", "x"), ("Copiar", "copy:", "c"), ("Pegar", "paste:", "v"), ("Seleccionar todo", "selectAll:", "a")] { edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key) }
        let windows = NSMenu(title: "Ventana"); let windowsRoot = NSMenuItem(); windowsRoot.submenu = windows; mainMenu.addItem(windowsRoot)
        windows.addItem(withTitle: "Cerrar ventana", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windows.addItem(withTitle: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windows.addItem(withTitle: "Mostrar Aster", action: #selector(openMain), keyEquivalent: "").target = self
        windows.addItem(withTitle: "Nueva misión", action: #selector(newMission), keyEquivalent: "n").target = self
        NSApplication.shared.windowsMenu = windows
        NSApplication.shared.mainMenu = mainMenu
        openMain(); showCompanion()
    }
    private func resizeCompanion() {
        let size = store.agent.style.size + 55
        companion.setContentSize(NSSize(width: size, height: size + 25))
    }
    @objc func openMain() { window.makeKeyAndOrderFront(nil); NSApplication.shared.activate(ignoringOtherApps: true) }
    @objc func showCompanion() { resizeCompanion(); companion.orderFrontRegardless() }
    @objc func showSettings() { openMain(); store.page = "Conexiones" }
    @objc func newMission() { openMain(); store.selectedMission = nil; store.page = "Misiones" }
    @objc func quit() { NSApplication.shared.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openMain(); return true }
}

@main struct AsterMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular); app.delegate = delegate; app.run()
        withExtendedLifetime(delegate) {}
    }
}
