import AppKit

struct ClipboardItem {
    let text: String
    let preview: String

    private static let previewLength = 500

    init(_ text: String) {
        self.text = text
        // Process only the first `previewLength` characters — avoids allocating
        // thousands of substrings when someone copies a large document.
        self.preview = text.prefix(Self.previewLength)
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ⏎ ")
    }
}

class ClipboardMonitor {

    private(set) var history: [ClipboardItem] = []
    private var lastChangeCount: Int
    private var timer: Timer?

    // Standard types that signal "do not store this" — http://nspasteboard.org
    private static let sensitiveTypes: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"), // passwords
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"), // transient data
    ]

    private static let maxItems    = 50
    private static let maxItemSize = 100_000 // utf16 code units ≈ 100 KB

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else { return } // Prevent double-start

        let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.check()
        }
        t.tolerance = 0.1 // Allow the OS to batch this wakeup with other timers.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func check() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        let types = pb.types ?? []
        guard !types.contains(where: { Self.sensitiveTypes.contains($0) }) else { return }

        guard let text = pb.string(forType: .string), !text.isEmpty else { return }
        guard text.utf16.count <= Self.maxItemSize else { return }
        guard history.first?.text != text else { return }

        history.removeAll { $0.text == text }
        history.insert(ClipboardItem(text), at: 0)
        if history.count > Self.maxItems {
            history.removeLast()
        }
    }
}
