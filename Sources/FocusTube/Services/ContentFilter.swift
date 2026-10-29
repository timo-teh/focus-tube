import Foundation

/// Règles d'exclusion du divertissement et des Shorts.
/// Une vidéo est gardée uniquement si elle passe les trois tests.
enum ContentFilter {

    static func isAllowed(_ video: Video) -> Bool {
        isAllowedCategory(video) && isNotShort(video) && hasNoShortsMarker(video)
    }

    /// 1. La catégorie doit figurer dans `AllowedCategories.ids`.
    static func isAllowedCategory(_ video: Video) -> Bool {
        AllowedCategories.ids.contains(video.categoryId)
    }

    /// 2. Durée strictement supérieure à 3 minutes.
    ///    Les directs (durée « P0D » = 0 s) sont donc exclus aussi.
    static func isNotShort(_ video: Video) -> Bool {
        video.durationSeconds > AppConfig.shortsMaxDurationSeconds
    }

    /// 3. Ni le titre ni la description ne contiennent « #shorts ».
    static func hasNoShortsMarker(_ video: Video) -> Bool {
        let haystack = (video.title + " " + video.description).lowercased()
        return !AppConfig.shortsMarkers.contains { haystack.contains($0.lowercased()) }
    }
}
