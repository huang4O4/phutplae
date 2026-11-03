import SwiftUI

@main
struct PhutPlaeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var settings: UserSettings
    @StateObject private var appState: AppState

    init() {
        let settings = UserSettings()
        _settings = StateObject(wrappedValue: settings)
        _appState = StateObject(wrappedValue: AppState(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ListenView()
                .environmentObject(appState)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    appState.handleScenePhase(phase)
                }
        }
    }
}
