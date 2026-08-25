import SwiftUI

@main
@MainActor
struct SMBPlayerApp: App {
    @StateObject private var serverStore = SMBServerStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(serverStore)
                .tint(.accentColor)
        }
    }
}
