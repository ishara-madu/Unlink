import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct MainWindowView: View {
    @State private var viewModel = UnlinkViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 240, ideal: 290, max: 350)
        } detail: {
            Group {
                if viewModel.markedApps.count > 1 {
                    BatchUninstallView(viewModel: viewModel)
                } else if let firstMarked = viewModel.markedApps.first {
                    AppDetailView(viewModel: viewModel, app: firstMarked)
                } else if let selectedApp = viewModel.selectedApp {
                    AppDetailView(viewModel: viewModel, app: selectedApp)
                } else {
                    DropZoneView(viewModel: viewModel)
                }
            }
            .frame(minWidth: 480, minHeight: 400)
        }
        .navigationTitle("Unlink")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if viewModel.selectedApp != nil || !viewModel.markedApps.isEmpty {
                    Button {
                        viewModel.clearSelection()
                        viewModel.deselectAllMarked()
                    } label: {
                        Label("Back to Drop Zone", systemImage: "xmark")
                    }
                    .help("Return to Drop Zone")
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async {
                    viewModel.handleDroppedURL(url)
                }
            }
            return true
        }
        .task {
            viewModel.loadInstalledApps()
        }
        // Single App Confirmation
        .confirmationDialog(
            "Move Associated Files to Trash?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash (\(viewModel.formattedTotalSelectedSize))", role: .destructive) {
                viewModel.executeDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if viewModel.selectedCount < viewModel.totalCount {
                Text("Unlink will move \(viewModel.selectedCount) selected item(s) to macOS Trash.\n\nNote: \(viewModel.totalCount - viewModel.selectedCount) unselected item(s) will NOT be touched and will remain on your Mac.")
            } else {
                Text("Unlink will safely move all \(viewModel.selectedCount) items to macOS Trash. You can restore them from Trash if needed.")
            }
        }
        // Batch Delete Confirmation
        .confirmationDialog(
            "Move \(viewModel.markedApps.count) Applications to Trash?",
            isPresented: $viewModel.showBatchDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall \(viewModel.markedApps.count) Apps (\(viewModel.formattedBatchTotalSize))", role: .destructive) {
                viewModel.executeBatchDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Unlink will safely move \(viewModel.markedApps.count) selected applications and all their associated caches, preferences, and container files to macOS Trash.")
        }
        // Single App Success Alert
        .alert("Uninstall Complete", isPresented: $viewModel.showTrashResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = viewModel.trashResult {
                if result.errors.isEmpty {
                    Text("Successfully moved \(result.trashedCount) items (\(result.formattedFreedBytes)) to Trash.")
                } else {
                    Text("Moved \(result.trashedCount) items to Trash. \(result.errors.count) item(s) encountered permission errors.")
                }
            }
        }
        // Batch Success Alert
        .alert("Batch Uninstall Complete", isPresented: $viewModel.showBatchResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = viewModel.batchTrashResult {
                if result.errors.isEmpty {
                    Text("Successfully uninstalled applications and moved \(result.trashedCount) items (\(result.formattedFreedBytes)) to macOS Trash.")
                } else {
                    Text("Moved \(result.trashedCount) items to Trash. \(result.errors.count) item(s) encountered permission errors.")
                }
            }
        }
    }
}
