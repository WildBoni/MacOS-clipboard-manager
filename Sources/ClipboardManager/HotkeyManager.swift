import Carbon.HIToolbox

@MainActor
class HotkeyManager {

    /// Default hotkey: ⌘⇧V. Change these to customise the trigger.
    static let defaultKeyCode   = UInt32(kVK_ANSI_V)
    static let defaultModifiers = UInt32(cmdKey | shiftKey)

    var onHotKey: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register(keyCode: UInt32, modifiers: UInt32) {
        guard hotKeyRef == nil else { return } // Prevent double-registration

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = Self.fourCharCode("CMgr")
        hotKeyID.id = 1

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  OSType(kEventHotKeyPressed)
        )

        // Pass `self` as a raw pointer so the C callback can invoke `onHotKey`.
        // `passUnretained` is safe: HotkeyManager is owned by AppDelegate
        // and lives for the entire lifetime of the app.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let ptr = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { manager.onHotKey?() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetApplicationEventTarget(), 0,
            &hotKeyRef
        )
    }

    deinit {
        if let ref = hotKeyRef      { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef { RemoveEventHandler(ref)    }
    }

    private static func fourCharCode(_ s: String) -> OSType {
        s.utf8.prefix(4).reduce(0) { ($0 << 8) | OSType($1) }
    }
}
