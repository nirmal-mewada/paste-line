import AppKit

class PasteEngine {
    static let shared = PasteEngine()
    
    /// Releases modifier keys programmatically to prevent interference from physically held hotkeys (like Control/Option).
    private func releaseModifierKeys() {
        let source = CGEventSource(stateID: .privateState)
        // Keycodes: Left Control (0x3B), Right Control (0x3E), Left Option (0x3A), Right Option (0x3D), Left Shift (0x38), Right Shift (0x3C)
        let modifierKeys: [CGKeyCode] = [0x3B, 0x3E, 0x3A, 0x3D, 0x38, 0x3C]
        for keyCode in modifierKeys {
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                keyUp.post(tap: .cgSessionEventTap)
            }
        }
    }
    
    /// Simulates pressing Cmd+V to paste the current clipboard contents into the active application.
    func performSystemPaste() {
        // Release physical modifier keys first
        releaseModifierKeys()
        
        let source = CGEventSource(stateID: .privateState)
        
        // Virtual key code for 'V' is 0x09
        let virtualKeyV: CGKeyCode = 0x09
        
        // Create KeyDown and KeyUp events with Command flag
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyV, keyDown: true) else {
            return
        }
        keyDown.flags = CGEventFlags.maskCommand
        
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyV, keyDown: false) else {
            return
        }
        keyUp.flags = CGEventFlags.maskCommand
        
        // Post to the session event tap (places keypresses in the active app's input stream)
        keyDown.post(tap: CGEventTapLocation.cgSessionEventTap)
        keyUp.post(tap: CGEventTapLocation.cgSessionEventTap)
    }
    
    /// Pops the next item from the queue according to current FIFO/LIFO rules,
    /// sets it to the pasteboard, and triggers a system paste.
    func pasteNext(queueManager: QueueManager, onBeforePaste: (() -> Void)? = nil, onAfterPaste: (() -> Void)? = nil) {
        guard let nextItem = queueManager.popNextItem() else {
            // Beep to alert the user that the clipboard stack is empty
            NSSound.beep()
            return
        }
        
        onBeforePaste?()
        
        // 1. Temporarily pause the monitor to prevent it from capturing our own write
        ClipboardMonitor.shared.pause()
        
        // 2. Put the item in the general pasteboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(nextItem.content, forType: .string)
        
        // 3. Wait a short delay for the pasteboard write to register and user to begin releasing keys
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            // 4. Perform the system paste
            self.performSystemPaste()
            
            // 5. Wait a bit longer for the paste operation to complete in the target app,
            // then re-enable clipboard monitoring
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                ClipboardMonitor.shared.resume()
                onAfterPaste?()
            }
        }
    }
}
