import Foundation

extension SearchViewModel {
    /// Expose le suivi du quota à la vue, sans dupliquer l'état.
    var quotaForDisplay: QuotaTracker { quotaTracker }
}
