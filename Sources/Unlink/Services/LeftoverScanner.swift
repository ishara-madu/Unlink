import Foundation

public struct LeftoverScanner: Sendable {
    public static let shared = LeftoverScanner()

    public init() {}

    public func scanLeftovers(for app: InstalledApp) async -> [LeftoverItem] {
        var items: [LeftoverItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let libraryURL = home.appendingPathComponent("Library", isDirectory: true)

        let appName = app.name
        let bundleID = app.bundleIdentifier

        // 1. App Bundle itself
        if fileManager.fileExists(atPath: app.url.path) {
            let appSize = calculateItemSize(at: app.url)
            items.append(
                LeftoverItem(
                    url: app.url,
                    path: app.url.path,
                    displayName: app.url.lastPathComponent,
                    category: .appBundle,
                    size: appSize,
                    isDirectory: true,
                    isSelected: true
                )
            )
        }

        // If app was invoked/scanned from a shortcut, include the shortcut itself for deletion
        if let shortcut = app.shortcutURL, fileManager.fileExists(atPath: shortcut.path) {
            let shortcutSize = calculateItemSize(at: shortcut)
            items.append(
                LeftoverItem(
                    url: shortcut,
                    path: shortcut.path,
                    displayName: "Shortcut: \(shortcut.lastPathComponent)",
                    category: .appBundle,
                    size: shortcutSize,
                    isDirectory: isDirectory(at: shortcut),
                    isSelected: true
                )
            )
        }

        // Also scan Desktop for any aliases/shortcuts pointing to this app
        let desktopURL = home.appendingPathComponent("Desktop", isDirectory: true)
        if let desktopContents = try? fileManager.contentsOfDirectory(
            at: desktopURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for file in desktopContents {
                if file.path != app.shortcutURL?.path {
                    let (resolvedTarget, isShortcut, _) = AppScannerService.resolveApplicationTarget(from: file)
                    if isShortcut && resolvedTarget.path == app.url.path {
                        let scSize = calculateItemSize(at: file)
                        items.append(
                            LeftoverItem(
                                url: file,
                                path: file.path,
                                displayName: "Desktop Shortcut: \(file.lastPathComponent)",
                                category: .appBundle,
                                size: scSize,
                                isDirectory: isDirectory(at: file),
                                isSelected: true
                            )
                        )
                    }
                }
            }
        }

        // Check containing installation folder if the app is nested inside a subfolder
        // (e.g., /Applications/Unity/Hub/Editor/2020.3.49f1/)
        let parentDir = app.url.deletingLastPathComponent()
        let standardAppDirs: Set<String> = [
            "/Applications",
            "/Applications/Utilities",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true).path,
            "/System/Applications"
        ]

        if !standardAppDirs.contains(parentDir.path) {
            if let parentContents = try? fileManager.contentsOfDirectory(
                at: parentDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for siblingURL in parentContents {
                    guard siblingURL.path != app.url.path else { continue }
                    let isDir = isDirectory(at: siblingURL)
                    let size = calculateItemSize(at: siblingURL)
                    items.append(
                        LeftoverItem(
                            url: siblingURL,
                            path: siblingURL.path,
                            displayName: "\(parentDir.lastPathComponent)/\(siblingURL.lastPathComponent)",
                            category: .appBundle,
                            size: size,
                            isDirectory: isDir,
                            isSelected: true
                        )
                    )
                }
            }
        }

        // Extract extra names from app bundle
        let bundle = Bundle(url: app.url)
        let executableName = bundle?.executableURL?.lastPathComponent
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleExecutable") as? String)
        let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String

        // Base app name (stripping any parenthetical subfolder info, e.g. "Unity (2020.3.49f1)" -> "Unity")
        var cleanAppName = appName
        if let parenIndex = appName.firstIndex(of: "(") {
            cleanAppName = String(appName[..<parenIndex]).trimmingCharacters(in: .whitespaces)
        }

        // Build list of valid search keywords
        var primaryIdentifiers = Set<String>()
        var subKeywords = Set<String>()

        if let bundleID, !bundleID.isEmpty {
            primaryIdentifiers.insert(bundleID)
            let parts = bundleID.split(separator: ".").map(String.init)
            if parts.count >= 2 {
                if let last = parts.last, last.count >= 3 {
                    subKeywords.insert(last)
                }
                let lastTwo = parts.suffix(2).joined(separator: ".")
                if lastTwo.count >= 4 {
                    primaryIdentifiers.insert(lastTwo)
                }
            }

            // Strip trailing versions/numbers (e.g. "com.unity3d.UnityEditor5.x" -> "com.unity3d.UnityEditor")
            if let dotIndex = bundleID.lastIndex(of: ".") {
                let lastPart = String(bundleID[bundleID.index(after: dotIndex)...])
                let strippedLast = lastPart.replacingOccurrences(of: #"[0-9]+(\.x)?"#, with: "", options: .regularExpression)
                if !strippedLast.isEmpty && strippedLast != lastPart {
                    let baseID = String(bundleID[..<bundleID.index(after: dotIndex)]) + strippedLast
                    primaryIdentifiers.insert(baseID)
                    subKeywords.insert(strippedLast)
                }
            }
        }

        if !cleanAppName.isEmpty && cleanAppName.count >= 3 {
            primaryIdentifiers.insert(cleanAppName)
            let noSpaces = cleanAppName.replacingOccurrences(of: " ", with: "")
            if noSpaces != cleanAppName && noSpaces.count >= 3 {
                primaryIdentifiers.insert(noSpaces)
            }
        }

        if let executableName, !executableName.isEmpty && executableName.count >= 3 {
            primaryIdentifiers.insert(executableName)
        }

        if let bundleName, !bundleName.isEmpty && bundleName.count >= 3 {
            primaryIdentifiers.insert(bundleName)
        }

        // Generic keywords to filter out for safety
        let blockedKeywords: Set<String> = [
            "app", "application", "macos", "osx", "apple", "system", "helper",
            "plugin", "default", "library", "framework", "agent", "service"
        ]

        // Helper to check and append single path if exists safely
        func checkItem(url: URL, category: LeftoverCategory, displayName: String? = nil) {
            let path = url.path
            guard fileManager.fileExists(atPath: path) else { return }

            // Strict safety: Never delete root library directories
            let prohibitedPaths: Set<String> = [
                libraryURL.path,
                libraryURL.appendingPathComponent("Caches").path,
                libraryURL.appendingPathComponent("Application Support").path,
                libraryURL.appendingPathComponent("Preferences").path,
                libraryURL.appendingPathComponent("Containers").path,
                libraryURL.appendingPathComponent("Group Containers").path,
                libraryURL.appendingPathComponent("Logs").path,
                "/Applications",
                "/System",
                "/Library",
                "/Library/Caches",
                "/Library/Application Support"
            ]
            guard !prohibitedPaths.contains(path) else { return }

            // Avoid duplicates
            if items.contains(where: { $0.url.path == path }) { return }

            let isDir = isDirectory(at: url)
            let size = calculateItemSize(at: url)

            items.append(
                LeftoverItem(
                    url: url,
                    path: path,
                    displayName: displayName ?? url.lastPathComponent,
                    category: category,
                    size: size,
                    isDirectory: isDir,
                    isSelected: true
                )
            )
        }

        // Helper to scan directory for items matching identifiers
        func scanDirectory(
            _ directoryURL: URL,
            category: LeftoverCategory,
            checkSubfolders: Bool = false
        ) {
            guard fileManager.fileExists(atPath: directoryURL.path) else { return }
            guard let contents = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            for itemURL in contents {
                let itemName = itemURL.lastPathComponent
                let lowerName = itemName.lowercased()

                var matched = false

                // 1. Check primary identifiers (exact or contains)
                for id in primaryIdentifiers {
                    let lowerId = id.lowercased()
                    if lowerName == lowerId ||
                       lowerName.hasPrefix("\(lowerId).") ||
                       lowerName.hasPrefix("\(lowerId)_") ||
                       lowerName.contains(lowerId) {
                        matched = true
                        break
                    }
                }

                // 2. Check sub-keywords if not already matched
                if !matched {
                    for kw in subKeywords where !blockedKeywords.contains(kw.lowercased()) {
                        let lowerKw = kw.lowercased()
                        if lowerName == lowerKw ||
                           lowerName.hasPrefix("\(lowerKw).") ||
                           lowerName.hasPrefix("\(lowerKw)-") {
                            matched = true
                            break
                        }
                    }
                }

                if matched {
                    checkItem(url: itemURL, category: category)
                } else if checkSubfolders {
                    // Check 1 level of subdirectories (e.g. Google/Chrome, Microsoft/Edge)
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir), isDir.boolValue {
                        if let subContents = try? fileManager.contentsOfDirectory(
                            at: itemURL,
                            includingPropertiesForKeys: nil,
                            options: [.skipsHiddenFiles]
                        ) {
                            for subURL in subContents {
                                let subName = subURL.lastPathComponent.lowercased()
                                for id in primaryIdentifiers {
                                    let lowerId = id.lowercased()
                                    if subName == lowerId || subName.contains(lowerId) {
                                        checkItem(url: subURL, category: category)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Direct directory in ~/Library (e.g., ~/Library/Unity)
        checkItem(url: libraryURL.appendingPathComponent(cleanAppName), category: .applicationSupport)

        // 2. Preferences (~/Library/Preferences)
        let preferencesURL = libraryURL.appendingPathComponent("Preferences", isDirectory: true)
        if let bundleID {
            checkItem(url: preferencesURL.appendingPathComponent("\(bundleID).plist"), category: .preferences)
            checkItem(url: preferencesURL.appendingPathComponent("\(bundleID).plist.lockfile"), category: .preferences)
            let byHostURL = preferencesURL.appendingPathComponent("ByHost", isDirectory: true)
            scanDirectory(byHostURL, category: .preferences)
        }
        checkItem(url: preferencesURL.appendingPathComponent("\(cleanAppName).plist"), category: .preferences)
        checkItem(url: preferencesURL.appendingPathComponent(cleanAppName), category: .preferences)
        scanDirectory(preferencesURL, category: .preferences)

        // 3. Application Support (~/Library/Application Support and /Library/Application Support)
        let appSupportURL = libraryURL.appendingPathComponent("Application Support", isDirectory: true)
        checkItem(url: appSupportURL.appendingPathComponent(cleanAppName), category: .applicationSupport)
        if let bundleID {
            checkItem(url: appSupportURL.appendingPathComponent(bundleID), category: .applicationSupport)
        }
        if let executableName {
            checkItem(url: appSupportURL.appendingPathComponent(executableName), category: .applicationSupport)
        }
        scanDirectory(appSupportURL, category: .applicationSupport, checkSubfolders: true)

        let sysAppSupportURL = URL(fileURLWithPath: "/Library/Application Support", isDirectory: true)
        checkItem(url: sysAppSupportURL.appendingPathComponent(cleanAppName), category: .applicationSupport)
        if let bundleID {
            checkItem(url: sysAppSupportURL.appendingPathComponent(bundleID), category: .applicationSupport)
        }

        // 4. Caches (~/Library/Caches and /Library/Caches)
        let cachesURL = libraryURL.appendingPathComponent("Caches", isDirectory: true)
        if let bundleID {
            checkItem(url: cachesURL.appendingPathComponent(bundleID), category: .caches)
            checkItem(url: cachesURL.appendingPathComponent("com.apple.nsurlsessiond/Downloads/\(bundleID)"), category: .caches)
        }
        checkItem(url: cachesURL.appendingPathComponent(cleanAppName), category: .caches)
        if let executableName {
            checkItem(url: cachesURL.appendingPathComponent(executableName), category: .caches)
        }
        scanDirectory(cachesURL, category: .caches, checkSubfolders: true)

        // Darwin User Cache (/var/folders/.../C/<bundleID>)
        if let darwinCache = getDarwinUserCacheDirectory() {
            for id in primaryIdentifiers {
                checkItem(url: darwinCache.appendingPathComponent(id), category: .caches)
            }
        }

        // 5. Containers (~/Library/Containers)
        let containersURL = libraryURL.appendingPathComponent("Containers", isDirectory: true)
        if let bundleID {
            checkItem(url: containersURL.appendingPathComponent(bundleID), category: .containers)
        }
        checkItem(url: containersURL.appendingPathComponent(cleanAppName), category: .containers)
        scanDirectory(containersURL, category: .containers)

        // 6. Group Containers (~/Library/Group Containers)
        let groupContainersURL = libraryURL.appendingPathComponent("Group Containers", isDirectory: true)
        scanDirectory(groupContainersURL, category: .groupContainers)

        // 7. Saved Application State (~/Library/Saved Application State)
        let savedStateURL = libraryURL.appendingPathComponent("Saved Application State", isDirectory: true)
        if let bundleID {
            checkItem(url: savedStateURL.appendingPathComponent("\(bundleID).savedState"), category: .savedState)
        }
        checkItem(url: savedStateURL.appendingPathComponent("\(cleanAppName).savedState"), category: .savedState)
        scanDirectory(savedStateURL, category: .savedState)

        // 8. Logs & Diagnostics (~/Library/Logs)
        let logsURL = libraryURL.appendingPathComponent("Logs", isDirectory: true)
        checkItem(url: logsURL.appendingPathComponent(cleanAppName), category: .logs)
        if let bundleID {
            checkItem(url: logsURL.appendingPathComponent(bundleID), category: .logs)
        }
        scanDirectory(logsURL, category: .logs, checkSubfolders: true)

        let diagURL = logsURL.appendingPathComponent("DiagnosticReports", isDirectory: true)
        scanDirectory(diagURL, category: .logs)

        // 9. HTTPStorages & WebKit (~/Library/HTTPStorages, ~/Library/WebKit, ~/Library/Cookies)
        let httpStoragesURL = libraryURL.appendingPathComponent("HTTPStorages", isDirectory: true)
        if let bundleID {
            checkItem(url: httpStoragesURL.appendingPathComponent(bundleID), category: .httpStorages)
            checkItem(url: httpStoragesURL.appendingPathComponent("\(bundleID).binarycookies"), category: .httpStorages)
        }
        let cookiesURL = libraryURL.appendingPathComponent("Cookies", isDirectory: true)
        if let bundleID {
            checkItem(url: cookiesURL.appendingPathComponent("\(bundleID).binarycookies"), category: .httpStorages)
        }
        let webKitURL = libraryURL.appendingPathComponent("WebKit", isDirectory: true)
        if let bundleID {
            checkItem(url: webKitURL.appendingPathComponent(bundleID), category: .httpStorages)
        }

        // 10. LaunchAgents (~/Library/LaunchAgents)
        let launchAgentsURL = libraryURL.appendingPathComponent("LaunchAgents", isDirectory: true)
        scanDirectory(launchAgentsURL, category: .launchAgents)

        // 11. Application Scripts (~/Library/Application Scripts)
        let appScriptsURL = libraryURL.appendingPathComponent("Application Scripts", isDirectory: true)
        if let bundleID {
            checkItem(url: appScriptsURL.appendingPathComponent(bundleID), category: .other)
        }
        checkItem(url: appScriptsURL.appendingPathComponent(cleanAppName), category: .other)

        // 13. System LaunchAgents & LaunchDaemons (/Library/LaunchAgents, /Library/LaunchDaemons)
        let sysLaunchAgents = URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true)
        scanDirectory(sysLaunchAgents, category: .launchAgents)
        let sysLaunchDaemons = URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true)
        scanDirectory(sysLaunchDaemons, category: .launchAgents)

        // 14. Privileged Helper Tools (/Library/PrivilegedHelperTools)
        let privHelperURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools", isDirectory: true)
        scanDirectory(privHelperURL, category: .other)

        // 15. Preference Panes (~/Library/PreferencePanes, /Library/PreferencePanes)
        let prefPanesURL = libraryURL.appendingPathComponent("PreferencePanes", isDirectory: true)
        scanDirectory(prefPanesURL, category: .preferences)
        let sysPrefPanesURL = URL(fileURLWithPath: "/Library/PreferencePanes", isDirectory: true)
        scanDirectory(sysPrefPanesURL, category: .preferences)

        // 16. QuickLook and Internet Plug-Ins
        let quickLookURL = libraryURL.appendingPathComponent("QuickLook", isDirectory: true)
        scanDirectory(quickLookURL, category: .other)
        let sysQuickLookURL = URL(fileURLWithPath: "/Library/QuickLook", isDirectory: true)
        scanDirectory(sysQuickLookURL, category: .other)
        let internetPluginsURL = libraryURL.appendingPathComponent("Internet Plug-Ins", isDirectory: true)
        scanDirectory(internetPluginsURL, category: .other)

        // 17. Cross-Platform Developer Tools (~/.config)
        let configURL = home.appendingPathComponent(".config", isDirectory: true)
        scanDirectory(configURL, category: .other)

        // 18. CrashReporter (~/Library/Application Support/CrashReporter)
        let crashRepURL = appSupportURL.appendingPathComponent("CrashReporter", isDirectory: true)
        scanDirectory(crashRepURL, category: .logs)

        // 19. Darwin User Temp Directory (/var/folders/.../T/<id>)
        if let darwinTemp = getDarwinUserTempDirectory() {
            for id in primaryIdentifiers {
                checkItem(url: darwinTemp.appendingPathComponent(id), category: .caches)
            }
        }

        return items
    }

    private func getDarwinUserCacheDirectory() -> URL? {
        let tmp = NSTemporaryDirectory()
        let parent = URL(fileURLWithPath: tmp).deletingLastPathComponent()
        let cacheDir = parent.appendingPathComponent("C", isDirectory: true)
        if FileManager.default.fileExists(atPath: cacheDir.path) {
            return cacheDir
        }
        return nil
    }

    private func getDarwinUserTempDirectory() -> URL? {
        let tmp = NSTemporaryDirectory()
        let parent = URL(fileURLWithPath: tmp).deletingLastPathComponent()
        let tempDir = parent.appendingPathComponent("T", isDirectory: true)
        if FileManager.default.fileExists(atPath: tempDir.path) {
            return tempDir
        }
        return nil
    }

    private func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }

    public func calculateItemSize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: []
        ) else {
            return 0
        }

        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }

        return totalSize
    }
}
