import AppKit

// MARK: - Helpers

private extension NSView {
    /// Pins all four edges of `self` to another view using Auto Layout.
    func pinEdges(to other: NSView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: other.topAnchor),
            leadingAnchor.constraint(equalTo: other.leadingAnchor),
            trailingAnchor.constraint(equalTo: other.trailingAnchor),
            bottomAnchor.constraint(equalTo: other.bottomAnchor),
        ])
    }
}

// MARK: - KeyablePanel

/// Borderless NSPanel that can still become the key window.
/// (A borderless NSWindow/NSPanel returns false for canBecomeKey by default.)
private class KeyablePanel: NSPanel {
    override var canBecomeKey:  Bool { true  }
    override var canBecomeMain: Bool { false }
}

// MARK: - ClipboardCellView

private class ClipboardCellView: NSView {

    private let badge = NSTextField(labelWithString: "")
    private let label = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)

        badge.font      = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        badge.alignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false

        label.font                 = .systemFont(ofSize: 13)
        label.textColor            = .labelColor // constant — set once, not on every configure
        label.lineBreakMode        = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(badge)
        addSubview(label)

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(index: Int, item: ClipboardItem) {
        badge.stringValue = index < 9 ? "\(index + 1)" : "·"
        badge.textColor   = index < 5 ? .secondaryLabelColor : .tertiaryLabelColor
        label.stringValue = item.preview // preview computed once on item creation
    }
}

// MARK: - ClipboardTableView

private class ClipboardTableView: NSTableView {

    var onEnter:     (() -> Void)?
    var onEscape:    (() -> Void)?
    var onNumberKey: ((Int) -> Void)?

    // kVK_ANSI_1…5 = 18, 19, 20, 21, 23  (note: 22 is kVK_ANSI_6)
    private static let quickSelectKeys: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4]

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: // Return / numpad Enter
            onEnter?()
        case 53:     // Escape
            onEscape?()
        default:
            if let idx = Self.quickSelectKeys[event.keyCode] {
                onNumberKey?(idx)
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

// MARK: - ClipboardWindowController

class ClipboardWindowController: NSWindowController {

    private static let cellID   = NSUserInterfaceItemIdentifier("ClipboardCell")
    private static let columnID = NSUserInterfaceItemIdentifier("ClipboardColumn")

    private var items: [ClipboardItem] = []
    private var previousApp: NSRunningApplication?
    private let tableView  = ClipboardTableView()
    private let scrollView = NSScrollView()

    init() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor         = .clear
        panel.isOpaque                = false
        panel.hasShadow               = true
        panel.isMovableByWindowBackground = true
        panel.level                   = .floating
        panel.hidesOnDeactivate       = false
        panel.isReleasedWhenClosed    = false
        super.init(window: panel)
        panel.delegate = self
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Show / hide

    func show(items: [ClipboardItem]) {
        self.items = items
        tableView.reloadData()

        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }

        guard let window else { return }
        window.center()

        previousApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(tableView)
    }

    func closeWindow() {
        window?.orderOut(nil)
        restorePreviousApp()
    }

    // MARK: Private

    private func restorePreviousApp() {
        // .activateIgnoringOtherApps is a no-op since macOS 14;
        // activate(options: []) is the forward-compatible form.
        previousApp?.activate(options: [])
        previousApp = nil
    }

    private func selectItem(at index: Int) {
        guard index >= 0, index < items.count else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(items[index].text, forType: .string)
        closeWindow()
    }

    @objc private func doubleClicked() {
        let row = tableView.clickedRow
        if row >= 0 { selectItem(at: row) }
    }

    // MARK: UI setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let vfx = makeBackground()
        contentView.addSubview(vfx)
        vfx.pinEdges(to: contentView)

        configureTableView()

        scrollView.documentView       = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType         = .noBorder
        scrollView.backgroundColor    = .clear

        let title     = makeLabel("Clipboard History",
                                  font: .systemFont(ofSize: 12, weight: .semibold),
                                  color: .secondaryLabelColor)
        let separator = { let b = NSBox(); b.boxType = .separator; return b }()
        let hint      = makeLabel("↑↓  navigate    1–5  quick pick    ↵  select    ⎋  close",
                                  font: .systemFont(ofSize: 11),
                                  color: .tertiaryLabelColor)

        let stack = NSStackView(views: [title, separator, scrollView, hint])
        stack.orientation = .vertical
        stack.spacing     = 6
        stack.edgeInsets  = NSEdgeInsets(top: 12, left: 0, bottom: 10, right: 0)

        vfx.addSubview(stack)
        stack.pinEdges(to: vfx)
    }

    private func makeBackground() -> NSVisualEffectView {
        let vfx = NSVisualEffectView()
        vfx.material     = .popover
        vfx.blendingMode = .behindWindow
        vfx.state        = .active
        vfx.wantsLayer   = true
        if let layer = vfx.layer {
            layer.cornerRadius  = 12
            layer.masksToBounds = true
        }
        return vfx
    }

    private func makeLabel(_ string: String, font: NSFont, color: NSColor) -> NSTextField {
        let label       = NSTextField(labelWithString: string)
        label.font      = font
        label.textColor = color
        label.alignment = .center
        return label
    }

    private func configureTableView() {
        let column = NSTableColumn(identifier: Self.columnID)
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.headerView       = nil
        tableView.rowHeight        = 38
        tableView.backgroundColor  = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.focusRingType    = .none
        tableView.dataSource       = self
        tableView.delegate         = self
        tableView.doubleAction     = #selector(doubleClicked)
        tableView.target           = self

        tableView.onEnter = { [weak self] in
            guard let self else { return }
            let row = self.tableView.selectedRow
            if row >= 0 { self.selectItem(at: row) }
        }
        tableView.onEscape    = { [weak self] in self?.closeWindow() }
        tableView.onNumberKey = { [weak self] idx in self?.selectItem(at: idx) }
    }
}

// MARK: - NSWindowDelegate

extension ClipboardWindowController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        // Close whenever focus leaves the panel: clicking outside, Cmd+Tab, etc.
        // Guard against re-entry: orderOut can itself trigger this callback.
        guard window?.isVisible == true else { return }
        closeWindow()
    }
}

// MARK: - NSTableViewDataSource

extension ClipboardWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
}

// MARK: - NSTableViewDelegate

extension ClipboardWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: Self.cellID, owner: nil) as? ClipboardCellView
                   ?? ClipboardCellView()
        cell.identifier = Self.cellID
        cell.configure(index: row, item: items[row])
        return cell
    }
}
