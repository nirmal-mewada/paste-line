# PasteLine Developer Memory

This file preserves the development context, design decisions, and environment configurations for future sessions on the **PasteLine** project.

---

## 📌 Project Overview
PasteLine is a native macOS menu bar application (agent app, `LSUIElement = true`) that acts as an advanced clipboard stack manager.
- **Language/Frameworks**: Swift 6.0.3, SwiftUI, AppKit, Carbon (global hotkeys), Foundation.
- **Build Method**: Standalone compilation using `swiftc` via a build script (`./build.sh`). Output is `PasteLine.app`.

---

## 🛠 Current Implementation State
All core features from the project requirements are implemented and fully functional:
- **Session Control**: Active session start/pause/clear.
- **Modes**: FIFO (First In, First Out) and LIFO (Last In, First Out) paste order toggles.
- **Menu Bar Icon**: Uses SF Symbol `paperclip.badge.ellipsis`. Updates dynamically to show temporary badge counts (e.g. `Captured #3`, `Pasted!`) for immediate visual feedback.
- **Stack UI**: A SwiftUI list populated inside a transient AppKit `NSPopover` with a glassmorphic visual effect.
  - Custom type icons (Text, URL, Code).
  - Hover action buttons (Copy-back, Edit, Delete).
  - Inline text/code editing sheet.
  - Native drag-and-drop list reordering (`onMove`).
- **Global Hotkeys**: Hooked to Carbon Event Targets (`⌃⌥⌘V` for paste next, `⌃⌥⌘S` for start session, `⌃⌥⌘X` for stop session).
- **Persistence**: Stack queue, active modes, and session status are serialized to JSON and persisted locally to `UserDefaults` (preserved across restarts).
- **Custom Shortcut Preferences**: Added a **Settings View** (accessible via a gear icon in the popover header) allowing the user to customize the global hotkey combinations (modifiers `⌃⌥⌘⇧` + key selection) at runtime. Updates apply instantly without restarting.

---

## 🔑 Crucial Technical Solutions & Quirks

### 1. Programmatic Paste (⌘+V) Modifier Interference
*   **Issue**: When the user presses `⌃⌥⌘V`, they are physically holding down `Control` and `Option`. If the app simulates `⌘V` key events immediately, the OS merges the physical keys, resulting in `⌃⌥⌘V` sent to the target app, causing the paste operation to fail.
*   **Solution**: 
    - Added a helper `releaseModifierKeys()` in `PasteEngine.swift` that programmatically posts `KeyUp` events for Control (`0x3B`/`0x3E`), Option (`0x3A`/`0x3D`), and Shift (`0x38`/`0x3C`) prior to pasting.
    - Switched the `CGEventSource` state ID to `.privateState` to isolate from current physical modifier flags.
    - Set the async delay before pasting to `100ms` to let the OS process the key releases.

### 2. Accessibility Permissions
*   **Issue**: Programmatic keyboard events require macOS Accessibility trust.
*   **Solution**: The app checks `AXIsProcessTrusted()` on popover launch and polls every second. If denied, a beautiful warning banner is shown. Clicking the action button triggers `AXIsProcessTrustedWithOptions` (invoking the macOS security dialog) and opens System Settings directly to Privacy & Security > Accessibility.

### 3. Environment & Git Setup
*   **SSH Key Directory Permissions**: The user's SSH key directory at `/Users/nirmal.s/.ssh/nirmal` was configured with permissions `drw-------`, missing the execute bit (`x`). This caused ssh key loading to fail with "Permission denied". We fixed this by setting it to `0700` (`chmod 700 /Users/nirmal.s/.ssh/nirmal`).
*   **Git Authentication**: Configured Git to use the specific private key at `/Users/nirmal.s/.ssh/nirmal/id_rsa` via:
    ```bash
    git config core.sshCommand "ssh -i /Users/nirmal.s/.ssh/nirmal/id_rsa -o IdentitiesOnly=yes"
    ```
    This successfully pushes to `git@github.com:nirmal-mewada/paste-line.git` on the `main` branch.

---

## 🚀 Active Next Steps / Remaining Tasks
The codebase is fully compiled and pushed to GitHub. The tag `v1.0.0` has been pushed. The remaining task is to create the GitHub Release:
1. The user needs to refresh their GitHub CLI scopes:
   ```bash
   gh auth refresh -h github.com -s workflow
   ```
2. Create the GitHub release and upload the archived `PasteLine.zip` file:
   ```bash
   gh release create v1.0.0 PasteLine.zip --title "v1.0.0" --notes "Initial release of PasteLine"
   ```
