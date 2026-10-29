import Foundation

/// Modèle d'une vidéo telle qu'affichée dans l'application.
/// Volontairement dépouillé : pas de vues, pas de likes, pas de date mise en avant.
struct Video: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let channelTitle: String
    let description: String
    let thumbnailURL: URL?
    let durationSeconds: Int
    let categoryId: String

    /// Durée formatée « 12:34 » ou « 1:05:20 ».
    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Nom lisible de la catégorie.
    var categoryName: String {
        AllowedCategories.name(for: categoryId)
    }
}

extension Video {
    /// Construit une `Video` à partir d'un élément renvoyé par videos.list.
    /// Retourne `nil` si la durée est illisible.
    init?(item: VideoListItem) {
        guard let seconds = ISO8601Duration.seconds(from: item.contentDetails.duration) else {
            return nil
        }
        let thumbs = item.snippet.thumbnails ?? [:]
        let thumbString = thumbs["medium"]?.url ?? thumbs["high"]?.url ?? thumbs["default"]?.url

        self.id = item.id
        self.title = item.snippet.title
        self.channelTitle = item.snippet.channelTitle
        self.description = item.snippet.description
        self.thumbnailURL = thumbString.flatMap(URL.init(string:))
        self.durationSeconds = seconds
        self.categoryId = item.snippet.categoryId ?? ""
    }
}
