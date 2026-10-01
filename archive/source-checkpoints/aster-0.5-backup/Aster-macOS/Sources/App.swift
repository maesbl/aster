import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: AsterStore!
    var window: NSWindow!
    var companions: DesktopCompanions!
    var computerHUD: NSPanel!
    var coach: ScreenCoach!
    var lastTarget: NSRunningApplication?
    var statusItem: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.main.url(forResource: "Aster", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
        store = AsterStore()
        let view = MainView(showCompanion: { [weak self] in self?.showCompanion() }).environmentObject(store)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 830), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Aster"; window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false; window.minSize = NSSize(width: 1020, height: 760)
        window.isOpaque = false; window.backgroundColor = .clear; window.titlebarSeparatorStyle = .none
        window.contentView = NSHostingView(rootView: view); window.setFrameAutosaveName("AsterMain"); if !window.setFrameUsingName("AsterMain") { window.center() }
        companions = DesktopCompanions(store: store, open: { [weak self] in self?.openMain() })
        coach = ScreenCoach(store: store)
        store.onOpenCoach = { [weak self] in self?.coach.show() }
        coach.prepareTarget = { [weak self] target in guard let self else { return }; if let target { self.lastTarget = target }; self.window.orderOut(nil); self.companions.suspend(); self.lastTarget?.activate(options: [.activateAllWindows]) }
        coach.restoreCompanions = { [weak self] in self?.companions.resume() }
        store.onFloatingChange = { [weak self] in self?.companions.synchronize() }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.companions.constrainToScreens() }
        }
        computerHUD = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 342, height: 114), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        computerHUD.title = "Aster · Mac"; computerHUD.isOpaque = false; computerHUD.backgroundColor = .clear; computerHUD.hasShadow = true; computerHUD.level = .floating; computerHUD.isMovableByWindowBackground = true; computerHUD.hidesOnDeactivate = false
        computerHUD.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        computerHUD.contentView = NSHostingView(rootView: ComputerHUD(computer: store.computer, open: { [weak self] in self?.store.computer.pause() }))
        if let screen = NSScreen.main { computerHUD.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 375, y: screen.visibleFrame.maxY - 130)) }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier { Task { @MainActor in self?.lastTarget = app } }
        }
        store.computer.onBegin = { [weak self] in guard let self else { return }; self.coach.suspend(); self.window.orderOut(nil); self.companions.suspend(); self.lastTarget?.activate(options: []); self.computerHUD.orderFrontRegardless() }
        store.computer.onEnd = { [weak self] in guard let self else { return }; self.computerHUD.orderOut(nil); self.companions.resume(); self.coach.resume(); self.store.page = "Ordenador"; self.openMain() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.dotted.circle.fill", accessibilityDescription: "Aster")
        let menu = NSMenu()
        menu.addItem(withTitle: "Abrir Aster", action: #selector(openMain), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Mostrar compañeros", action: #selector(showCompanion), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Ordenar arriba a la derecha", action: #selector(arrangeCompanions), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Minimizar compañeros", action: #selector(hideCompanions), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Chat rápido", action: #selector(quickChat), keyEquivalent: "").target = self
        menu.addItem(withTitle: "A tu lado · ⌥⌘K", action: #selector(openCoach), keyEquivalent: "").target = self
        addChatMenu(to: menu)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Salir de Aster", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        let mainMenu = NSMenu(); let appMenu = NSMenu(); let root = NSMenuItem(title: "Aster", action: nil, keyEquivalent: ""); root.submenu = appMenu; mainMenu.addItem(root)
        appMenu.addItem(withTitle: "Acerca de Aster", action: #selector(showAbout), keyEquivalent: "").target = self
        appMenu.addItem(withTitle: "Ajustes…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(NSMenuItem.separator()); appMenu.addItem(withTitle: "Salir de Aster", action: #selector(quit), keyEquivalent: "q").target = self
        let edit = NSMenu(title: "Edición"); let editRoot = NSMenuItem(title: "Edición", action: nil, keyEquivalent: ""); editRoot.submenu = edit; mainMenu.addItem(editRoot)
        for (title, action, key) in [("Deshacer", "undo:", "z"), ("Cortar", "cut:", "x"), ("Copiar", "copy:", "c"), ("Pegar", "paste:", "v"), ("Seleccionar todo", "selectAll:", "a")] { edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key) }
        let windows = NSMenu(title: "Ventana"); let windowsRoot = NSMenuItem(title: "Ventana", action: nil, keyEquivalent: ""); windowsRoot.submenu = windows; mainMenu.addItem(windowsRoot)
        windows.addItem(withTitle: "Cerrar ventana", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windows.addItem(withTitle: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windows.addItem(withTitle: "Mostrar compañeros", action: #selector(showCompanion), keyEquivalent: "").target = self
        windows.addItem(withTitle: "Ordenar arriba a la derecha", action: #selector(arrangeCompanions), keyEquivalent: "").target = self
        windows.addItem(withTitle: "Minimizar compañeros", action: #selector(hideCompanions), keyEquivalent: "").target = self
        let quickItem = windows.addItem(withTitle: "Chat rápido", action: #selector(quickChat), keyEquivalent: "j"); quickItem.target = self; quickItem.keyEquivalentModifierMask = [.command, .option]
        windows.addItem(withTitle: "A tu lado · ⌥⌘K", action: #selector(openCoach), keyEquivalent: "").target = self
        addChatMenu(to: windows)
        let foldItem = windows.addItem(withTitle: "Plegar o desplegar equipo", action: #selector(toggleDesktop), keyEquivalent: "b"); foldItem.target = self; foldItem.keyEquivalentModifierMask = [.command, .option]
        windows.addItem(withTitle: "Mostrar Aster", action: #selector(openMain), keyEquivalent: "").target = self
        windows.addItem(withTitle: "Nueva misión", action: #selector(newMission), keyEquivalent: "n").target = self
        NSApplication.shared.windowsMenu = windows
        NSApplication.shared.mainMenu = mainMenu
        localizeMenus()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.localizeMenus() } }
        openMain()
    }
    private func localizeMenus() {
        func translate(_ menu: NSMenu) {
            for item in menu.items {
                if item.action == #selector(chatWithAgent(_:)) {
                    if let id = item.representedObject as? String, let agent = store.state.specialists.first(where: { $0.id == id }) { item.title = agent.name }; continue
                }
                if item.representedObject == nil { item.representedObject = item.title }
                if let key = item.representedObject as? String { item.title = L(key) }
                if let submenu = item.submenu { translate(submenu); if let key = item.representedObject as? String, !key.isEmpty { submenu.title = L(key) } }
            }
        }
        if let menu = NSApplication.shared.mainMenu { translate(menu) }
        if let menu = statusItem.menu { translate(menu) }
    }
    private func addChatMenu(to menu: NSMenu) {
        let root = NSMenuItem(title: "Hablar con…", action: nil, keyEquivalent: ""); let submenu = NSMenu()
        for agent in store.state.specialists {
            let item = submenu.addItem(withTitle: agent.name, action: #selector(chatWithAgent(_:)), keyEquivalent: ""); item.target = self; item.representedObject = agent.id
        }
        root.submenu = submenu; menu.addItem(root)
    }
    @objc func openCoach() { coach.show() }
    @objc func quickChat() { companions.showChat(store.agent.id, focus: true) }
    @objc func chatWithAgent(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { companions.showChat(id, focus: true) } }
    @objc func toggleDesktop() { companions.toggleCollapsed() }
    @objc func openMain() { window.makeKeyAndOrderFront(nil); NSApplication.shared.activate(ignoringOtherApps: true) }
    @objc func showCompanion() { companions.showAll() }
    @objc func arrangeCompanions() { companions.arrange() }
    @objc func hideCompanions() { companions.hideAll() }
    @objc func showAbout() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [.applicationName: "Aster"]
        if let icon = NSApplication.shared.applicationIconImage { options[.applicationIcon] = icon }
        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    @objc func showSettings() { openMain(); store.page = "Conexiones" }
    @objc func newMission() { openMain(); store.selectedMission = nil; store.page = "Misiones" }
    func applicationWillTerminate(_ notification: Notification) { coach.shutdown(); store.computer.stop(); store.voice.stop(); companions.flushDrafts(); store.flushStorage() }
    @objc func quit() { NSApplication.shared.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if coach.restoreFocus() { return true }
        if companions.restorePinnedChatFocus() { return true }
        openMain(); return true
    }
}

@main struct AsterMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular); app.delegate = delegate; app.run()
        withExtendedLifetime(delegate) {}
    }
}
