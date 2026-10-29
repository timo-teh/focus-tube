import AppKit

/// Délégué AppKit minimal.
/// Nécessaire pour que l'app se comporte comme une vraie application
/// (icône dans le Dock, fenêtre au premier plan) même lorsqu'elle est lancée
/// depuis Xcode en tant qu'exécutable Swift Package.
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apparence sombre forcée : l'interface est pensée en niveaux de gris.
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
