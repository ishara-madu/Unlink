import AppKit
import Foundation
import Observation

@Observable
@MainActor
public final class UnlinkViewModel {
    public var installedApps: [InstalledApp] = []
    public var selectedApp: InstalledApp?
    public var leftovers: [LeftoverItem] = []
    public var searchQuery: String = ""

    // System Apps & Multi-selection
    public var showSystemApps: Bool = false
    public var markedAppIDs: Set<String> = []
    public var batchLeftovers: [String: [LeftoverItem]] = [:]

    public var isScanningApps: Bool = false
    public var isScanningSystemApps: Bool = false
    public var hasScannedSystemApps: Bool = false
    public var isScanningLeftovers: Bool = false
    public var isDeleting: Bool = false
    public var isBatchDeleting: Bool = false

    public var showDeleteConfirmation: Bool = false
    public var showBatchDeleteConfirmation: Bool = false
    public var trashResult: TrashResult?
    public var batchTrashResult: TrashResult?
    public var showTrashResultAlert: Bool = false
    public var showBatchResultAlert: Bool = false
    public var errorMessage: String?

    // Filtered applications based on search query and system app toggle
    public var filteredApps: [InstalledApp] {
        var list = installedApps
        if !showSystemApps {
            list = list.filter { !$0.isSystemApp }
        }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return list
    }

    public var userAppsCount: Int {
        installedApps.filter { !$0.isSystemApp }.count
    }

    public var systemAppsCount: Int {
        installedApps.filter { $0.isSystemApp }.count
    }

    public var markedApps: [InstalledApp] {
        installedApps.filter { markedAppIDs.contains($0.id) }
    }

    public var isAllFilteredMarked: Bool {
        let nonSystem = filteredApps.filter { !$0.isSystemApp }
        return !nonSystem.isEmpty && nonSystem.allSatisfy { markedAppIDs.contains($0.id) }
    }

    // Categories present in the current single app leftovers
    public var presentCategories: [LeftoverCategory] {
        let set = Set(leftovers.map { $0.category })
        return LeftoverCategory.allCases.filter { set.contains($0) }
    }

    public func items(for category: LeftoverCategory) -> [LeftoverItem] {
        leftovers.filter { $0.category == category }
    }

    public var totalSelectedSize: Int64 {
        leftovers.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    public var formattedTotalSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }

    public var totalLeftoverSize: Int64 {
        leftovers.reduce(0) { $0 + $1.size }
    }

    public var formattedTotalLeftoverSize: String {
        ByteCountFormatter.string(fromByteCount: totalLeftoverSize, countStyle: .file)
    }

    public var selectedCount: Int {
        leftovers.filter { $0.isSelected }.count
    }

    public var totalCount: Int {
        leftovers.count
    }

    public var areAllSelected: Bool {
        !leftovers.isEmpty && leftovers.allSatisfy { $0.isSelected }
    }

    public var isAnalyzingBatchLeftovers: Bool {
        !markedApps.isEmpty && markedApps.contains { batchLeftovers[$0.id] == nil }
    }

    public var analyzedBatchAppsCount: Int {
        markedApps.filter { batchLeftovers[$0.id] != nil }.count
    }

    public var batchTotalSize: Int64 {
        var total: Int64 = 0
        for app in markedApps {
            if let items = batchLeftovers[app.id] {
                total += items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
            } else {
                total += app.bundleSize
            }
        }
        return total
    }

    public var formattedBatchTotalSize: String {
        ByteCountFormatter.string(fromByteCount: batchTotalSize, countStyle: .file)
    }

    // MARK: - Actions
 
    public func toggleSystemApps() {
        showSystemApps.toggle()
        if showSystemApps && !hasScannedSystemApps {
            loadSystemApps()
        }
    }

    public func loadSystemApps() {
        guard !isScanningSystemApps else { return }
        isScanningSystemApps = true

        Task.detached(priority: .userInitiated) {
            let sysApps = await AppScannerService.shared.scanSystemApplications()
            await MainActor.run {
                let existingPaths = Set(self.installedApps.map { $0.url.path })
                let newApps = sysApps.filter { !existingPaths.contains($0.url.path) }
                self.installedApps.append(contentsOf: newApps)
                self.installedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.hasScannedSystemApps = true
                self.isScanningSystemApps = false
            }
        }
    }

    public func loadInstalledApps() {
        guard !isScanningApps else { return }
        isScanningApps = true

        let shouldIncludeSystem = showSystemApps

        Task.detached(priority: .userInitiated) {
            let apps = await AppScannerService.shared.scanInstalledApplications(includeSystem: shouldIncludeSystem)
            await MainActor.run {
                self.installedApps = apps
                self.isScanningApps = false
                if shouldIncludeSystem {
                    self.hasScannedSystemApps = true
                }
            }

            // Asynchronously compute bundle sizes in background without flooding MainActor
            var sizeMap: [String: Int64] = [:]
            var lastUpdateTime = Date()

            for app in apps where !app.isSystemApp {
                let size = AppScannerService.shared.calculateDirectorySize(at: app.url)
                sizeMap[app.id] = size

                // Throttle UI updates to at most once per 0.8s to prevent UI freeze
                if Date().timeIntervalSince(lastUpdateTime) >= 0.8 {
                    let currentBatch = sizeMap
                    await MainActor.run {
                        self.applyBundleSizes(currentBatch)
                    }
                    lastUpdateTime = Date()
                }
                await Task.yield()
            }

            let finalBatch = sizeMap
            await MainActor.run {
                self.applyBundleSizes(finalBatch)
            }
        }
    }

    private func applyBundleSizes(_ sizes: [String: Int64]) {
        for index in installedApps.indices {
            if let size = sizes[installedApps[index].id], installedApps[index].bundleSize != size {
                installedApps[index].bundleSize = size
            }
        }
    }

    public func selectApp(_ app: InstalledApp) {
        guard selectedApp?.id != app.id else { return }
        selectedApp = app
        leftovers = []
        isScanningLeftovers = true

        // When in single app mode (0 or 1 marked app), sync mark with selected app
        if markedAppIDs.count <= 1 {
            if !app.isSystemApp {
                markedAppIDs = [app.id]
            } else {
                markedAppIDs.removeAll()
            }
        }

        Task {
            let foundItems = await LeftoverScanner.shared.scanLeftovers(for: app)
            self.leftovers = foundItems
            self.isScanningLeftovers = false
            self.batchLeftovers[app.id] = foundItems
        }
    }

    public func handleDroppedURL(_ url: URL) {
        let (realURL, isShortcut, shortcutURL) = AppScannerService.resolveApplicationTarget(from: url)

        guard realURL.pathExtension.lowercased() == "app",
              FileManager.default.fileExists(atPath: realURL.path) else {
            errorMessage = "Please drop a valid macOS application or shortcut (.app / alias)."
            return
        }

        if let existing = installedApps.first(where: { $0.url.path == realURL.path }) {
            var updatedApp = existing
            if isShortcut && updatedApp.shortcutURL == nil {
                updatedApp = InstalledApp(
                    url: existing.url,
                    name: existing.name,
                    bundleIdentifier: existing.bundleIdentifier,
                    version: existing.version,
                    icon: existing.icon,
                    bundleSize: existing.bundleSize,
                    isSystemApp: existing.isSystemApp,
                    shortcutURL: shortcutURL
                )
            }
            selectApp(updatedApp)
            return
        }

        if let parsedApp = AppScannerService.shared.parseApplication(at: realURL, shortcutURL: shortcutURL) {
            installedApps.insert(parsedApp, at: 0)
            selectApp(parsedApp)
        }
    }

    public func clearSelection() {
        selectedApp = nil
        leftovers = []
    }

    public func toggleItemSelection(id: UUID) {
        if let index = leftovers.firstIndex(where: { $0.id == id }) {
            leftovers[index].isSelected.toggle()
        }
    }

    public func toggleCategory(category: LeftoverCategory, isSelected: Bool) {
        for index in leftovers.indices where leftovers[index].category == category {
            leftovers[index].isSelected = isSelected
        }
    }

    public func setAllSelected(_ select: Bool) {
        for index in leftovers.indices {
            leftovers[index].isSelected = select
        }
    }

    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func requestDelete() {
        guard selectedCount > 0, !isScanningLeftovers else { return }
        showDeleteConfirmation = true
    }

    public func executeDelete() {
        guard !isDeleting, !isScanningLeftovers, let app = selectedApp else { return }
        isDeleting = true

        Task {
            var itemsToDelete = self.leftovers.filter { $0.isSelected }
            if itemsToDelete.isEmpty {
                // If leftovers were somehow not populated, ensure we deep-scan before deleting anything
                let scanned = await LeftoverScanner.shared.scanLeftovers(for: app)
                self.leftovers = scanned
                itemsToDelete = scanned.filter { $0.isSelected }
            }

            let result = await Task.detached(priority: .userInitiated) {
                TrashService.shared.trashItems(itemsToDelete)
            }.value

            self.isDeleting = false
            self.trashResult = result
            self.showTrashResultAlert = true

            // Remove deleted items from the current view
            self.leftovers.removeAll { item in
                itemsToDelete.contains(where: { $0.id == item.id }) &&
                !FileManager.default.fileExists(atPath: item.url.path)
            }

            // If app bundle was deleted, remove from installedApps
            if let current = self.selectedApp, !FileManager.default.fileExists(atPath: current.url.path) {
                self.installedApps.removeAll { $0.id == current.id }
                self.markedAppIDs.remove(current.id)
                self.selectedApp = nil
                self.leftovers = []
            }
        }
    }

    // MARK: - Multi-App / Batch Actions

    public func toggleAppMarked(id: String) {
        guard let app = installedApps.first(where: { $0.id == id }), !app.isSystemApp else {
            return // Never mark system apps for batch deletion
        }

        if markedAppIDs.contains(id) {
            markedAppIDs.remove(id)
            if markedAppIDs.count == 1, let remainingID = markedAppIDs.first,
               let remainingApp = installedApps.first(where: { $0.id == remainingID }) {
                selectApp(remainingApp)
            } else if markedAppIDs.isEmpty {
                clearSelection()
            }
        } else {
            markedAppIDs.insert(id)
            loadBatchLeftovers(for: id)

            // When marking a single app, definitely focus onto it!
            if markedAppIDs.count == 1 {
                selectApp(app)
            }
        }
    }

    // MARK: - Batch Leftovers Granular Management

    public func toggleBatchItemSelection(appID: String, itemID: UUID) {
        guard var items = batchLeftovers[appID],
              let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].isSelected.toggle()
        batchLeftovers[appID] = items
    }

    public func toggleBatchCategory(appID: String, category: LeftoverCategory, isSelected: Bool) {
        guard var items = batchLeftovers[appID] else { return }
        for idx in items.indices where items[idx].category == category {
            items[idx].isSelected = isSelected
        }
        batchLeftovers[appID] = items
    }

    public func setAllBatchItemsSelected(appID: String, isSelected: Bool) {
        guard var items = batchLeftovers[appID] else { return }
        for idx in items.indices {
            items[idx].isSelected = isSelected
        }
        batchLeftovers[appID] = items
    }

    public func batchCategories(for appID: String) -> [LeftoverCategory] {
        guard let items = batchLeftovers[appID] else { return [] }
        let set = Set(items.map { $0.category })
        return LeftoverCategory.allCases.filter { set.contains($0) }
    }

    public func batchItems(for appID: String, category: LeftoverCategory) -> [LeftoverItem] {
        batchLeftovers[appID]?.filter { $0.category == category } ?? []
    }

    public func loadBatchLeftovers(for appID: String) {
        guard let app = installedApps.first(where: { $0.id == appID }),
              batchLeftovers[appID] == nil else { return }

        Task {
            let items = await LeftoverScanner.shared.scanLeftovers(for: app)
            self.batchLeftovers[appID] = items
        }
    }

    public func selectAllMarked() {
        let nonSystemIDs = filteredApps.filter { !$0.isSystemApp }.map { $0.id }
        markedAppIDs = Set(nonSystemIDs)
        for id in markedAppIDs {
            loadBatchLeftovers(for: id)
        }
    }

    public func deselectAllMarked() {
        markedAppIDs.removeAll()
    }

    public func requestBatchDelete() {
        guard !markedApps.isEmpty, !isAnalyzingBatchLeftovers else { return }
        showBatchDeleteConfirmation = true
    }

    public func executeBatchDelete() {
        guard !isBatchDeleting, !markedApps.isEmpty else { return }
        isBatchDeleting = true

        Task {
            var allItemsToDelete: [LeftoverItem] = []
            for app in self.markedApps {
                let items: [LeftoverItem]
                if let existing = self.batchLeftovers[app.id] {
                    items = existing
                } else {
                    // Safe Fallback: Await deep leftover scan so caches/preferences are NEVER missed!
                    items = await LeftoverScanner.shared.scanLeftovers(for: app)
                    self.batchLeftovers[app.id] = items
                }
                allItemsToDelete.append(contentsOf: items.filter { $0.isSelected })
            }

            let deletingAppIDs = self.markedAppIDs

            let result = await Task.detached(priority: .userInitiated) {
                TrashService.shared.trashItems(allItemsToDelete)
            }.value

            self.isBatchDeleting = false
            self.batchTrashResult = result
            self.showBatchResultAlert = true

            // Remove successfully deleted apps from installed list
            self.installedApps.removeAll { app in
                deletingAppIDs.contains(app.id) &&
                !FileManager.default.fileExists(atPath: app.url.path)
            }
            self.markedAppIDs.removeAll()
            self.batchLeftovers.removeAll()

            if let selected = self.selectedApp, !FileManager.default.fileExists(atPath: selected.url.path) {
                self.selectedApp = nil
                self.leftovers = []
            }
        }
    }
}
