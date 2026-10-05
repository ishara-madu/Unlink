import SwiftUI

@main
struct UnlinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .frame(minWidth: 760, minHeight: 480)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 880, height: 560)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
