import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let popover = NSPopover()
    let queueManager = QueueManager()
    
    private var badgeTimer: Timer?
    private var statusImage: NSImage?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Initialize the status item in the macOS Menu Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Configure status bar icon using native SF Symbol
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            statusImage = NSImage(systemSymbolName: "paperclip.badge.ellipsis", accessibilityDescription: "PasteLine")?
                .withSymbolConfiguration(config)
            
            button.image = statusImage
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            // Enable right mouse events to support the right-click menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 2. Configure the popover holding the SwiftUI view
        popover.contentSize = NSSize(width: 330, height: 450)
        popover.behavior = .transient // Dismisses popover when clicking outside
        
        let popoverView = PopoverView(queueManager: queueManager)
        popover.contentViewController = NSHostingController(rootView: popoverView)
        
        // 3. Register global shortcuts using Carbon
        GlobalShortcutManager.shared.onStartSession = { [weak self] in
            self?.queueManager.startSession()
            self?.showTemporaryIndicator(text: "Session Active")
        }
        
        GlobalShortcutManager.shared.onStopSession = { [weak self] in
            self?.queueManager.stopSession()
            self?.showTemporaryIndicator(text: "Session Stopped")
        }
        
        GlobalShortcutManager.shared.onPasteNext = { [weak self] in
            guard let self = self else { return }
            PasteEngine.shared.pasteNext(
                queueManager: self.queueManager,
                onBeforePaste: {
                    self.showTemporaryIndicator(text: "Pasted!")
                }
            )
        }
        
        GlobalShortcutManager.shared.registerShortcuts()
        
        // 4. Start Clipboard Monitor
        ClipboardMonitor.shared.start(queueManager: queueManager)
        
        // 5. Connect capture callback to show visual feedback on the menu bar icon
        ClipboardMonitor.shared.onCapture = { [weak self] _ in
            guard let self = self else { return }
            let count = self.queueManager.items.count
            self.showTemporaryIndicator(text: "Captured #\(count)")
        }
        
        print("PasteLine App Loaded Successfully!")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stop()
    }
    
    // MARK: - Actions
    
    @objc func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        
        // Check for right-click or Control+left-click to show context menu
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }
    
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Focus the popover so it can handle keystrokes
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        // Title item (disabled)
        let titleItem = NSMenuItem(title: "PasteLine v1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Session toggle
        let sessionTitle = queueManager.isSessionActive ? "Stop Monitoring Session" : "Start Monitoring Session"
        let sessionItem = NSMenuItem(title: sessionTitle, action: #selector(toggleSessionFromMenu), keyEquivalent: "")
        sessionItem.target = self
        menu.addItem(sessionItem)
        
        // Clear queue
        let clearItem = NSMenuItem(title: "Clear Queue (\(queueManager.items.count) items)", action: #selector(clearSessionFromMenu), keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = !queueManager.items.isEmpty
        menu.addItem(clearItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit PasteLine", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }
    
    @objc func toggleSessionFromMenu() {
        if queueManager.isSessionActive {
            queueManager.stopSession()
        } else {
            queueManager.startSession()
        }
    }
    
    @objc func clearSessionFromMenu() {
        // Simple confirmation before clearing from the status bar menu directly
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard Queue?"
        alert.informativeText = "Are you sure you want to delete all \(queueManager.items.count) captured snippets in the current session?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            queueManager.clearSession()
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Visual Feedback Helper
    
    private func showTemporaryIndicator(text: String) {
        guard let button = statusItem.button else { return }
        
        badgeTimer?.invalidate()
        
        // Display custom badge text in menu bar
        button.title = text
        button.image = nil // Hide icon so text fits clean
        
        // Restore standard icon after 1.5 seconds
        badgeTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            button.title = ""
            button.image = self.statusImage
        }
    }
}
