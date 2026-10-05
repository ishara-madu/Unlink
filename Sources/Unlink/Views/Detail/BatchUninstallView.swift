import AppKit
import SwiftUI

public struct BatchUninstallView: View {
    @Bindable var viewModel: UnlinkViewModel

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: "trash.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Batch Application Removal")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(viewModel.markedApps.count) applications selected with associated files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Total Space to Free Badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Space to Reclaim")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if viewModel.isAnalyzingBatchLeftovers {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Calculating...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(viewModel.formattedBatchTotalSize)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Scrollable List of Selected Apps
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.markedApps) { app in
                        BatchAppCard(
                            app: app,
                            viewModel: viewModel,
                            onRemove: {
                                viewModel.toggleAppMarked(id: app.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            Divider()

            // Sticky Bottom Action Bar
            HStack(spacing: 16) {
                Button {
                    viewModel.deselectAllMarked()
                } label: {
                    Label("Clear All Selected", systemImage: "xmark.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(viewModel.markedApps.count) applications marked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if viewModel.isAnalyzingBatchLeftovers {
                        Text("Scanning files...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(viewModel.formattedBatchTotalSize)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                }

                Button {
                    viewModel.requestBatchDelete()
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isAnalyzingBatchLeftovers {
                            ProgressView()
                                .controlSize(.small)
                            Text("Analyzing Files (\(viewModel.analyzedBatchAppsCount)/\(viewModel.markedApps.count))...")
                                .font(.system(size: 12, weight: .semibold))
                        } else {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 12))
                            Text("Uninstall \(viewModel.markedApps.count) Apps")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
                .disabled(viewModel.isBatchDeleting || viewModel.markedApps.isEmpty || viewModel.isAnalyzingBatchLeftovers)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
}

private struct BatchAppCard: View {
    let app: InstalledApp
    @Bindable var viewModel: UnlinkViewModel
    let onRemove: () -> Void

    @State private var isExpanded: Bool = false

    private var leftovers: [LeftoverItem]? {
        viewModel.batchLeftovers[app.id]
    }

    private var selectedSize: Int64 {
        if let leftovers {
            return leftovers.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        }
        return app.bundleSize
    }

    private var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }

    private var totalCount: Int {
        leftovers?.count ?? 0
    }

    private var selectedCount: Int {
        leftovers?.filter { $0.isSelected }.count ?? 0
    }

    private var categories: [LeftoverCategory] {
        viewModel.batchCategories(for: app.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main Card Header
            HStack(spacing: 12) {
                // Expand / Collapse Chevron Button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Collapse associated files" : "Expand associated files")

                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .semibold))

                        if app.isShortcut {
                            Text("SHORTCUT")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .foregroundStyle(.blue)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("v\(app.version)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        if leftovers != nil {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text("\(selectedCount) of \(totalCount) files selected")
                                .font(.system(size: 10))
                                .foregroundStyle(selectedCount == totalCount ? .secondary : Color.accentColor)
                        } else {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            ProgressView()
                                .controlSize(.mini)
                            Text("Analyzing leftovers...")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Text(formattedSelectedSize)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(selectedSize > 0 ? Color.primary : Color.secondary)

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Remove from batch")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Dropdown Content Panel
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    if leftovers != nil {
                        // Quick Action Sub-bar
                        HStack {
                            Text("Associated Files for \(app.name)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                viewModel.setAllBatchItemsSelected(appID: app.id, isSelected: true)
                            } label: {
                                Text("Select All")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)

                            Text("•")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)

                            Button {
                                viewModel.setAllBatchItemsSelected(appID: app.id, isSelected: false)
                            } label: {
                                Text("Deselect All")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                        // Categorized Leftover Items
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(categories) { category in
                                let items = viewModel.batchItems(for: app.id, category: category)
                                let isCategoryAllSelected = !items.isEmpty && items.allSatisfy { $0.isSelected }
                                let categorySize = items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }

                                VStack(alignment: .leading, spacing: 4) {
                                    // Category Header
                                    HStack(spacing: 6) {
                                        Button {
                                            viewModel.toggleBatchCategory(appID: app.id, category: category, isSelected: !isCategoryAllSelected)
                                        } label: {
                                            Image(systemName: isCategoryAllSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 11))
                                                .foregroundStyle(isCategoryAllSelected ? category.tintColor : Color.secondary.opacity(0.5))
                                        }
                                        .buttonStyle(.plain)

                                        Image(systemName: category.iconName)
                                            .font(.system(size: 11))
                                            .foregroundStyle(category.tintColor)

                                        Text(category.displayName)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Text(ByteCountFormatter.string(fromByteCount: categorySize, countStyle: .file))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)

                                    // Category Rows
                                    VStack(spacing: 2) {
                                        ForEach(items) { item in
                                            LeftoverRowView(
                                                item: item,
                                                onToggle: {
                                                    viewModel.toggleBatchItemSelection(appID: app.id, itemID: item.id)
                                                },
                                                onReveal: {
                                                    viewModel.revealInFinder(url: item.url)
                                                }
                                            )
                                        }
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Scanning associated files for \(app.name)...")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
