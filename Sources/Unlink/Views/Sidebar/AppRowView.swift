import AppKit
import SwiftUI

public struct AppRowView: View {
    public let app: InstalledApp
    public let isSelected: Bool
    public let isMarked: Bool
    public let onToggleMark: () -> Void

    public var body: some View {
        HStack(spacing: 10) {
            // Checkbox for batch selection or lock for system apps
            if app.isSystemApp {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .frame(width: 16, height: 16)
                    .help("System Protected (Cannot be deleted)")
            } else {
                Button {
                    onToggleMark()
                } label: {
                    Image(systemName: isMarked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundStyle(isMarked ? Color.accentColor : Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .help(isMarked ? "Uncheck application" : "Mark for batch deletion")
            }

            // App Icon
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

            // App Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    if app.isSystemApp {
                        Text("SYSTEM")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(.secondary)
                    } else if app.isShortcut {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.system(size: 7))
                            Text("SHORTCUT")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(.blue)
                    }
                }

                Text(app.version.isEmpty ? "v1.0" : "v\(app.version)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if app.bundleSize > 0 {
                Text(app.formattedSize)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}
