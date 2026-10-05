import Foundation

public struct LeftoverItem: Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public let path: String
    public let displayName: String
    public let category: LeftoverCategory
    public let size: Int64
    public let isDirectory: Bool
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        path: String,
        displayName: String,
        category: LeftoverCategory,
        size: Int64,
        isDirectory: Bool,
        isSelected: Bool = true
    ) {
        self.id = id
        self.url = url
        self.path = path
        self.displayName = displayName
        self.category = category
        self.size = size
        self.isDirectory = isDirectory
        self.isSelected = isSelected
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var relativePathDisplay: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
