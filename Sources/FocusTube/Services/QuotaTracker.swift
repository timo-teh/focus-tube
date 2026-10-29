import Foundation
import Combine

/// Estimation locale de la consommation du quota YouTube.
/// Google ne fournit pas le compteur en temps réel : on additionne les coûts connus
/// (100 par recherche, 1 par videos.list) et on remet à zéro à minuit, heure du Pacifique,
/// comme le fait Google.
@MainActor
final class QuotaTracker: ObservableObject {

    @Published private(set) var usedToday: Int = 0

    private let defaults = UserDefaults.standard
    private let dayKey = "quota.day"
    private let usedKey = "quota.used"

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    init() {
        refresh()
    }

    private var todayKey: String {
        dayFormatter.string(from: Date())
    }

    /// Remet le compteur à zéro si le jour (Pacifique) a changé.
    func refresh() {
        if defaults.string(forKey: dayKey) != todayKey {
            defaults.set(todayKey, forKey: dayKey)
            defaults.set(0, forKey: usedKey)
        }
        usedToday = defaults.integer(forKey: usedKey)
    }

    /// Enregistre une dépense d'unités.
    func record(_ units: Int) {
        refresh()
        usedToday += units
        defaults.set(usedToday, forKey: usedKey)
    }

    var remaining: Int {
        max(0, AppConfig.dailyQuota - usedToday)
    }

    /// Nombre de recherches restantes (chaque recherche coûte search + videos.list).
    var searchesRemaining: Int {
        remaining / (AppConfig.searchCost + AppConfig.videosListCost)
    }
}
