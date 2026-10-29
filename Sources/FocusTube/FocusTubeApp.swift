import SwiftUI

/// Point d'entrée de l'application.
/// Une seule fenêtre, pas de menu « Nouvelle fenêtre », pas de notifications.
@main
struct FocusTubeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("Focus Tube") {
            RootView()
                .environmentObject(appViewModel)
        }
        .defaultSize(width: 1000, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            // Supprime « Nouvelle fenêtre » : une seule fenêtre, un seul sujet à la fois.
            CommandGroup(replacing: .newItem) { }
            // Pas de menu Aide (tout est dans le README).
            CommandGroup(replacing: .help) { }
        }
    }
}
