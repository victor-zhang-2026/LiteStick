import SwiftUI
import AppKit

struct StickView: View {
    let controller: StickWindowController
    @State private var store = StickStore()
    @AppStorage("language") private var language = Locale.current.language.languageCode?.identifier == "zh" ? "zh" : "en"
    @AppStorage("appearance") private var appearance = "system"
    @Environment(\.colorScheme) private var systemScheme
    @State private var editing = false
    @State private var pinVisual = false
    @State private var showCopied = false
    @State private var dragPrevious: CGSize = .zero
    private func localized(_ chinese: String, _ english: String) -> String {
        language == "zh" ? chinese : english
    }
    private var dark: Bool {
        appearance == "dark" || (appearance == "system" && systemScheme == .dark)
    }
    private var surface: Color {
        dark ? Color(red: 40/255, green: 36/255, blue: 30/255) : Color(red: 1.0, green: 0.985, blue: 0.93)
    }
    private var editorBackground: Color {
        dark ? Color.white.opacity(0.07) : Color.black.opacity(0.035)
    }
    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color(nsColor: .separatorColor).opacity(0.55)).frame(height: 0.5)
            editor
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .preferredColorScheme(appearance == "system" ? nil : (dark ? .dark : .light))
        .onHover(perform: controller.panelHover)
        .onReceive(NotificationCenter.default.publisher(for: .liteStickPanelDidOpen)) { _ in editing = false }
        .onReceive(NotificationCenter.default.publisher(for: .liteStickEditorDidEnd)) { _ in editing = false }
        .onAppear { pinVisual = controller.pinned }
    }
    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: StickyStrip.image)
                .resizable()
                .accessibilityHidden(true)
                .frame(width: 28, height: 28)
            Text("LiteStick")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(nsColor: .labelColor))
            if showCopied {
                Text(localized("已复制", "Copied"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            button("doc.on.doc", help: localized("复制全部", "Copy All"), disabled: store.text.isEmpty) { copyAll() }
            button(pinVisual ? "pin.fill" : "pin", help: pinVisual ? localized("取消固定", "Unpin Panel") : localized("固定浮窗", "Pin Panel")) {
                controller.togglePin(); pinVisual = controller.pinned
            }
            button("trash", help: localized("清空", "Clear"), disabled: store.text.isEmpty) { clearAll() }
            button("xmark", help: localized("收起", "Close"), hoverColor: .red) {
                editing = false
                controller.dismissPanel()
                pinVisual = false
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .zIndex(10)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 4).onChanged { value in
            let delta = CGSize(width: value.translation.width - dragPrevious.width, height: -(value.translation.height - dragPrevious.height))
            dragPrevious = value.translation
            controller.movePanel(by: NSSize(width: delta.width, height: delta.height), ended: false)
        }.onEnded { _ in dragPrevious = .zero; controller.movePanel(by: .zero, ended: true) })
    }
    private var editor: some View {
        StickEditor(text: $store.text,
                    onEditingChange: { active in
                        editing = active
                        controller.setEditing(active)
                    },
                    onEditorClick: controller.activateForEditing)
            .background(editorBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(editing ? Color.accentColor.opacity(0.65) : Color.secondary.opacity(0.2))
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                if store.text.isEmpty && !editing {
                    Text(localized("随手记点什么……", "Stick something here…"))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 10)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func copyAll() {
        guard !store.text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(store.text, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.2)) { showCopied = false }
        }
    }
    private func clearAll() {
        guard !store.text.isEmpty else { return }
        // The editor performs an undoable deletion and updates the binding;
        // fall back only if no editor is reachable.
        NotificationCenter.default.post(name: .liteStickClearRequested, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak store] in
            guard let store, !store.text.isEmpty else { return }
            store.clear()
        }
    }
    private func button(_ symbol: String, help: String, disabled: Bool = false, hoverColor: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(disabled ? Color.secondary.opacity(0.4) : Color.primary)
        }
        .buttonStyle(StickHeaderButtonStyle(hoverColor: hoverColor))
        .focusHelp(help)
        .disabled(disabled)
    }
}

private struct StickEditor: NSViewRepresentable {
    @Binding var text: String
    let onEditingChange: (Bool) -> Void
    let onEditorClick: (NSTextView) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, onEditingChange: onEditingChange) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = StickScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let editor = StickTextView(frame: .zero)
        editor.delegate = context.coordinator
        editor.onEditingChange = onEditingChange
        editor.onEditorClick = onEditorClick
        editor.string = text
        editor.font = .systemFont(ofSize: 14)
        editor.textColor = .labelColor
        editor.insertionPointColor = .labelColor
        editor.drawsBackground = false
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainerInset = NSSize(width: 5, height: 8)
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        scrollView.documentView = editor
        let token = NotificationCenter.default.addObserver(forName: .liteStickClearRequested, object: nil, queue: .main) { [weak editor] _ in
            MainActor.assumeIsolated {
                guard let editor else { return }
                let length = (editor.string as NSString).length
                guard length > 0 else { return }
                editor.setSelectedRange(NSRange(location: 0, length: length))
                editor.insertText("", replacementRange: editor.selectedRange())
            }
        }
        context.coordinator.observer = token
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onEditingChange = onEditingChange
        guard let editor = scrollView.documentView as? StickTextView else { return }
        editor.onEditingChange = onEditingChange
        editor.onEditorClick = onEditorClick
        if editor.string != text { editor.string = text }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onEditingChange: (Bool) -> Void
        var observer: Any?
        init(text: Binding<String>, onEditingChange: @escaping (Bool) -> Void) {
            self.text = text
            self.onEditingChange = onEditingChange
        }
        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            text.wrappedValue = editor.string
        }
    }
}

private final class StickScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let editor = documentView as? NSTextView else { return }
        let viewport = contentView.bounds.size
        editor.minSize = NSSize(width: 0, height: viewport.height)
        let size = NSSize(width: viewport.width, height: max(viewport.height, editor.frame.height))
        if editor.frame.size != size { editor.setFrameSize(size) }
    }
}

private final class StickTextView: NSTextView {
    var onEditingChange: ((Bool) -> Void)?
    var onEditorClick: ((NSTextView) -> Void)?
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onEditingChange?(true) }
        return result
    }
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { onEditingChange?(false) }
        return result
    }
    override var needsPanelToBecomeKey: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onEditorClick?(self)
        super.mouseDown(with: event)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 && !hasMarkedText() {
            NotificationCenter.default.post(name: .liteStickEscape, object: nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

private struct StickHeaderButtonStyle: ButtonStyle {
    var hoverColor: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        StickHeaderButtonBody(configuration: configuration, hoverColor: hoverColor)
    }

    private struct StickHeaderButtonBody: View {
        let configuration: Configuration
        let hoverColor: Color
        @State private var hovering = false

        var body: some View {
            configuration.label
                .symbolRenderingMode(.monochrome)
                .frame(width: 28, height: 28)
                .background(
                    hoverColor.opacity(configuration.isPressed ? 0.12 : hovering ? 0.08 : 0),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}

private struct StickHelpModifier: ViewModifier {
    let text: String
    @State private var isPresented = false
    @State private var hoverToken = UUID()

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(text)
            .onHover { hovering in
                let token = UUID()
                hoverToken = token
                if hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        guard hoverToken == token else { return }
                        isPresented = true
                    }
                } else {
                    isPresented = false
                }
            }
            .overlay(alignment: .bottom) {
                if isPresented {
                    Text(text)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        .offset(x: 0, y: 28)
                        .allowsHitTesting(false)
                }
            }
            .zIndex(isPresented ? 20 : 0)
    }
}

private extension View {
    func focusHelp(_ text: String) -> some View {
        modifier(StickHelpModifier(text: text))
    }
}
