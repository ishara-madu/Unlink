import AppKit
import SwiftUI

public struct AppDetailView: View {
    @Bindable var viewModel: UnlinkViewModel
    public let app: InstalledApp

    public var body: some View {
        VStack(spacing: 0) {
            // App Information Header
            HStack(spacing: 16) {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        if app.isSystemApp {
                            Text("System Protected")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 10) {
                        if let bundleID = app.bundleIdentifier {
                            Text(bundleID)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Text("•")
                            .foregroundStyle(.tertiary)

                        Text("v\(app.version)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Text(app.url.path)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let shortcutURL = app.shortcutURL {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.system(size: 9))
                            Text("Shortcut: \(shortcutURL.lastPathComponent) → Target: \(app.url.lastPathComponent)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Spacer()

                // Total Leftover Size Badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Associated Size")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(viewModel.formattedTotalLeftoverSize)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Main Content Area
            if viewModel.isScanningLeftovers {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .controlSize(.regular)
                    Text("Scanning associated preferences, caches, and containers...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.leftovers.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("No Associated Files Found")
                        .font(.headline)
                    Text("This application does not appear to have any leftover files.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.presentCategories) { category in
                            LeftoverCategoryView(
                                category: category,
                                items: viewModel.items(for: category),
                                onToggleCategory: { isSelected in
                                    viewModel.toggleCategory(category: category, isSelected: isSelected)
                                },
                                onToggleItem: { itemId in
                                    viewModel.toggleItemSelection(id: itemId)
                                },
                                onRevealItem: { url in
                                    viewModel.revealInFinder(url: url)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }

            Divider()

            // Sticky Bottom Action Bar
            HStack(spacing: 16) {
                // Select All Button
                Button {
                    viewModel.setAllSelected(!viewModel.areAllSelected)
                } label: {
                    Label(
                        viewModel.areAllSelected ? "Deselect All" : "Select All",
                        systemImage: viewModel.areAllSelected ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Spacer()

                // Selected Size Summary
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(viewModel.selectedCount) of \(viewModel.totalCount) items selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if viewModel.selectedCount < viewModel.totalCount {
                            Text("(\(viewModel.totalCount - viewModel.selectedCount) kept)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(viewModel.formattedTotalSelectedSize)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(viewModel.selectedCount > 0 ? Color.primary : Color.secondary)
                }

                // Delete Button
                Button {
                    viewModel.requestDelete()
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isScanningLeftovers {
                            ProgressView()
                                .controlSize(.small)
                            Text("Scanning Files...")
                                .font(.system(size: 13, weight: .semibold))
                        } else {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 12))
                            Text("Uninstall Selected")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
                .disabled(viewModel.selectedCount == 0 || viewModel.isDeleting || viewModel.isScanningLeftovers)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
}
