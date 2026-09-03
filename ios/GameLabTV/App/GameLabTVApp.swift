import SwiftUI

@main
struct GameLabTVApp: App {
    var body: some Scene {
        WindowGroup {
            RootTVView()
                .onAppear {
                    GameSocketManager.shared.connect(to: AppConstants.serverURL)
                }
        }
    }
}
