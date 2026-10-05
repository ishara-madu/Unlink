import SwiftUI

public struct LeftoverRowView: View {
    public let item: LeftoverItem
    public let onToggle: () -> Void
    public let onReveal: () -> Void

    @State private var isHovering: Bool = false

    public var body: some View {
        HStack(spacing: 10) {
            // Checkbox Button
            Button {
                onToggle()
            } label: {
                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(item.isSelected ? Color.accentColor : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)

            // File or Folder Icon
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 13))
                .foregroundStyle(item.isSelected ? item.category.tintColor : item.category.tintColor.opacity(0.4))

            // File Path and Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 12, weight: item.isSelected ? .medium : .regular))
                        .foregroundStyle(item.isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)

                    if !item.isSelected {
                        Text("KEPT")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(item.relativePathDisplay)
                    .font(.system(size: 10))
                    .foregroundStyle(item.isSelected ? .secondary : .tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.path)
            }

            Spacer()

            // Reveal in Finder Button
            if isHovering {
                Button {
                    onReveal()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
                .transition(.opacity)
            }

            // File Size
            Text(item.formattedSize)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(item.isSelected ? Color.primary : Color.secondary.opacity(0.6))
                .frame(minWidth: 65, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
