import AppKit

class ClipboardMonitor {
    static let shared = ClipboardMonitor()
    
    private var changeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private var queueManager: QueueManager?
    private var isPaused = false
    
    // Callback when a new item is captured
    var onCapture: ((String) -> Void)?
    
    func start(queueManager: QueueManager) {
        self.queueManager = queueManager
        self.changeCount = NSPasteboard.general.changeCount
        
        // Timer runs on the main runloop, polling the clipboard every 300ms
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func pause() {
        isPaused = true
    }
    
    func resume() {
        // Synchronize our changeCount with the system before unpausing
        // This ensures the update to the pasteboard we just made during paste isn't captured
        self.changeCount = NSPasteboard.general.changeCount
        isPaused = false
    }
    
    private func checkClipboard() {
        guard let queueManager = queueManager, queueManager.isSessionActive, !isPaused else {
            // Keep the changeCount in sync even if inactive or paused,
            // so we don't capture old clipboard contents when we resume/activate
            self.changeCount = NSPasteboard.general.changeCount
            return
        }
        
        let pb = NSPasteboard.general
        if pb.changeCount != changeCount {
            changeCount = pb.changeCount
            
            // Only capture string content (plain text, URLs, formatted code, etc.)
            if let content = pb.string(forType: .string) {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    // Update our queue manager
                    queueManager.addItem(content: content)
                    onCapture?(content)
                }
            }
        }
    }
}
