import SwiftUI

public struct SidebarView: View {
    @Bindable var viewModel: UnlinkViewModel

    public var body: some View {
        VStack(spacing: 0) {
            // Search Bar Area
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))

                TextField("Search applications...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Filter Strip (Show System Apps toggle & Select All)
            HStack(spacing: 8) {
                // Show/Hide System Apps Button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.toggleSystemApps()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isScanningSystemApps {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: viewModel.showSystemApps ? "shield.fill" : "shield")
                                .font(.system(size: 10))
                        }
                        Text(viewModel.showSystemApps ? "System Visible" : "Show System")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(viewModel.showSystemApps ? Color.orange.opacity(0.15) : Color.primary.opacity(0.05))
                    .foregroundStyle(viewModel.showSystemApps ? Color.orange : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Toggle visibility of macOS system applications")

                Spacer()

                // Batch Selection Actions
                if !viewModel.markedAppIDs.isEmpty {
                    Button {
                        viewModel.deselectAllMarked()
                    } label: {
                        Text("Clear (\(viewModel.markedAppIDs.count))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Clear marked applications")
                } else {
                    Button {
                        viewModel.selectAllMarked()
                    } label: {
                        Text("Select All")
                            .font(.system(size: 11))
                            .foregroundStyle(viewModel.isScanningApps || viewModel.filteredApps.isEmpty ? .tertiary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isScanningApps || viewModel.filteredApps.isEmpty)
                    .help("Mark all applications for batch deletion")
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Application List
            if viewModel.isScanningApps && viewModel.installedApps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .controlSize(.regular)
                    Text("Scanning Applications...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if viewModel.filteredApps.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "questionmark.app.dashed")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(viewModel.searchQuery.isEmpty ? "No Applications Found" : "No Matches Found")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(selection: Binding(
                    get: { viewModel.selectedApp },
                    set: { newApp in
                        if let newApp {
                            viewModel.selectApp(newApp)
                        } else {
                            viewModel.clearSelection()
                        }
                    }
                )) {
                    Section {
                        ForEach(viewModel.filteredApps) { app in
                            AppRowView(
                                app: app,
                                isSelected: viewModel.selectedApp?.id == app.id,
                                isMarked: viewModel.markedAppIDs.contains(app.id),
                                onToggleMark: {
                                    viewModel.toggleAppMarked(id: app.id)
                                }
                            )
                            .tag(app)
                        }
                    } header: {
                        HStack {
                            Text(viewModel.showSystemApps ? "All Applications" : "User Applications")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Spacer()

                            if !viewModel.markedAppIDs.isEmpty {
                                Text("\(viewModel.markedAppIDs.count) marked")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red)
                            } else {
                                Text("\(viewModel.filteredApps.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            // Sidebar Bottom Status Bar
            HStack {
                Button {
                    viewModel.loadInstalledApps()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Rescan Applications")

                Spacer()

                Text("\(viewModel.filteredApps.count) Apps • \(viewModel.userAppsCount) User")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
