import SwiftUI

@main
@MainActor
struct SMBPlayerApp: App {
    @StateObject private var serverStore = SMBServerStore()

    init() {
        AppLogger.shared.log("App did launch")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(serverStore)
                .tint(.accentColor)
        }
    }
}
