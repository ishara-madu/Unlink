import AppKit
import Foundation

public struct AppScannerService: Sendable {
    public static let shared = AppScannerService()

    public init() {}

    public static func resolveApplicationTarget(from url: URL) -> (realURL: URL, isShortcut: Bool, shortcutURL: URL?) {
        let fileManager = FileManager.default
        var isShortcut = false
        var currentURL = url

        // 1. Resolve Symlinks
        let symlinkTarget = currentURL.resolvingSymlinksInPath()
        if symlinkTarget.path != currentURL.path {
            isShortcut = true
            currentURL = symlinkTarget
        }

        // 2. Resolve Finder Aliases (Bookmark files)
        do {
            let res = try currentURL.resourceValues(forKeys: [.isAliasFileKey, .isSymbolicLinkKey])
            if res.isAliasFile == true || res.isSymbolicLink == true {
                isShortcut = true
                let resolved = try URL(resolvingAliasFileAt: currentURL, options: [.withoutUI, .withoutMounting])
                currentURL = resolved
            }
        } catch {
            if let bookmarkData = try? URL.bookmarkData(withContentsOf: currentURL) {
                var isStale = false
                if let resolved = try? URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    isShortcut = true
                    currentURL = resolved
                }
            }
        }

        // Check if the resolved file is an .app and exists
        if currentURL.pathExtension.lowercased() == "app" && fileManager.fileExists(atPath: currentURL.path) {
            return (currentURL, isShortcut, isShortcut ? url : nil)
        }

        return (currentURL, isShortcut, isShortcut ? url : nil)
    }

    nonisolated(unsafe) private static let iconCache = NSCache<NSString, NSImage>()

    public func scanInstalledApplications(includeSystem: Bool = false) async -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fileManager = FileManager.default

        var searchDirectories: [(url: URL, isSystem: Bool)] = [
            (URL(fileURLWithPath: "/Applications"), false),
            (URL(fileURLWithPath: "/Applications/Utilities"), false),
            (fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true), false)
        ]

        if includeSystem {
            searchDirectories.append((URL(fileURLWithPath: "/System/Applications"), true))
        }

        var seenURLs = Set<URL>()

        for (directory, isSystem) in searchDirectories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }

            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            ) else { continue }

            while let fileURL = enumerator.nextObject() as? URL {
                let (targetURL, _, shortcutURL) = Self.resolveApplicationTarget(from: fileURL)

                guard targetURL.pathExtension.lowercased() == "app" else { continue }

                // Do not descend inside an .app bundle itself (skips internal helpers)
                if fileURL.pathExtension.lowercased() == "app" {
                    enumerator.skipDescendants()
                }

                // Skip internal helpers (pointing inside an .app/Contents/)
                if targetURL.path.contains(".app/Contents/") {
                    continue
                }

                guard !seenURLs.contains(targetURL) else { continue }
                seenURLs.insert(targetURL)

                if let app = parseApplication(at: targetURL, isSystem: isSystem, shortcutURL: shortcutURL) {
                    apps.append(app)
                }
            }
        }

        // Sort alphabetically by name
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func scanSystemApplications() async -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fileManager = FileManager.default
        let directory = URL(fileURLWithPath: "/System/Applications")
        guard fileManager.fileExists(atPath: directory.path) else { return [] }

        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var seenURLs = Set<URL>()

        while let fileURL = enumerator.nextObject() as? URL {
            let (targetURL, _, shortcutURL) = Self.resolveApplicationTarget(from: fileURL)

            guard targetURL.pathExtension.lowercased() == "app" else { continue }

            if fileURL.pathExtension.lowercased() == "app" {
                enumerator.skipDescendants()
            }

            if targetURL.path.contains(".app/Contents/") {
                continue
            }

            guard !seenURLs.contains(targetURL) else { continue }
            seenURLs.insert(targetURL)

            if let app = parseApplication(at: targetURL, isSystem: true, shortcutURL: shortcutURL) {
                apps.append(app)
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func parseApplication(at url: URL, isSystem: Bool = false, shortcutURL: URL? = nil) -> InstalledApp? {
        let (realURL, _, detectedShortcut) = Self.resolveApplicationTarget(from: url)
        let effectiveShortcut = shortcutURL ?? detectedShortcut

        let bundle = Bundle(url: realURL)
        var name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? realURL.deletingPathExtension().lastPathComponent

        let bundleIdentifier = bundle?.bundleIdentifier
        let shortVersion = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        var version = shortVersion ?? (bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1.0"

        // Clean up version if prefixed with app name
        if version.lowercased().hasPrefix(name.lowercased()) {
            version = version.dropFirst(name.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if version.lowercased().hasPrefix("version") {
                version = version.dropFirst(7).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // If the app is nested inside a versioned or named subfolder (e.g., Unity/Hub/Editor/2020.3.49f1/Unity.app)
        let parentDir = realURL.deletingLastPathComponent()
        let parentName = parentDir.lastPathComponent
        let standardAppDirs: Set<String> = [
            "Applications", "Utilities", "System"
        ]
        if !standardAppDirs.contains(parentName) && parentName != name {
            if parentName.rangeOfCharacter(from: .decimalDigits) != nil || parentName.count < 15 {
                name = "\(name) (\(parentName))"
            }
        }

        let icon: NSImage
        let cacheKey = realURL.path as NSString
        if let cached = Self.iconCache.object(forKey: cacheKey) {
            icon = cached
        } else {
            let loaded = NSWorkspace.shared.icon(forFile: realURL.path)
            loaded.size = NSSize(width: 64, height: 64)
            Self.iconCache.setObject(loaded, forKey: cacheKey)
            icon = loaded
        }

        return InstalledApp(
            url: realURL,
            name: name,
            bundleIdentifier: bundleIdentifier,
            version: version,
            icon: icon,
            bundleSize: 0,
            isSystemApp: isSystem,
            shortcutURL: effectiveShortcut
        )
    }

    public func calculateDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
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
