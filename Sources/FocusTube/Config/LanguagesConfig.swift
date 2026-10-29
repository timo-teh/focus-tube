import Foundation

/// Réglages des sous-titres et de la langue audio. Modifiables sans toucher au reste du code.
enum LanguagesConfig {
    /// Sous-titres affichés dès le lancement d'une vidéo (quand il en existe).
    static let captionsOnByDefault = false

    /// Langue de sous-titres préférée (code ISO 639-1, ex. "fr", "en"), ou nil pour laisser YouTube choisir.
    static let preferredCaptionLanguage: String? = nil

    /// Langues proposées dans le menu « Audio ». YouTube choisit le doublage correspondant
    /// lorsque le créateur en a fourni un ; sinon la piste originale est jouée.
    static let audioLanguages: [(code: String, name: String)] = [
        ("fr", "Français"),
        ("en", "English"),
        ("es", "Español"),
        ("de", "Deutsch"),
        ("it", "Italiano"),
        ("pt", "Português"),
        ("ja", "日本語"),
        ("ar", "العربية")
    ]
}
