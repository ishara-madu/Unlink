# Unlink - macOS Application & Associated Files Uninstaller Guidelines

## Project Overview

**Unlink** is a native macOS desktop uninstaller application built using **Swift**, **SwiftUI**, and **AppKit**.
It scans for installed applications, finds all associated leftovers (Preferences, Caches, Application Support, Containers, Saved Application State, Logs, Crash Reports), and safely moves them to Trash upon user confirmation.

> [!IMPORTANT]
> **Strict Command-Line (CLI) Only Policy**:
> - **No Xcode GUI**: Do NOT use or suggest using the Xcode application GUI. The entire project lifecycle (creating files, compiling, testing, running, and bundling) is executed strictly via the terminal using the `swift` command-line tools.
> - **No `.xcodeproj` Dependency**: Manage all dependencies, targets, and compilation via **Swift Package Manager (`Package.swift`)**.

---

## Command-Line Toolchain & Commands

Always use the Swift CLI toolchain for building, running, and managing the project:

| Task | Command | Description |
| :--- | :--- | :--- |
| **Run App** | `swift run` | Compiles and immediately launches the Unlink window for testing |
| **Build Debug** | `swift build` | Compiles debug binaries |
| **Build Release** | `swift build -c release` | Compiles optimized release binaries |
| **Run Tests** | `swift test` | Executes unit and integration test suites |
| **Clean Build** | `swift package clean` | Cleans build artifacts (`.build/` directory) |
| **Resolve Dependencies** | `swift package resolve` | Resolves SPM packages listed in `Package.swift` |
| **Update Dependencies** | `swift package update` | Updates packages to the latest compatible versions |

### Creating a Standalone macOS `.app` Bundle (CLI Only)
### Creating a Standalone macOS `.app` Bundle (Universal Binary: Apple Silicon + Intel)
To create a fully native **Universal 2** `.app` bundle that runs with zero emulation on both Apple Silicon (M1/M2/M3/M4) and Intel Macs:

```bash
# 1. Compile both architectures
swift build -c release --triple arm64-apple-macosx
swift build -c release --triple x86_64-apple-macosx

# 2. Package bundle structure
mkdir -p build/Unlink.app/Contents/{MacOS,Resources}
cp Resources/Info.plist build/Unlink.app/Contents/
cp Resources/AppIcon.icns build/Unlink.app/Contents/Resources/

# 3. Create Universal Binary using lipo
lipo -create -output build/Unlink.app/Contents/MacOS/Unlink \
  .build/arm64-apple-macosx/release/Unlink \
  .build/x86_64-apple-macosx/release/Unlink

# 4. Optional: Create distributable zip
(cd build && zip -q -r -y Unlink.zip Unlink.app)
```

---

## Technical Stack & Architecture

### Core Technologies
- **Language**: Swift (Swift 6 concurrency model)
- **UI Framework**: SwiftUI (macOS 14+ / 15+) with AppKit interop (`NSWorkspace`, `NSOpenPanel`, `NSApplicationDelegate`)
- **State Management**: Swift Observation framework (`@Observable`)
- **File System**: `FileManager`, `URL`, `Bundle`

### Architecture (MVVM + Scanner Services)
```
Sources/Unlink/
├── App/
│   ├── UnlinkApp.swift          # Main entry point (@main, WindowGroup)
│   └── AppDelegate.swift        # AppKit lifecycle, window styling, file dropping
├── Models/
│   ├── InstalledApp.swift       # App model (name, URL, bundleID, version, size, icon)
│   ├── LeftoverItem.swift       # Associated leftover file (URL, size, category, isSelected)
│   └── LeftoverCategory.swift   # Bundle, Preferences, Caches, App Support, Containers, etc.
├── Services/
│   ├── AppScannerService.swift  # Scans /Applications and ~/Applications
│   ├── LeftoverScanner.swift    # Resolves leftover files across ~/Library
│   └── TrashService.swift       # Moves selected files to macOS Trash
├── ViewModels/
│   └── UnlinkViewModel.swift    # @Observable presentation logic, selection, state
└── Views/
    ├── MainWindowView.swift     # Split view layout / main container
    ├── Sidebar/
    │   ├── SidebarView.swift    # App list, search bar, filter
    │   └── AppRowView.swift     # App row item with icon and metadata
    ├── Detail/
    │   ├── AppDetailView.swift  # Detailed inspection view
    │   ├── LeftoverCategoryView.swift # Categorized leftover section
    │   └── LeftoverRowView.swift      # Single file row with checkbox & action
    ├── DropZone/
    │   └── DropZoneView.swift   # Interactive drag-and-drop hero component
    └── Components/
        └── StatBadge.swift      # Space badge, badges
```

---

## Native macOS Aesthetics & UX Guidelines

1. **Native Apple Materials**:
   - Use `.ultraThinMaterial`, `NSVisualEffectView`, and standard macOS system colors.
   - Clean, subtle borders and native rounded corners.
2. **SF Symbols**:
   - Exclusively use Apple SF Symbols for actions and categories (`trash.fill`, `magnifyingglass`, `gearshape`, `shippingbox`, etc.).
3. **Typography**:
   - Use `.monospacedDigit()` for all file sizes and counters.
4. **Safety First**:
   - Default to moving items to the macOS Trash (`FileManager.default.trashItem`) rather than permanent deletion, with confirmation dialogs.
