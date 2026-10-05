import AppKit
import Foundation

public struct InstalledApp: Identifiable, Hashable, @unchecked Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let bundleIdentifier: String?
    public let version: String
    public let icon: NSImage
    public var bundleSize: Int64
    public let isSystemApp: Bool
    public let shortcutURL: URL?

    public init(
        url: URL,
        name: String,
        bundleIdentifier: String?,
        version: String,
        icon: NSImage,
        bundleSize: Int64 = 0,
        isSystemApp: Bool = false,
        shortcutURL: URL? = nil
    ) {
        self.id = bundleIdentifier ?? url.path
        self.url = url
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.icon = icon
        self.bundleSize = bundleSize
        self.isSystemApp = isSystemApp
        self.shortcutURL = shortcutURL
    }

    public var isShortcut: Bool {
        shortcutURL != nil
    }

    public var formattedSize: String {
        if bundleSize <= 0 {
            return "Calculating..."
        }
        return ByteCountFormatter.string(fromByteCount: bundleSize, countStyle: .file)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(url)
    }

    public static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
