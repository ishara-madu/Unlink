import SwiftUI

public enum LeftoverCategory: String, CaseIterable, Identifiable, Sendable {
    case appBundle = "Application"
    case applicationSupport = "Application Support"
    case preferences = "Preferences"
    case caches = "Caches"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case savedState = "Saved State"
    case logs = "Logs & Diagnostics"
    case httpStorages = "Web & HTTP Storages"
    case launchAgents = "Launch Agents"
    case other = "Other Associated Files"

    public var id: String { rawValue }

    public var displayName: String { rawValue }

    public var iconName: String {
        switch self {
        case .appBundle:
            return "app.dashed"
        case .applicationSupport:
            return "folder.badge.gearshape"
        case .preferences:
            return "slider.horizontal.3"
        case .caches:
            return "bolt.horizontal.fill"
        case .containers:
            return "cube.fill"
        case .groupContainers:
            return "square.stack.3d.down.right.fill"
        case .savedState:
            return "clock.arrow.circlepath"
        case .logs:
            return "doc.text.magnifyingglass"
        case .httpStorages:
            return "network"
        case .launchAgents:
            return "play.circle.fill"
        case .other:
            return "doc.fill"
        }
    }

    public var tintColor: Color {
        switch self {
        case .appBundle:
            return .blue
        case .applicationSupport:
            return .indigo
        case .preferences:
            return .orange
        case .caches:
            return .yellow
        case .containers:
            return .purple
        case .groupContainers:
            return .pink
        case .savedState:
            return .teal
        case .logs:
            return .gray
        case .httpStorages:
            return .cyan
        case .launchAgents:
            return .red
        case .other:
            return .secondary
        }
    }
}
