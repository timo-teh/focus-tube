import Foundation

/// Constantes de configuration de l'application.
/// Tout ce qui est « réglable » sans toucher à la logique se trouve ici.
enum AppConfig {

    // MARK: - Filtrage

    /// Durée maximale (en secondes) considérée comme un Short.
    /// Toute vidéo de cette durée ou moins est exclue (3 minutes = 180 s).
    static let shortsMaxDurationSeconds = 180

    /// Marqueurs textuels qui signalent un Short dans le titre ou la description.
    /// La comparaison est insensible à la casse.
    static let shortsMarkers: [String] = ["#shorts"]

    // MARK: - Lecteur

    /// Vitesse de lecture maximale autorisée.
    static let maxPlaybackRate: Double = 1.5

    /// Vitesses proposées dans l'interface.
    static let allowedPlaybackRates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5]

    // MARK: - API YouTube

    /// Nombre de résultats demandés à search.list (maximum 50).
    /// Le coût est de 100 unités quel que soit ce nombre : autant en demander 50.
    static let maxSearchResults = 50

    /// Quota quotidien par défaut d'un projet Google Cloud.
    static let dailyQuota = 10_000

    /// Coût d'un appel search.list.
    static let searchCost = 100

    /// Coût d'un appel videos.list.
    static let videosListCost = 1

    // MARK: - Cache

    /// Durée de validité d'un résultat de recherche en cache (24 h).
    static let cacheTTL: TimeInterval = 24 * 60 * 60

    /// Nombre maximal de recherches conservées sur disque.
    static let cacheMaxEntries = 200
}
