import SwiftUI

@main
@MainActor
struct BikeBikeApp: App {
    @StateObject private var container = AppDependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
        }
    }
}
