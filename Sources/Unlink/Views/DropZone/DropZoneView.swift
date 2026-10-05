import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct DropZoneView: View {
    @Bindable var viewModel: UnlinkViewModel
    @State private var isTargeted: Bool = false

    public init(viewModel: UnlinkViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                // Background halo
                Circle()
                    .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.03))
                    .frame(width: 180, height: 180)
                    .blur(radius: 20)

                // Outer border circle
                Circle()
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(isTargeted ? 1.08 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isTargeted)

                // Icon
                if isTargeted {
                    Image(systemName: "arrow.down.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.bounce, value: isTargeted)
                } else if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
                          let nsImage = NSImage(contentsOf: iconURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                } else {
                    Image(systemName: "shippingbox.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(Color.secondary)
                }
            }

            VStack(spacing: 8) {
                Text("Drop Application to Uninstall")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Drag any .app bundle from Finder to detect and remove all leftover caches, preferences, and container files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 12) {
                Button {
                    openFilePicker()
                } label: {
                    Label("Browse Application...", systemImage: "folder.badge.plus")
                        .font(.body)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top, 4)

            Spacer()

            // Subtle instruction footer
            HStack(spacing: 16) {
                Label("Scans ~/Library", systemImage: "magnifyingglass")
                Label("Safe Trash Deletion", systemImage: "trash")
                Label("100% Free & Open", systemImage: "checkmark.seal")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async {
                    viewModel.handleDroppedURL(url)
                }
            }
            return true
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.prompt = "Select App"
        panel.message = "Choose an application (.app) to analyze associated files"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            viewModel.handleDroppedURL(selectedURL)
        }
    }
}
