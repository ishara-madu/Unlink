# Unlink v1.0.0 - Initial Release 🎉

**Unlink** is a modern, native macOS application & deep leftover uninstaller built with **Swift 6**, **SwiftUI**, and **AppKit**. It thoroughly traces, audits, and removes applications along with their hidden leftovers (caches, preferences, application support, containers, logs, background daemons) to keep your Mac fast and clean.

---

## ⚡ What's New in v1.0.0

- **Universal 2 Binary**: Full native execution with zero emulation on **Apple Silicon (M1/M2/M3/M4)** and **Intel** Macs.
- **Deep 20+ Location Leftover Scanner**:
  - `~/Library/Application Support` & `/Library/Application Support` (with vendor subfolder traversal for Google, Microsoft, Adobe, JetBrains, etc.)
  - `~/Library/Caches` & `/Library/Caches`
  - `~/Library/Preferences` (`.plist`, `.lockfile`, and `ByHost` configurations)
  - `~/Library/Containers` & `~/Library/Group Containers` (sandboxed application data)
  - `~/Library/Saved Application State`
  - `~/Library/Logs` & `~/Library/Logs/DiagnosticReports`
  - `~/Library/WebKit` & `~/Library/HTTPStorages` (web caches and binary cookies)
  - `~/Library/LaunchAgents`, `/Library/LaunchAgents` & `/Library/LaunchDaemons` (startup background daemons)
  - `/Library/PrivilegedHelperTools`
  - `~/.config` (developer and cross-platform dotfiles)
  - Darwin OS Kernel User Caches (`/var/folders/.../C/` & `/T/`)
- **Subfolder Application Scanning**:
  - Automatically discovers nested apps inside versioned subdirectories (e.g., `/Applications/Unity/Hub/Editor/2020.3.49f1/Unity.app`).
- **Shortcut & Finder Alias Resolution**:
  - Dropping or scanning Finder Aliases or Symlinks automatically tracks down the target application and includes the shortcut for removal.
- **Batch Uninstallation with Interactive Dropdowns**:
  - Select and uninstall multiple applications simultaneously.
  - Interactive accordion dropdowns allow expanding each app to inspect, select, or deselect individual associated files and categories.
- **Pre-Deletion Process Termination**:
  - Safely terminates running target applications before moving files to release SQLite locks and prevent cache recreation.
- **Safety First (macOS Native Trash)**:
  - Critical root directories (`/Library`, `~/Library`, `/Applications`) are protected and blocked.
  - Files are moved to the macOS Trash via native `FileManager.default.trashItem`, allowing instant "Put Back" restoration if ever needed.
- **Ultra Lightweight**:
  - Only ~2.4 MB `.dmg` and ~2.0 MB `.zip` distribution.

---

## 📥 Downloads & Assets

| File | Size | Description |
| :--- | :--- | :--- |
| **`Unlink.dmg`** | **2.4 MB** | macOS Drag-and-Drop installer (Recommended) |
| **`Unlink.zip`** | **2.0 MB** | Portable standalone application archive |

### SHA-256 Checksums
```
08147f6425d39f06113f411529f42b2a212d9fa57e1246d692e40379bf5c35e7  Unlink.dmg
3ed8cc2e95c6ed85ba1d0964eda99fa70382b8fbfab76ebc9e1899ae3fb19b83  Unlink.zip
```

---

## 💻 Requirements
- **OS**: macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- **Architecture**: Universal (Apple Silicon M1/M2/M3/M4 & Intel 64-bit)
