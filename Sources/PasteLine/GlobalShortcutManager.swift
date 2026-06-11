import Carbon
import AppKit

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    
    private var hotKeys: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerInstalled = false
    
    // Action Callbacks
    var onStartSession: (() -> Void)?
    var onStopSession: (() -> Void)?
    var onPasteNext: (() -> Void)?
    
    // Carbon Keyboard Constants
    private static let kEventClassKeyboard = makeFourCharCode("keyb")
    private static let kEventHotKeyPressed = UInt32(5)
    private static let kEventParamDirectObject = makeFourCharCode("----")
    private static let typeEventHotKeyID = makeFourCharCode("hkid")
    private static let kPasteLineSignature = makeFourCharCode("PLHk")
    
    func registerShortcuts() {
        // 1. Clear any currently registered shortcuts
        unregisterShortcuts()
        
        let appTarget = GetApplicationEventTarget()
        var eventSpec = EventTypeSpec(eventClass: OSType(Self.kEventClassKeyboard), eventKind: Self.kEventHotKeyPressed)
        
        // 2. Install event handler if not already installed
        if !eventHandlerInstalled {
            let eventHandlerUPP: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let paramStatus = GetEventParameter(
                    event,
                    EventParamName(GlobalShortcutManager.kEventParamDirectObject),
                    EventParamType(GlobalShortcutManager.typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if paramStatus == noErr {
                    let id = hotKeyID.id
                    DispatchQueue.main.async {
                        GlobalShortcutManager.shared.handleHotKey(id: id)
                    }
                }
                return noErr
            }
            
            let status = InstallEventHandler(appTarget, eventHandlerUPP, 1, &eventSpec, nil, nil)
            if status != noErr {
                print("Failed to install Carbon hotkey event handler: \(status)")
            } else {
                eventHandlerInstalled = true
            }
        }
        
        // 3. Load settings from UserDefaults (fallback to default ⌃⌥⌘ + S/X/V)
        // Default modifiers: Ctrl (4096) + Opt (2048) + Cmd (256) = 6400
        let startCode = UserDefaults.standard.object(forKey: "PL_start_code") as? UInt32 ?? 1   // S
        let startMods = UserDefaults.standard.object(forKey: "PL_start_mods") as? UInt32 ?? 6400
        
        let stopCode = UserDefaults.standard.object(forKey: "PL_stop_code") as? UInt32 ?? 7     // X
        let stopMods = UserDefaults.standard.object(forKey: "PL_stop_mods") as? UInt32 ?? 6400
        
        let pasteCode = UserDefaults.standard.object(forKey: "PL_paste_code") as? UInt32 ?? 9   // V
        let pasteMods = UserDefaults.standard.object(forKey: "PL_paste_mods") as? UInt32 ?? 6400
        
        registerHotKey(id: 1, keyCode: startCode, modifiers: startMods)
        registerHotKey(id: 2, keyCode: stopCode, modifiers: stopMods)
        registerHotKey(id: 3, keyCode: pasteCode, modifiers: pasteMods)
        
        print("Shortcuts registered. Start: code \(startCode) mods \(startMods). Stop: code \(stopCode) mods \(stopMods). Paste: code \(pasteCode) mods \(pasteMods).")
    }
    
    func unregisterShortcuts() {
        for (id, ref) in hotKeys {
            let status = UnregisterEventHotKey(ref)
            if status != noErr {
                print("Failed to unregister hotkey \(id): \(status)")
            }
        }
        hotKeys.removeAll()
    }
    
    private func registerHotKey(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(Self.kPasteLineSignature), id: id)
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            hotKeys[id] = ref
        } else {
            print("Failed to register hotkey \(id): Carbon Status \(status)")
        }
    }
    
    fileprivate func handleHotKey(id: UInt32) {
        switch id {
        case 1:
            onStartSession?()
        case 2:
            onStopSession?()
        case 3:
            onPasteNext?()
        default:
            break
        }
    }
}

// Helper to convert 4-char string to OSType
func makeFourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for char in string.utf8 {
        result = (result << 8) + FourCharCode(char)
    }
    return result
}
