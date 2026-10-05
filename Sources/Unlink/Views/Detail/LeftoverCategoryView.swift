import SwiftUI

public struct LeftoverCategoryView: View {
    public let category: LeftoverCategory
    public let items: [LeftoverItem]
    public let onToggleCategory: (Bool) -> Void
    public let onToggleItem: (UUID) -> Void
    public let onRevealItem: (URL) -> Void

    @State private var isExpanded: Bool = true

    public var categoryTotalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    public var selectedCategorySize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    public var formattedCategorySize: String {
        ByteCountFormatter.string(fromByteCount: categoryTotalSize, countStyle: .file)
    }

    public var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedCategorySize, countStyle: .file)
    }

    public var isAllSelected: Bool {
        !items.isEmpty && items.allSatisfy { $0.isSelected }
    }

    public var hasAnySelected: Bool {
        items.contains(where: { $0.isSelected })
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Category Header Card
            HStack(spacing: 10) {
                // Category Checkbox
                Button {
                    onToggleCategory(!isAllSelected)
                } label: {
                    Image(systemName: isAllSelected ? "checkmark.circle.fill" : (hasAnySelected ? "minus.circle.fill" : "circle"))
                        .font(.system(size: 15))
                        .foregroundStyle(hasAnySelected ? category.tintColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(isAllSelected ? "Deselect all in \(category.displayName)" : "Select all in \(category.displayName)")

                // Category Icon
                Image(systemName: category.iconName)
                    .font(.system(size: 13))
                    .foregroundStyle(category.tintColor)

                // Category Title
                Text(category.displayName)
                    .font(.system(size: 13, weight: .semibold))

                // Item Count Pill
                Text("\(items.count)")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)

                Spacer()

                // Category Size Display
                if isAllSelected {
                    Text(formattedCategorySize)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if hasAnySelected {
                    Text("\(formattedSelectedSize) / \(formattedCategorySize)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("0 B / \(formattedCategorySize)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                // Collapse/Expand Arrow
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Sub-items
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(items) { item in
                        LeftoverRowView(
                            item: item,
                            onToggle: { onToggleItem(item.id) },
                            onReveal: { onRevealItem(item.url) }
                        )
                    }
                }
                .padding(.leading, 12)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 4)
    }
}
