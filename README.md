# PasteLine: Clipboard Stack Manager for macOS

PasteLine is a native macOS menu bar application built with Swift, SwiftUI, and AppKit. It monitors your clipboard when active, captures items copied via standard copy commands (`⌘+C`), and allows you to paste them sequentially in either FIFO (First In, First Out) or LIFO (Last In, First Out) order using a system-wide hotkey.

It runs entirely from the macOS menu bar as a status bar agent (`LSUIElement`), avoiding Dock and main window clutter, and uses a custom popover with glassmorphic backing for a modern and premium macOS look.

---

## Key Features

1. **Active Session Control**: Start or pause monitoring your clipboard from the menu bar or via global shortcuts.
2. **FIFO & LIFO Modes**: Dynamically toggle between pasting oldest items first (FIFO) or newest items first (LIFO).
3. **Interactive Stack Management**: 
   - **View & Preview**: Review your captured clipboard history inside a beautiful popup list.
   - **Reorder**: Drag-and-drop rows to modify the paste order dynamically.
   - **Edit**: Edit any snippet inline via a popover sheet.
   - **Individual Deletion**: Remove individual entries with a click.
   - **Copy Back**: Copy any stored snippet back into your clipboard.
4. **Global Keyboard Shortcuts**:
   - **Start Monitoring**: `⌃⌥⌘S` (Control + Option + Command + S)
   - **Stop Monitoring**: `⌃⌥⌘X` (Control + Option + Command + X)
   - **Sequential Paste**: `⌃⌥⌘V` (Control + Option + Command + V)
5. **Visual Capture Feedback**: Shows temporary success banners like `Captured #3` or `Pasted!` directly in the menu bar.
6. **Automatic Persistence**: Saves the stack queue and settings to local storage, preserving your history even when the app restarts.
7. **Accessibility Permissions Handling**: Detects if macOS accessibility access is granted (required to programmatically paste into target apps) and presents a helpful setup banner directing users to macOS Privacy Settings.

---

## Project Structure

The project code is organized under `Sources/PasteLine/`:

- [Sources/PasteLine/main.swift](file:///Users/nirmal.s/Documents/Projects/PoC/PasteLine/Sources/PasteLine/main.swift): Entry point that initializes AppKit and the `AppDelegate`.
- [Sources/PasteLine/AppDelegate.swift](file:///Users/nirmal.s/Documents/Projects/PoC/PasteLine/Sources/PasteLine/AppDelegate.swift): Manages the menu bar status item, popover lifecycle, context menus, and visual feedback timers.
- [Sources/PasteLine/PopoverView.swift](file:///Users/nirmal.s/Documents/Projects/PoC/PasteLine/Sources/PasteLine/PopoverView.swift): Rich SwiftUI interface displaying the clipboard items, mode selectors, sheet editor, and the accessibility permission warning card.
- [Sources/PasteLine/QueueManager.swift](file:///Users/nirmal.s/Documents/Projects/PoC/PasteLine/Sources/PasteLine/QueueManager.swift): Manages clipboard snippet storage, filtering consecutive duplicates, persistence via `UserDefaults`, and FIFO/LIFO ordering.
- [Sources/PasteLine/ClipboardMonitor.swift](file:///Users/nirmal.s/Documents/Projects/PoC/PasteLine/Sources/PasteLine/ClipboardMonitor.swift): Background thread that polls `NSPasteboard` changes and pauses during paste events to prevent self-capturing.
- [Sources/PasteLine/PasteEngine.swift](file:///Users/nirmal.s/Documents/Projects/PoC/PasteLine/Sources/PasteLine/PasteEngine.swift): Performs programmatic paste simulations into target apps using macOS `CGEvent` synthesizers.
- [Sources/PasteLine/GlobalShortcutManager.swift](file:///Users/nirmal.s/Documents/Projects/PoC/PasteLine/Sources/PasteLine/GlobalShortcutManager.swift): Handles registering low-level system-wide hotkeys through the Carbon framework.
- [Sources/PasteLine/Info.plist](file:///Users/nirmal.s/Documents/Projects/PoC/PasteLine/Sources/PasteLine/Info.plist): Core application metadata setting target macOS version (14+) and configuring the application to run as an agent (`LSUIElement = true`).

---

## Build and Launch

A build script `build.sh` is provided in the root directory to compile and package the app automatically.

### Compiling

To build the application, execute:
```bash
./build.sh
```

This compiles the Swift files and creates the app bundle at `PasteLine.app`.

### Running

To launch the compiled app, run:
```bash
open PasteLine.app
```

Once launched, you will see a paperclip icon (`paperclip.badge.ellipsis` SF symbol) in your macOS menu bar.

---

## Getting Started

1. **Launch the App**: Left-click the menu bar icon to open the popover interface.
2. **Grant Permissions**:
   - Because macOS restricts apps from simulating keypresses globally, PasteLine needs **Accessibility Permissions**.
   - If not yet authorized, an amber banner will appear in the popover. Click **Grant** to open macOS Privacy settings, and toggle **PasteLine** to on.
   - Once authorized, the banner will automatically slide away.
3. **Start Monitoring**: Click **Start** in the popover header, or press `⌃⌥⌘S`.
4. **Copy Items**: Go to any browser, text editor, or tool, and copy multiple texts using `⌘+C`. You will see `Captured #1`, `Captured #2` flash in your menu bar.
5. **Sequential Paste**: Place your cursor in a target document, and press `⌃⌥⌘V` repeatedly. Items will paste one-by-one in your chosen order (FIFO or LIFO) and disappear from the queue!
6. **Stack Actions**: Left-click the menu bar icon anytime to reorder items by dragging, delete individual snippets, copy items back to clipboard, or edit them.
7. **Control Menu**: Right-click the menu bar icon (or Control-click) to open a traditional context menu where you can start/stop sessions, clear the queue, or quit the application.
8. **Settings & Customization**: Click the gear icon in the popover header to customize global shortcuts for sequential pasting, starting sessions, and stopping sessions.

---

## License

This project is licensed under the MIT License. See the [LICENSE](file:///Users/nirmal.s/Documents/Projects/PoC/PasteLine/LICENSE) file for details.
