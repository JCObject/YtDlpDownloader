import SwiftUI

@main
struct YtDlpDownloaderMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1180, height: 820)
        .windowResizability(.contentMinSize)
    }
}
