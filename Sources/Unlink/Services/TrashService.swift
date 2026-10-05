import AppKit
import Foundation

public struct TrashResult: Sendable {
    public let trashedCount: Int
    public let freedBytes: Int64
    public let errors: [String]

    public var formattedFreedBytes: String {
        ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)
    }
}

public struct TrashService: Sendable {
    public static let shared = TrashService()

    public init() {}

    public func trashItems(_ items: [LeftoverItem]) -> TrashResult {
        let fileManager = FileManager.default
        var trashedCount = 0
        var freedBytes: Int64 = 0
        var errors: [String] = []

        // Terminate any running application before trashing to avoid file lock conflicts
        for item in items where item.category == .appBundle && item.isSelected {
            if let bundle = Bundle(url: item.url), let bundleID = bundle.bundleIdentifier {
                let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                for running in runningInstances {
                    running.terminate()
                }
            }
        }

        for item in items where item.isSelected {
            guard fileManager.fileExists(atPath: item.url.path) else {
                continue
            }

            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: item.url, resultingItemURL: &resultingURL)
                trashedCount += 1
                freedBytes += item.size
            } catch {
                errors.append("\(item.displayName): \(error.localizedDescription)")
            }
        }

        return TrashResult(
            trashedCount: trashedCount,
            freedBytes: freedBytes,
            errors: errors
        )
    }
}
