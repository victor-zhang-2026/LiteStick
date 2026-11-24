import AppKit
import SwiftUI
import Observation

extension Notification.Name {
    static let liteStickPanelDidOpen = Notification.Name("LiteStickPanelDidOpen")
    static let liteStickEditorDidEnd = Notification.Name("LiteStickEditorDidEnd")
    static let liteStickClearRequested = Notification.Name("LiteStickClearRequested")
    static let liteStickEscape = Notification.Name("LiteStickEscape")
}

enum Copy {
    static var chinese: Bool { UserDefaults.standard.string(forKey: "language") == "zh" || (UserDefaults.standard.string(forKey: "language") == nil && Locale.current.language.languageCode?.identifier == "zh") }
    static func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }
}

@main @MainActor final class LiteStickApp: NSObject, NSApplicationDelegate {
    private var controller: StickWindowController!
    static func main() {
        let app = NSApplication.shared
        let delegate = LiteStickApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        let main = NSMenu()
        let appItem = NSMenuItem()
        let menu = NSMenu()
        menu.addItem(withTitle: "About LiteStick", action: #selector(LiteStickApp.showAbout), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LiteStick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = menu; main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit; main.addItem(editItem)
        app.mainMenu = main
        app.run()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StickWindowController()
        controller.show()
    }
    @objc func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "LiteStick"
        alert.informativeText = Copy.text("V1.0.2\n随手一贴，随时取用。", "V1.0.2\nStick it here for later.")
        alert.alertStyle = .informational
        alert.runModal()
    }
}

final class StickPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class StickWindowController: NSObject {
    private let placement = FloatingPlacement()
    private var ball: StickPanel!
    private var panel: StickPanel!
    private var panelClickMonitor: Any?
    private var outsideClickMonitor: Any?
    private var closeWork: DispatchWorkItem?
    private var editing = false
    private var dragging = false
    private(set) var pinned = UserDefaults.standard.bool(forKey: "pinned")
    private(set) var opened = false
    private let ballSize = NSSize(width: 48, height: 48)
    private let panelSize = NSSize(width: 336, height: 320)
    private static let overlayLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))

    override init() {
        super.init()
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(forName: .liteStickEscape, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.dismissPanel() }
        }
    }
    private func prepare(_ window: StickPanel) {
        window.level = Self.overlayLevel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
    }
    private func setup() {
        ball = StickPanel(contentRect: NSRect(origin: .zero, size: ballSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        prepare(ball)
        ball.hasShadow = false
        ball.contentView = StickBallView(controller: self)
        panel = StickPanel(contentRect: NSRect(origin: .zero, size: panelSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        prepare(panel)
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: StickView(controller: self))
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        panelClickMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            guard let self else { return event }
            if event.window !== self.panel, event.window !== self.ball {
                self.closeIfClickedOutside()
            } else if event.type == .leftMouseDown, event.window === self.panel,
                      let editor = self.panel.firstResponder as? NSTextView {
                let point = editor.convert(event.locationInWindow, from: nil)
                if !editor.visibleRect.contains(point) {
                    self.endEditing()
                }
            }
            return event
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            self?.closeIfClickedOutside()
        }
    }
    private func closeIfClickedOutside() {
        let point = NSEvent.mouseLocation
        guard opened, !pinned, !dragging,
              !ball.frame.contains(point), !panel.frame.contains(point) else { return }
        cancelClose()
        close()
    }
    func show() {
        let fallback: NSPoint
        if let screen = NSScreen.main {
            fallback = NSPoint(x: screen.visibleFrame.maxX - 58, y: screen.visibleFrame.midY - 24)
        } else { fallback = NSPoint(x: 800, y: 400) }
        placement.restore(ball, fallback: fallback)
        ball.orderFrontRegardless()
        if pinned { open() }
    }
    func ballHover(_ active: Bool) { active ? open() : scheduleClose() }
    func panelHover(_ active: Bool) { if active { cancelClose() } else { scheduleClose() } }
    func setEditing(_ active: Bool) {
        editing = active
        if active { cancelClose() } else { scheduleClose() }
    }
    private func setDragging(_ active: Bool) { dragging = active; if active { cancelClose() } else { scheduleClose() } }
    func togglePin() {
        pinned.toggle()
        UserDefaults.standard.set(pinned, forKey: "pinned")
        if pinned { open() } else { scheduleClose() }
    }
    func activateForEditing(_ editor: NSTextView) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKey()
        panel.makeFirstResponder(editor)
    }
    func dismissPanel() {
        pinned = false
        UserDefaults.standard.set(false, forKey: "pinned")
        editing = false
        cancelClose()
        close()
    }
    func endEditing() { panel.makeFirstResponder(nil) }
    func open() {
        cancelClose()
        guard !opened, !dragging else { return }
        opened = true
        positionPanel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        ball.orderFrontRegardless()
        panel.makeFirstResponder(nil)
        NotificationCenter.default.post(name: .liteStickPanelDidOpen, object: nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }
    private func close() {
        guard opened else { return }
        opened = false
        panel.makeFirstResponder(nil)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.opened else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
            }
        })
    }
    private func scheduleClose() {
        cancelClose()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.pinned, !self.editing, !self.dragging, self.opened else { return }
            let pointer = NSEvent.mouseLocation
            guard !self.ball.frame.contains(pointer), !self.panel.frame.contains(pointer) else { return }
            self.close()
        }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    private func cancelClose() { closeWork?.cancel(); closeWork = nil }
    func moveBall(to origin: NSPoint, ended: Bool) {
        setDragging(!ended)
        ball.setFrameOrigin(origin)
        if ended {
            constrainBall()
            placement.remember(ball)
        }
        if opened { positionPanel() }
    }
    private func constrainBall() {
        let center = NSPoint(x: ball.frame.midX, y: ball.frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? ball.screen ?? NSScreen.main
        guard let frame = screen?.visibleFrame.insetBy(dx: 8, dy: 8) else { return }
        ball.setFrameOrigin(NSPoint(x: min(max(ball.frame.minX, frame.minX), frame.maxX - ballSize.width), y: min(max(ball.frame.minY, frame.minY), frame.maxY - ballSize.height)))
    }
    private func positionPanel() {
        let center = NSPoint(x: ball.frame.midX, y: ball.frame.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        let left = ball.frame.minX - visible.minX
        let right = visible.maxX - ball.frame.maxX
        let x = left >= panelSize.width || left >= right ? ball.frame.minX - panelSize.width - 4 : ball.frame.maxX + 4
        let origin = NSPoint(x: min(max(x, visible.minX), visible.maxX - panelSize.width), y: min(max(ball.frame.midY - panelSize.height / 2, visible.minY), visible.maxY - panelSize.height))
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }
    @objc private func screenChanged() {
        placement.afterScreenChange { [weak self] in
            guard let self, !self.dragging else { return }
            self.placement.restore(self.ball, fallback: self.ball.frame.origin)
            if self.opened { self.positionPanel() }
            self.ball.orderFrontRegardless()
        }
    }
    func quit() { NSApplication.shared.terminate(nil) }
}
