import SwiftUI

/// Palette en niveaux de gris. Aucune couleur saturée dans l'interface :
/// seule la vidéo en lecture est en couleur.
enum Theme {
    static let background = Color(white: 0.09)
    static let surface = Color(white: 0.15)
    static let surfaceHover = Color(white: 0.20)
    static let border = Color(white: 0.28)
    static let textPrimary = Color(white: 0.93)
    static let textSecondary = Color(white: 0.62)
    static let textTertiary = Color(white: 0.45)
}

/// Bouton monochrome. `prominent` inverse les tons pour l'action principale.
struct MonoButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(prominent ? Theme.textPrimary : Theme.surface)
            .foregroundColor(prominent ? Theme.background : Theme.textPrimary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Theme.border, lineWidth: prominent ? 0 : 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// Champ de texte sobre, sans bordure système.
struct MonoFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.title3)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func monoField() -> some View {
        modifier(MonoFieldModifier())
    }
}
