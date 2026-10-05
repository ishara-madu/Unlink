<div align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Unlink App Icon" />
  <h1>Unlink</h1>
  <p><strong>A fast, native macOS application & deep leftover uninstaller built with Swift & SwiftUI.</strong></p>
  <p>
    <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple" alt="macOS 14+" />
    <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift" alt="Swift 6.0" />
    <img src="https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-success" alt="Universal 2" />
    <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License" />
  </p>
</div>

---

## 📖 Overview

**Unlink** completely removes macOS applications and all of their hidden leftovers. When you delete an app by dragging it to Trash in Finder, gigabytes of caches, settings, preferences, and container data remain buried deep inside `~/Library`. Unlink scans over **20+ macOS system locations**, locates every single associated file, and safely moves them to Trash upon your confirmation.

---

## ✨ Key Features

- **⚡ Blazing Fast & Lightweight**: Zero sluggishness. Opens in under 0.3s with instant responsiveness. Distribution package is only ~2 MB.
- **🍎 Universal 2 Native Binary**: Runs natively on both **Apple Silicon (M1/M2/M3/M4)** and **Intel** Macs with zero emulation or Rosetta needed.
- **🔍 20+ Location Deep Leftover Scanner**:
  - Traces `Application Support` (with vendor subfolder traversal), `Caches`, `Preferences` (`.plist`, `.lockfile`, `ByHost`), `Containers`, `Group Containers`, `Saved Application State`, `Logs`, `HTTPStorages`, `WebKit`, `LaunchAgents`, `LaunchDaemons`, `PrivilegedHelperTools`, and Darwin Kernel Caches (`/var/folders/.../C/` & `/T/`).
- **📁 Subfolder & Nested App Detection**:
  - Recursively discovers editors and applications nested in versioned subfolders (e.g. `/Applications/Unity/Hub/Editor/2020.3.49f1/Unity.app`).
- **🔗 Shortcut & Finder Alias Resolver**:
  - Dragging or scanning Finder Aliases or Symlinks automatically locates the original binary and marks the shortcut for removal.
- **📦 Batch Uninstallation with Accordion Dropdowns**:
  - Mark multiple applications and remove them together.
  - Interactive dropdown cards let you inspect, select, or deselect individual associated files before deletion.
- **🛡️ Safety First**:
  - Core system directories (`/System`, `/Library`, `/Applications`) are protected and blocked from accidental deletion.
  - Items are moved to the native macOS Trash (`FileManager.default.trashItem`), allowing instant restoration with "Put Back" if desired.
- **🛑 Running Process Termination**:
  - Automatically terminates running target apps prior to deletion to release file locks and prevent cache recreation.

---

## 📥 Installation

Download the latest release from the [Releases](https://github.com/ishara-madu/Unlink/releases) page:

1. Download **`Unlink.dmg`** (Recommended) or **`Unlink.zip`**.
2. Open `Unlink.dmg` and drag **Unlink** into your `Applications` folder.
3. Launch **Unlink** and start cleaning!

---

## 🛠️ Building from Source (Command-Line Only)

Unlink follows a strict **CLI-only** build policy using Swift Package Manager (no Xcode GUI required):

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Xcode Command Line Tools (`xcode-select --install`)

### Run Locally
```bash
# Clone the repository
git clone https://github.com/ishara-madu/Unlink.git
cd Unlink

# Build and launch immediately
swift run
```

### Build Universal 2 DMG & Release Package
To compile native binaries for both Apple Silicon and Intel, and package the `.dmg` and `.zip`:

```bash
./scripts/package_release.sh
```

Artifacts will be generated in `build/`:
- `build/Unlink.dmg`
- `build/Unlink.zip`
- `build/checksums.txt`

---

## 🏛️ Architecture

```
Sources/Unlink/
├── App/
│   ├── UnlinkApp.swift          # Main entry point (@main, WindowGroup)
│   └── AppDelegate.swift        # AppKit lifecycle, window styling, Dock icon
├── Models/
│   ├── InstalledApp.swift       # App model (name, URL, bundleID, version, size, icon)
│   ├── LeftoverItem.swift       # Associated leftover file (URL, size, category, isSelected)
│   └── LeftoverCategory.swift   # AppBundle, Preferences, Caches, Containers, etc.
├── Services/
│   ├── AppScannerService.swift  # Scans /Applications and ~/Applications (lazy system scan)
│   ├── LeftoverScanner.swift    # Deep leftover resolver across 20+ ~/Library locations
│   └── TrashService.swift       # Process termination & safe macOS Trash handling
├── ViewModels/
│   └── UnlinkViewModel.swift    # @Observable presentation logic, selection, batch actions
└── Views/
    ├── MainWindowView.swift     # Split view layout / main container
    ├── Sidebar/
    │   ├── SidebarView.swift    # Search bar, system app toggle, app list
    │   └── AppRowView.swift     # Individual app item row
    ├── Detail/
    │   ├── AppDetailView.swift  # Single app leftover inspection & granular selection
    │   ├── BatchUninstallView.swift # Batch uninstaller with expandable accordion cards
    │   ├── LeftoverCategoryView.swift # Categorized file group
    │   └── LeftoverRowView.swift      # Individual leftover row with checkbox
    └── DropZone/
        └── DropZoneView.swift   # Drag-and-drop hero component
```

---

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.
