import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private let clipboardMonitor = ClipboardMonitor()
    private let hotkeyManager    = HotkeyManager()
    private var windowController: ClipboardWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        let wc = windowController ?? ClipboardWindowController()
        windowController = wc

        if wc.window?.isVisible == true {
            wc.closeWindow()
        } else {
            wc.show(items: clipboardMonitor.history)
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
