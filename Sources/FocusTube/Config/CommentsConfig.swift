import Foundation

/// Réglages des commentaires. Modifiables sans toucher au reste du code.
enum CommentsConfig {
    /// Tri des commentaires : "relevance" (jugés les plus utiles) ou "time" (les plus récents).
    static let order = "relevance"

    /// Nombre de commentaires chargés par page (1 à 100).
    static let pageSize = 20

    /// Coût en unités de quota d'un appel commentThreads.list ou comments.list.
    static let listCost = 1
}
