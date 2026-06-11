import SwiftUI
import ApplicationServices

struct PopoverView: View {
    @ObservedObject var queueManager: QueueManager
    
    @State private var editingItem: ClipboardItem? = nil
    @State private var editContent: String = ""
    @State private var showClearConfirmation = false
    @State private var isPulseActive = false
    @State private var isAccessibilityTrusted = AXIsProcessTrusted()
    @State private var isShowingSettings = false
    
    // Timer to poll accessibility status while the popover is open
    let accessibilityTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Group {
            if isShowingSettings {
                SettingsView(isPresented: $isShowingSettings)
            } else {
                VStack(spacing: 0) {
                    // Header
                    HeaderView(
                        isSessionActive: queueManager.isSessionActive,
                        onToggleSession: {
                            if queueManager.isSessionActive {
                                queueManager.stopSession()
                            } else {
                                queueManager.startSession()
                            }
                        },
                        onSettings: {
                            withAnimation(.spring()) {
                                isShowingSettings = true
                            }
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            
            if !isAccessibilityTrusted {
                AccessibilityWarningView(onFix: {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                    AXIsProcessTrustedWithOptions(options as CFDictionary)
                    
                    // Fallback to open system settings if needed
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                })
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.asymmetric(insertion: .slide, removal: .opacity))
            }
            
            Divider()
                .opacity(0.3)
            
            // Mode Selector
            ModeSelectorView(currentMode: $queueManager.mode)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            // Clipboard Entries list
            if queueManager.items.isEmpty {
                EmptyStateView(isSessionActive: queueManager.isSessionActive)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(queueManager.items) { item in
                        ClipboardItemRow(
                            item: item,
                            onCopy: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.content, forType: .string)
                            },
                            onEdit: {
                                editingItem = item
                                editContent = item.content
                            },
                            onDelete: {
                                withAnimation {
                                    queueManager.removeItem(id: item.id)
                                }
                            }
                        )
                        .listRowSeparator(.visible, edges: .bottom)
                        .listRowSeparatorTint(Color.primary.opacity(0.08))
                        .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                    }
                    .onMove { source, destination in
                        queueManager.reorder(fromOffsets: source, toOffset: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            
            Divider()
                .opacity(0.3)
            
            // Footer
            FooterView(
                itemCount: queueManager.items.count,
                onClear: {
                    if queueManager.items.isEmpty { return }
                    showClearConfirmation = true
                }
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        }
        }
        .frame(width: 330, height: 450)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .ignoresSafeArea()
        )
        // Edit Sheet
        .sheet(item: $editingItem) { item in
            EditItemSheet(
                content: $editContent,
                onSave: {
                    queueManager.updateItem(id: item.id, newContent: editContent)
                    editingItem = nil
                },
                onCancel: {
                    editingItem = nil
                }
            )
        }
        // Confirmation dialog for clearing
        .confirmationDialog(
            "Clear current session?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Items", role: .destructive) {
                withAnimation {
                    queueManager.clearSession()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will discard all \(queueManager.items.count) captured items in this session.")
        }
        .onReceive(accessibilityTimer) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted != isAccessibilityTrusted {
                withAnimation(.spring()) {
                    isAccessibilityTrusted = trusted
                }
            }
        }
    }
}

// MARK: - Accessibility Warning Banner
struct AccessibilityWarningView: View {
    let onFix: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 13, weight: .bold))
                
                Text("Accessibility Access Required")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onFix) {
                    Text("Grant")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Text("PasteLine needs permission to automate the ⌘V keystroke when pasting snippets sequentially.")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Header
struct HeaderView: View {
    let isSessionActive: Bool
    let onToggleSession: () -> Void
    let onSettings: () -> Void
    @State private var isPulsing = false
    
    var body: some View {
        HStack {
            // App Title Logo with Gradient
            HStack(spacing: 6) {
                Image(systemName: "paperclip.badge.ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
                
                Text("PasteLine")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Spacer()
            
            // Pulse status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(isSessionActive ? Color.green : Color.secondary.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(isSessionActive && isPulsing ? 1.5 : 1.0)
                    .opacity(isSessionActive && isPulsing ? 0.4 : 1.0)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true)
                        ) {
                            isPulsing = true
                        }
                    }
                
                Text(isSessionActive ? "Active" : "Stopped")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSessionActive ? .green : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(12)
            .padding(.trailing, 4)
            
            // Settings button
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(5)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help("Open settings")
            .padding(.trailing, 4)
            
            // Play/Pause button
            Button(action: onToggleSession) {
                HStack(spacing: 4) {
                    Image(systemName: isSessionActive ? "pause.fill" : "play.fill")
                    Text(isSessionActive ? "Pause" : "Start")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: isSessionActive ? [.red, .orange] : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: (isSessionActive ? Color.red : Color.blue).opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Mode Selector
struct ModeSelectorView: View {
    @Binding var currentMode: PasteMode
    
    var body: some View {
        HStack(spacing: 2) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentMode = .fifo
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 10, weight: .semibold))
                    Text("FIFO (First In, First Out)")
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(currentMode == .fifo ? Color.accentColor : Color.clear)
                .foregroundColor(currentMode == .fifo ? .white : .primary)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentMode = .lifo
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 10, weight: .semibold))
                    Text("LIFO (Last In, First Out)")
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(currentMode == .lifo ? Color.accentColor : Color.clear)
                .foregroundColor(currentMode == .lifo ? .white : .primary)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }
}

// MARK: - Clipboard Item Row
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var iconName: String {
        switch item.type {
        case .url: return "link"
        case .code: return "curlybraces"
        case .text: return "doc.text"
        }
    }
    
    var iconColor: Color {
        switch item.type {
        case .url: return .blue
        case .code: return .purple
        case .text: return .secondary
        }
    }
    
    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.timestamp, relativeTo: Date())
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Type Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            // Snippet Preview
            VStack(alignment: .leading, spacing: 3) {
                Text(item.content)
                    .font(.system(size: 12, weight: .regular, design: item.type == .code ? .monospaced : .default))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    
                Text(formattedTime)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 4) {
                // Copy back
                Button(action: onCopy) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10))
                        .padding(5)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Copy back to clipboard")
                
                // Edit
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .padding(5)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Edit entry")
                
                // Delete
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(5)
                        .background(Color.red.opacity(0.06))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Delete entry")
            }
            .opacity(isHovered ? 1.0 : 0.6) // Always visible, but highlights on hover
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Make entire row hoverable
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let isSessionActive: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(width: 64, height: 64)
                
                Image(systemName: isSessionActive ? "rectangle.and.paperclip" : "play.circle")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor.opacity(0.8))
            }
            
            VStack(spacing: 4) {
                Text(isSessionActive ? "Stack is Empty" : "Monitoring Paused")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(isSessionActive ? "Copy items using ⌘C to fill the stack" : "Click Start above or press ⌃⌥⌘S")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Footer View
struct FooterView: View {
    let itemCount: Int
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            // Stats
            Text("\(itemCount) items captured")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Clear Button
            Button(action: onClear) {
                HStack(spacing: 4) {
                    Image(systemName: "clear")
                    Text("Clear Queue")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(itemCount > 0 ? .red : .secondary.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(itemCount > 0 ? Color.red.opacity(0.06) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(itemCount == 0)
        }
    }
}

// MARK: - Edit Item Sheet
struct EditItemSheet: View {
    @Binding var content: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Edit Snippet")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            
            TextEditor(text: $content)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 120, maxHeight: 200)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            
            HStack {
                Spacer()
                
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - VisualEffectView for Glassmorphic backdrop
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Settings")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                
                Spacer()
                
                // Alignment spacer
                Text("Back")
                    .font(.system(size: 12))
                    .opacity(0)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.3)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary.opacity(0.8))
                        .padding(.horizontal, 4)
                    
                    ShortcutConfigRow(
                        title: "Paste Next Item",
                        codeKey: "PL_paste_code",
                        modsKey: "PL_paste_mods",
                        defaultCode: 9, // V
                        defaultMods: 6400 // ⌃⌥⌘
                    )
                    
                    ShortcutConfigRow(
                        title: "Start Monitoring Session",
                        codeKey: "PL_start_code",
                        modsKey: "PL_start_mods",
                        defaultCode: 1, // S
                        defaultMods: 6400 // ⌃⌥⌘
                    )
                    
                    ShortcutConfigRow(
                        title: "Stop Monitoring Session",
                        codeKey: "PL_stop_code",
                        modsKey: "PL_stop_mods",
                        defaultCode: 7, // X
                        defaultMods: 6400 // ⌃⌥⌘
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Permission Status")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        let trusted = AXIsProcessTrusted()
                        HStack {
                            Circle()
                                .fill(trusted ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            
                            Text(trusted ? "Accessibility Access Granted" : "Accessibility Access Denied")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding()
            }
        }
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Shortcut Config Row
struct ShortcutConfigRow: View {
    let title: String
    let codeKey: String
    let modsKey: String
    let defaultCode: UInt32
    let defaultMods: UInt32
    
    @State private var keyCode: UInt32 = 9
    @State private var modifiers: UInt32 = 6400
    
    @State private var hasCmd = false
    @State private var hasOpt = false
    @State private var hasCtrl = false
    @State private var hasShift = false
    
    // Key choices mapping to macOS Virtual Keycodes
    let keys: [(String, UInt32)] = [
        ("A", 0), ("B", 11), ("C", 8), ("D", 2), ("E", 14), ("F", 3), ("G", 5),
        ("H", 4), ("I", 34), ("J", 38), ("K", 40), ("L", 37), ("M", 46), ("N", 45),
        ("O", 31), ("P", 35), ("Q", 12), ("R", 15), ("S", 1), ("T", 17), ("U", 32),
        ("V", 9), ("W", 13), ("X", 7), ("Y", 16), ("Z", 6), ("Space", 49), ("Return", 36),
        ("Tab", 48), ("Escape", 53), ("0", 29), ("1", 18), ("2", 19), ("3", 20), ("4", 21),
        ("5", 23), ("6", 22), ("7", 26), ("8", 28), ("9", 25)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                // Modifier checkboxes
                HStack(spacing: 2) {
                    ModifierToggle(label: "⌃", isSelected: $hasCtrl)
                    ModifierToggle(label: "⌥", isSelected: $hasOpt)
                    ModifierToggle(label: "⌘", isSelected: $hasCmd)
                    ModifierToggle(label: "⇧", isSelected: $hasShift)
                }
                
                // Key Picker
                Picker("", selection: $keyCode) {
                    ForEach(keys, id: \.1) { item in
                        Text(item.0).tag(item.1)
                    }
                }
                .frame(width: 80)
                .labelsHidden()
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(8)
        .onAppear {
            self.keyCode = UserDefaults.standard.object(forKey: codeKey) as? UInt32 ?? defaultCode
            self.modifiers = UserDefaults.standard.object(forKey: modsKey) as? UInt32 ?? defaultMods
            
            // Unpack modifiers
            self.hasCmd = (modifiers & 256) != 0
            self.hasShift = (modifiers & 512) != 0
            self.hasOpt = (modifiers & 2048) != 0
            self.hasCtrl = (modifiers & 4096) != 0
        }
        .onChange(of: keyCode) { _, _ in updateValues() }
        .onChange(of: hasCmd) { _, _ in updateValues() }
        .onChange(of: hasOpt) { _, _ in updateValues() }
        .onChange(of: hasCtrl) { _, _ in updateValues() }
        .onChange(of: hasShift) { _, _ in updateValues() }
    }
    
    private func updateValues() {
        var mods: UInt32 = 0
        if hasCmd { mods += 256 }
        if hasShift { mods += 512 }
        if hasOpt { mods += 2048 }
        if hasCtrl { mods += 4096 }
        
        // Save to UserDefaults
        UserDefaults.standard.set(keyCode, forKey: codeKey)
        UserDefaults.standard.set(mods, forKey: modsKey)
        
        // Reload hotkeys instantly
        GlobalShortcutManager.shared.registerShortcuts()
    }
}

// MARK: - Modifier Toggle Button
struct ModifierToggle: View {
    let label: String
    @Binding var isSelected: Bool
    
    var body: some View {
        Button(action: {
            isSelected.toggle()
        }) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 24, height: 24)
                .background(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
