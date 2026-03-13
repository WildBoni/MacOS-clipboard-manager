import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private let clipboardMonitor = ClipboardMonitor()
    private let hotkeyManager    = HotkeyManager()

    private lazy var windowController: ClipboardWindowController = {
        let wc = ClipboardWindowController()
        wc.onDeleteItem = { [weak self] text in
            self?.clipboardMonitor.remove(text: text)
        }
        return wc
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessibility access is required to post synthetic paste (Cmd+V) events.
        // AXIsProcessTrustedWithOptions is idempotent — safe to call unconditionally.
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        )
        setupMenu()
        clipboardMonitor.start()

        hotkeyManager.onHotKey = { [weak self] in
            self?.toggleClipboardWindow()
        }
        hotkeyManager.register(
            keyCode:   HotkeyManager.defaultKeyCode,
            modifiers: HotkeyManager.defaultModifiers
        )
    }

    private func toggleClipboardWindow() {
        if windowController.window?.isVisible == true {
            windowController.closeWindow()
        } else {
            windowController.show(items: clipboardMonitor.history)
        }
    }

    private func setupMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(
            title: "Quit ClipboardManager",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
