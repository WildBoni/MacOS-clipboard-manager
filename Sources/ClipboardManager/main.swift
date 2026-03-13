import AppKit

// main.swift is always invoked on the main thread; tell the Swift
// concurrency checker about this so @MainActor types can be used here.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // No dock icon
    app.run()
}
