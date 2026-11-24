import AppKit

@MainActor final class StickBallView: NSView {
    private weak var controller: StickWindowController?
    private var tracking: NSTrackingArea?
    private var hovering = false
    private var startMouse: NSPoint?
    private var startOrigin: NSPoint?
    private var dragged = false
    init(controller: StickWindowController) {
        self.controller = controller
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area); tracking = area
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill()
        let outerCircle = NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3))
        let shadow = NSShadow()
        shadow.shadowColor = .black.withAlphaComponent(hovering ? 0.20 : 0.14)
        shadow.shadowBlurRadius = hovering ? 5 : 4
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor.white.setFill()
        outerCircle.fill()
        NSGraphicsContext.restoreGraphicsState()

        let inset: CGFloat = hovering ? 6 : 7
        let innerCircle = NSBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset))
        NSColor(srgbRed: 0.96, green: 0.68, blue: 0.22, alpha: 1).setFill()
        innerCircle.fill()
        drawNoteMark()
    }
    private func drawNoteMark() {
        let paper = NSBezierPath(roundedRect: NSRect(x: 13, y: 14, width: 22, height: 20),
                                 xRadius: 4, yRadius: 4)
        NSColor(srgbRed: 1, green: 0.97, blue: 0.84, alpha: 1).setFill()
        paper.fill()

        let curl = NSBezierPath()
        curl.move(to: NSPoint(x: 26, y: 14))
        curl.curve(to: NSPoint(x: 35, y: 23), controlPoint1: NSPoint(x: 29, y: 17),
                   controlPoint2: NSPoint(x: 26, y: 23))
        curl.curve(to: NSPoint(x: 26, y: 14), controlPoint1: NSPoint(x: 34, y: 20),
                   controlPoint2: NSPoint(x: 30, y: 15))
        curl.close()
        NSColor(srgbRed: 1, green: 0.80, blue: 0.36, alpha: 1).setFill()
        curl.fill()

        NSColor(srgbRed: 0.75, green: 0.48, blue: 0.16, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 17, y: 28, width: 14, height: 1.5),
                     xRadius: 0.75, yRadius: 0.75).fill()
        NSBezierPath(roundedRect: NSRect(x: 17, y: 24, width: 12, height: 1.5),
                     xRadius: 0.75, yRadius: 0.75).fill()
        NSBezierPath(roundedRect: NSRect(x: 17, y: 20, width: 8, height: 1.5),
                     xRadius: 0.75, yRadius: 0.75).fill()
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true; controller?.ballHover(true) }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true; controller?.ballHover(false) }
    override func mouseDown(with event: NSEvent) { startMouse = NSEvent.mouseLocation; startOrigin = window?.frame.origin; dragged = false }
    override func mouseDragged(with event: NSEvent) {
        guard let startMouse, let startOrigin else { return }
        let point = NSEvent.mouseLocation; let dx = point.x - startMouse.x; let dy = point.y - startMouse.y
        if !dragged && hypot(dx, dy) <= 3 { return }
        dragged = true
        controller?.moveBall(to: NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy), ended: false)
    }
    override func mouseUp(with event: NSEvent) {
        if dragged, let startMouse, let startOrigin {
            let point = NSEvent.mouseLocation
            controller?.moveBall(to: NSPoint(x: startOrigin.x + point.x - startMouse.x, y: startOrigin.y + point.y - startMouse.y), ended: true)
        } else { controller?.open() }
        startMouse = nil; startOrigin = nil; dragged = false
    }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let languageItem = NSMenuItem(title: Copy.text("语言", "Language"), action: nil, keyEquivalent: "")
        let language = NSMenu(title: Copy.text("语言", "Language"))
        let zh = NSMenuItem(title: "简体中文", action: #selector(setLanguage(_:)), keyEquivalent: "")
        zh.target = self; zh.representedObject = "zh"; zh.state = Copy.chinese ? .on : .off
        let en = NSMenuItem(title: "English", action: #selector(setLanguage(_:)), keyEquivalent: "")
        en.target = self; en.representedObject = "en"; en.state = Copy.chinese ? .off : .on
        language.addItem(zh); language.addItem(en)
        languageItem.submenu = language
        menu.addItem(languageItem)
        let appearanceItem = NSMenuItem(title: Copy.text("外观", "Appearance"), action: nil, keyEquivalent: "")
        let appearance = NSMenu(title: Copy.text("外观", "Appearance"))
        let current = UserDefaults.standard.string(forKey: "appearance") ?? "system"
        let options: [(String, String)] = [("system", Copy.text("跟随系统", "System")), ("light", Copy.text("浅色", "Light")), ("dark", Copy.text("深色", "Dark"))]
        for (value, title) in options {
            let item = NSMenuItem(title: title, action: #selector(setAppearance(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = value; item.state = current == value ? .on : .off
            appearance.addItem(item)
        }
        appearanceItem.submenu = appearance
        menu.addItem(appearanceItem)
        menu.addItem(.separator())
        let about = NSMenuItem(title: Copy.text("关于 LiteStick", "About LiteStick"), action: #selector(aboutApp), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let quit = NSMenuItem(title: Copy.text("退出 LiteStick", "Quit LiteStick"), action: #selector(quitApp), keyEquivalent: "")
        quit.target = self; menu.addItem(quit)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    @objc private func setLanguage(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.representedObject as? String ?? "en", forKey: "language")
    }
    @objc private func setAppearance(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.representedObject as? String ?? "system", forKey: "appearance")
    }
    @objc private func aboutApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "LiteStick"
        alert.informativeText = Copy.text("V1.0.2\n随手一贴，随时取用。", "V1.0.2\nStick it here for later.")
        alert.alertStyle = .informational
        alert.runModal()
    }
    @objc private func quitApp() { controller?.quit() }
}

@MainActor enum StickyStrip {
    static let image: NSImage = {
        guard let url = Bundle.main.url(forResource: "LiteStick", withExtension: "icns"),
              let image = NSImage(contentsOf: url) else { return NSApp.applicationIconImage }
        return image
    }()
}
