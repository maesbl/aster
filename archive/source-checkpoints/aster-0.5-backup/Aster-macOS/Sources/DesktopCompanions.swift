import AppKit
import SwiftUI
import QuartzCore

@MainActor final class DesktopCompanions: ObservableObject {
    private let store: AsterStore
    private let open: () -> Void
    private var panels: [String: NSPanel] = [:]
    private var moveObservers: [String: NSObjectProtocol] = [:]
    private var hidden: Set<String>
    private var suspended = false
    private var fold: NSPanel?
    private var chat: MiniChatPanel?
    private var hoverTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var draftTask: Task<Void, Never>?
    private var visibilityTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var visibilityRevisions: [ObjectIdentifier: Int] = [:]
    private var visibilityTargets: [ObjectIdentifier: Bool] = [:]
    private var hoveredAgent: String?
    private var chatHovered = false
    private var dragging = Set<String>()
    private let defaults = UserDefaults.standard
    private let hiddenKey = "AsterDesktopHiddenAgents"
    @Published private(set) var collapsed: Bool
    @Published private(set) var activeChatID: String?
    @Published var pinned = false
    @Published private(set) var drafts: [String: String]
    private func positionKey(_ id: String) -> String { "AsterDesktopPosition.v2.\(id)" }
    var visibleCount: Int { store.state.specialists.filter { !hidden.contains($0.id) }.count }

    init(store: AsterStore, open: @escaping () -> Void) {
        self.store = store; self.open = open
        hidden = Set(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [])
        collapsed = UserDefaults.standard.bool(forKey: "AsterDesktopCollapsed")
        drafts = store.state.desktopDrafts
        synchronize(); restoreVisible()
    }
    func synchronize() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let agents = store.state.specialists
        let frames = DesktopLayout.column(count: agents.count, screen: screen.visibleFrame, topInset: 44)
        let oldFrames = DesktopLayout.column(count: agents.count, screen: screen.visibleFrame)
        if fold == nil {
            let panel = NSPanel(contentRect: CGRect(x: screen.visibleFrame.maxX - 56, y: screen.visibleFrame.maxY - 44, width: 44, height: 32), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            configure(panel, title: "Aster · Equipo")
            panel.contentView = NSHostingView(rootView: DesktopFoldView(desktop: self).environmentObject(store))
            fold = panel
        }
        let migrateDock = !defaults.bool(forKey: "AsterDesktopShelfLayout")
        for (index, agent) in agents.enumerated() {
            if let panel = panels[agent.id] { panel.title = "Aster · \(agent.name)"; continue }
            let panel = NSPanel(contentRect: frames[index], styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            configure(panel, title: "Aster · \(agent.name)")
            if let saved = defaults.string(forKey: positionKey(agent.id)) {
                let savedFrame = NSRectFromString(saved)
                let wasDocked = abs(savedFrame.minX - oldFrames[index].minX) < 2 && abs(savedFrame.minY - oldFrames[index].minY) < 2
                if savedFrame.origin.x.isFinite, savedFrame.origin.y.isFinite, savedFrame.width > 0, !(migrateDock && wasDocked) {
                    panel.setFrame(DesktopLayout.clamped(CGRect(origin: savedFrame.origin, size: frames[index].size), screens: NSScreen.screens.map(\.visibleFrame)), display: false)
                }
            }
            panels[agent.id] = panel; installAvatar(agent.id, panel: panel)
            moveObservers[agent.id] = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.rememberPosition(agent.id) }
            }
            savePosition(agent.id)
        }
        defaults.set(true, forKey: "AsterDesktopShelfLayout")
        for id in Set(panels.keys).subtracting(agents.map(\.id)) {
            if let observer = moveObservers.removeValue(forKey: id) { NotificationCenter.default.removeObserver(observer) }
            panels.removeValue(forKey: id)?.orderOut(nil)
            if activeChatID == id { closeChat() }
        }
    }
    private func configure(_ panel: NSPanel, title: String) {
        panel.title = title; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
    }
    private func installAvatar(_ id: String, panel: NSPanel) {
        panel.contentView = NSHostingView(rootView: FloatingView(agentID: id, height: panel.frame.height,
            open: { [weak self] in self?.expandChat(id) }, talk: { [weak self] in self?.showChat(id, focus: true) },
            arrange: { [weak self] in self?.arrange() }, hide: { [weak self] in self?.hide(id) },
            moved: { [weak self] in self?.endDrag(id) }, dragStarted: { [weak self] in self?.beginDrag(id) },
            hover: { [weak self] inside in self?.hover(id, inside: inside) }).environmentObject(store))
    }
    private func hide(_ id: String) {
        hidden.insert(id); defaults.set(Array(hidden), forKey: hiddenKey)
        if let panel = panels[id] { setVisible(panel, false, offset: CGPoint(x: 0, y: 12)) }
        if activeChatID == id { closeChat() }; objectWillChange.send()
    }
    func showAll() { hidden.removeAll(); defaults.set([], forKey: hiddenKey); synchronize(); setCollapsed(false) }
    func hideAll() { setCollapsed(true) }
    func toggleCollapsed() { if visibleCount == 0 { showAll() } else { setCollapsed(!collapsed) } }
    private func setCollapsed(_ value: Bool) {
        withAnimation(AsterMotion.spring(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)) { collapsed = value }
        defaults.set(value, forKey: "AsterDesktopCollapsed")
        if value { closeChat() }; restoreVisible()
    }
    func arrange() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frames = DesktopLayout.column(count: store.state.specialists.count, screen: screen.visibleFrame, topInset: 44)
        for (index, agent) in store.state.specialists.enumerated() {
            guard let panel = panels[agent.id] else { continue }
            panel.setFrame(frames[index], display: true); installAvatar(agent.id, panel: panel); savePosition(agent.id)
        }
        fold?.setFrameOrigin(CGPoint(x: screen.visibleFrame.maxX - 56, y: screen.visibleFrame.maxY - 44))
        showAll(); if let id = activeChatID { positionChat(id) }
    }
    func constrainToScreens() {
        for id in panels.keys { savePosition(id) }
        if let fold { fold.setFrame(DesktopLayout.clamped(fold.frame, screens: NSScreen.screens.map(\.visibleFrame)), display: true) }
        if let id = activeChatID { positionChat(id) }
    }
    private func savePosition(_ id: String) {
        guard let panel = panels[id] else { return }
        panel.setFrame(DesktopLayout.clamped(panel.frame, screens: NSScreen.screens.map(\.visibleFrame)), display: true); rememberPosition(id)
    }
    private func rememberPosition(_ id: String) {
        guard let panel = panels[id] else { return }
        let value = NSStringFromRect(panel.frame)
        if defaults.string(forKey: positionKey(id)) != value { defaults.set(value, forKey: positionKey(id)) }
    }
    private func restoreVisible(animated: Bool = true) {
        guard !suspended else { return }
        if let fold { setVisible(fold, true, animated: animated, offset: CGPoint(x: 0, y: 4)) }
        for (index, agent) in store.state.specialists.enumerated() {
            guard let panel = panels[agent.id] else { continue }
            setVisible(panel, !collapsed && !hidden.contains(agent.id), animated: animated,
                       offset: CGPoint(x: 0, y: 12), delay: Double(index) * 0.014)
        }
    }
    func suspend() {
        suspended = true; closeChat(animated: false)
        if let fold { setVisible(fold, false, animated: false) }
        panels.values.forEach { setVisible($0, false, animated: false) }
    }
    func resume() { suspended = false; restoreVisible() }

    // Animate the composited content, keeping the saved desktop window positions fixed.
    // A revision cancels an older fade-out when the user opens the panel again quickly.
    private func setVisible(_ panel: NSPanel, _ visible: Bool, animated: Bool = true,
                            offset: CGPoint = .zero, delay: Double = 0, refresh: Bool = false,
                            completion: (() -> Void)? = nil) {
        let key = ObjectIdentifier(panel)
        let previousTarget = visibilityTargets[key]
        visibilityTargets[key] = visible
        if visible, panel.isVisible, previousTarget != false, !refresh { completion?(); return }
        visibilityTasks.removeValue(forKey: key)?.cancel()
        let revision = (visibilityRevisions[key] ?? 0) + 1; visibilityRevisions[key] = revision
        guard let view = panel.contentView else { if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }; completion?(); return }
        view.wantsLayer = true
        guard let layer = view.layer else { if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }; completion?(); return }
        let wasVisible = panel.isVisible
        let presentation = layer.presentation()
        let fromOpacity = wasVisible ? (presentation?.opacity ?? layer.opacity) : 0
        let hiddenTransform = CATransform3DScale(CATransform3DMakeTranslation(offset.x, offset.y, 0), 0.975, 0.975, 1)
        let fromTransform = wasVisible ? (presentation?.transform ?? layer.transform) : hiddenTransform
        layer.removeAnimation(forKey: "AsterVisibility")
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.opacity = visible ? 1 : 0; layer.transform = visible ? CATransform3DIdentity : hiddenTransform
        CATransaction.commit()
        if visible { panel.orderFrontRegardless() }
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, visible || wasVisible else {
            if !visible { panel.orderOut(nil) }
            resetLayer(layer); completion?(); return
        }
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = refresh && visible && fromOpacity == 1 ? 0.72 : fromOpacity
        opacity.toValue = visible ? 1 : 0
        let transform = CABasicAnimation(keyPath: "transform")
        transform.fromValue = NSValue(caTransform3D: fromTransform)
        transform.toValue = NSValue(caTransform3D: visible ? CATransform3DIdentity : hiddenTransform)
        let group = CAAnimationGroup(); group.animations = [opacity, transform]
        let duration = visible ? 0.22 : 0.18
        group.duration = duration; group.beginTime = CACurrentMediaTime() + delay
        group.timingFunction = CAMediaTimingFunction(name: visible ? .easeOut : .easeInEaseOut)
        group.fillMode = .backwards; layer.add(group, forKey: "AsterVisibility")
        visibilityTasks[key] = Task { [weak self, weak panel, weak layer] in
            do { try await Task.sleep(for: .seconds(delay + duration)) } catch { return }
            guard let self, let panel, let layer, self.visibilityRevisions[key] == revision else { return }
            if !visible { panel.orderOut(nil); self.resetLayer(layer) }
            self.visibilityTasks.removeValue(forKey: key); completion?()
        }
    }
    private func resetLayer(_ layer: CALayer) {
        layer.removeAnimation(forKey: "AsterVisibility")
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.opacity = 1; layer.transform = CATransform3DIdentity; CATransaction.commit()
    }
    private func beginDrag(_ id: String) { dragging.insert(id); hoverTask?.cancel(); hoveredAgent = nil; closeChat() }
    private func endDrag(_ id: String) { dragging.remove(id); savePosition(id) }

    func hover(_ id: String, inside: Bool) {
        guard !collapsed, !suspended, dragging.isEmpty else { return }
        if inside {
            hoveredAgent = id; closeTask?.cancel()
            guard !pinned || activeChatID == id else { return }
            hoverTask?.cancel()
            hoverTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(240)) } catch { return }
                guard let self, self.hoveredAgent == id, !self.collapsed, !self.suspended, self.dragging.isEmpty, NSApplication.shared.modalWindow == nil else { return }
                self.showChat(id)
            }
        } else {
            if hoveredAgent == id { hoveredAgent = nil; hoverTask?.cancel() }
            scheduleClose()
        }
    }
    func chatHover(_ inside: Bool) { chatHovered = inside; if inside { closeTask?.cancel() } else { scheduleClose() } }
    private func scheduleClose() {
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
            guard let self, let id = self.activeChatID, !self.pinned, !self.chatHovered, self.hoveredAgent != id,
                  (self.drafts[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !self.store.isRunning(self.store.desktopMission(for: id)?.id) else { return }
            let pointer = NSEvent.mouseLocation
            if self.chat?.frame.insetBy(dx: -10, dy: -10).contains(pointer) == true || self.panels[id]?.frame.insetBy(dx: -10, dy: -10).contains(pointer) == true {
                self.scheduleClose(); return
            }
            self.closeChat()
        }
    }
    func togglePin() { pinned.toggle(); if !pinned { scheduleClose() } }
    func setDraft(_ text: String, agentID: String) {
        drafts[agentID] = String(text.prefix(24000))
        draftTask?.cancel()
        draftTask = Task { [weak self] in do { try await Task.sleep(for: .milliseconds(400)) } catch { return }; self?.flushDrafts() }
    }
    func flushDrafts() {
        draftTask?.cancel(); draftTask = nil
        for agent in store.state.specialists { store.setDesktopDraft(drafts[agent.id] ?? "", agentID: agent.id) }
    }
    func send() {
        guard let id = activeChatID, let text = drafts[id], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        flushDrafts()
        if store.sendDesktop(text, agentID: id) { pinned = true; drafts[id] = ""; flushDrafts() }
    }
    func showChat(_ id: String, focus: Bool = false) {
        guard !suspended, store.state.specialists.contains(where: { $0.id == id }) else { return }
        hoverTask?.cancel(); closeTask?.cancel()
        if collapsed { setCollapsed(false) }
        let changedAgent = activeChatID != id
        if changedAgent { flushDrafts(); activeChatID = id; pinned = false }
        if chat == nil {
            let panel = MiniChatPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            configure(panel, title: "Aster · Chat rápido"); panel.hasShadow = true; panel.becomesKeyOnlyIfNeeded = true
            panel.closeRequested = { [weak self] in self?.closeChat() }
            let hosting = MiniChatHostingView(rootView: DesktopChatView(desktop: self).environmentObject(store))
            hosting.hoverChanged = { [weak self] in self?.chatHover($0) }; panel.contentView = hosting
            chat = panel
        }
        chat?.title = LF("Chat rápido · %@", store.state.specialists.first { $0.id == id }?.name ?? "Aster")
        let preference = AsterAppearance(rawValue: defaults.string(forKey: "AsterAppearance") ?? "system")
        chat?.appearance = preference?.scheme.map { NSAppearance(named: $0 == .dark ? .darkAqua : .aqua) } ?? nil
        positionChat(id, animated: changedAgent && chat?.isVisible == true)
        if let chat { setVisible(chat, true, offset: CGPoint(x: 8, y: -4), refresh: changedAgent) }
        if focus { pinned = true; focusInput() }
    }
    private func positionChat(_ id: String, animated: Bool = false) {
        guard let anchor = panels[id], let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(CGPoint(x: anchor.frame.midX, y: anchor.frame.midY)) }) ?? NSScreen.main else { return }
        let frame = DesktopLayout.chatFrame(anchor: anchor.frame, screen: screen.visibleFrame)
        if animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18; context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                chat?.animator().setFrame(frame, display: true)
            }
        } else { chat?.setFrame(frame, display: true) }
    }
    func focusInput() {
        guard let chat else { return }; pinned = true; chat.makeKeyAndOrderFront(nil)
        func editor(in view: NSView?) -> NSTextView? {
            guard let view else { return nil }; if let text = view as? NSTextView, text.isEditable { return text }
            for child in view.subviews { if let found = editor(in: child) { return found } }; return nil
        }
        if let input = editor(in: chat.contentView) { chat.makeFirstResponder(input) }
    }
    func restorePinnedChatFocus() -> Bool {
        guard pinned, activeChatID != nil, chat?.isVisible == true, !suspended, !collapsed else { return false }
        focusInput(); return true
    }
    func closeChat(animated: Bool = true) {
        hoverTask?.cancel(); closeTask?.cancel(); flushDrafts()
        guard let chat else { activeChatID = nil; pinned = false; chatHovered = false; return }
        setVisible(chat, false, animated: animated, offset: CGPoint(x: 8, y: -4)) { [weak self] in
            self?.activeChatID = nil; self?.pinned = false; self?.chatHovered = false
        }
    }
    func expandChat(_ agentID: String? = nil) {
        guard let id = agentID ?? activeChatID else { return }
        if let mission = store.desktopMission(for: id) { store.openMission(mission.id) }
        else { store.select(id); store.selectedMission = nil; store.page = "Personajes" }
        closeChat(); open()
    }
}

final class MiniChatPanel: NSPanel {
    var closeRequested: () -> Void = {}
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { closeRequested() }
}

final class MiniChatHostingView<Content: View>: NSHostingView<Content> {
    var hoverChanged: (Bool) -> Void = { _ in }
    private var area: NSTrackingArea?
    override func updateTrackingAreas() {
        if let area { removeTrackingArea(area) }
        let tracking = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(tracking); area = tracking; super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { hoverChanged(true) }
    override func mouseExited(with event: NSEvent) { hoverChanged(false) }
}

struct CompanionInteraction: NSViewRepresentable {
    var name: String
    var open: () -> Void
    var talk: () -> Void
    var arrange: () -> Void
    var hide: () -> Void
    var moved: () -> Void
    var dragStarted: () -> Void
    var hover: (Bool) -> Void
    func makeNSView(context: Context) -> Handle { Handle() }
    func updateNSView(_ view: Handle, context: Context) {
        view.open = open; view.talk = talk; view.arrange = arrange; view.hide = hide; view.moved = moved; view.dragStarted = dragStarted; view.hover = hover
        view.setAccessibilityElement(true); view.setAccessibilityRole(.button); view.setAccessibilityLabel(LF("Hablar con %@", name))
        view.setAccessibilityHelp(L("Cursor para hablar · arrastra para mover · doble clic para abrir Aster"))
    }
    final class Handle: NSView {
        var open: () -> Void = {}; var talk: () -> Void = {}; var arrange: () -> Void = {}; var hide: () -> Void = {}
        var moved: () -> Void = {}; var dragStarted: () -> Void = {}; var hover: (Bool) -> Void = { _ in }
        private var area: NSTrackingArea?
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }
        override func updateTrackingAreas() {
            if let area { removeTrackingArea(area) }
            let tracking = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
            addTrackingArea(tracking); area = tracking; super.updateTrackingAreas()
        }
        override func mouseEntered(with event: NSEvent) { hover(true) }
        override func mouseExited(with event: NSEvent) { hover(false) }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount >= 2 { open(); return }
            let origin = window?.frame.origin ?? .zero; dragStarted(); window?.performDrag(with: event)
            let destination = window?.frame.origin ?? origin; moved()
            if hypot(destination.x - origin.x, destination.y - origin.y) < 3 { talk() }
        }
        override func rightMouseDown(with event: NSEvent) {
            let menu = NSMenu()
            for (title, action) in [("Chat rápido", #selector(talkMenu)), ("Abrir Aster", #selector(openMenu)), ("Ordenar arriba a la derecha", #selector(arrangeMenu)), ("Ocultar compañero", #selector(hideMenu))] {
                menu.addItem(withTitle: L(title), action: action, keyEquivalent: "").target = self
            }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
        override func accessibilityPerformPress() -> Bool { talk(); return true }
        @objc private func talkMenu() { talk() }; @objc private func openMenu() { open() }
        @objc private func arrangeMenu() { arrange() }; @objc private func hideMenu() { hide() }
    }
}
