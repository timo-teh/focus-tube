import Foundation
import Combine

/// ViewModel du lecteur.
/// Reçoit les événements du lecteur IFrame (via JavaScript) et lui envoie des commandes.
@MainActor
final class PlayerViewModel: ObservableObject {

    enum PlaybackState: Equatable {
        case loading
        case playing
        case paused
        case buffering
        case ended
        case error(String)
    }

    let video: Video

    @Published private(set) var state: PlaybackState = .loading
    @Published private(set) var playbackRate: Double = 1.0
    @Published private(set) var showPauseOverlay = false

    /// Exécute du JavaScript dans la WKWebView. Injecté par `YouTubePlayerWebView`.
    var jsExecutor: ((String) -> Void)?

    private var pauseOverlayTask: Task<Void, Never>?

    init(video: Video) {
        self.video = video
    }

    // MARK: - Événements venant du JavaScript

    /// Message reçu du lecteur : `{ event: String, data: Any? }`.
    func handle(message: [String: Any]) {
        guard let event = message["event"] as? String else { return }

        switch event {
        case "ready":
            state = .buffering

        case "stateChange":
            guard let code = message["data"] as? Int else { return }
            updateState(fromYouTubeCode: code)

        case "rateChange":
            guard let rate = message["data"] as? Double else { return }
            enforceRateLimit(rate)

        case "error":
            let code = message["data"] as? Int ?? -1
            state = .error(errorMessage(forCode: code))

        default:
            break
        }
    }

    /// Codes de l'IFrame API : -1 non démarré, 0 terminé, 1 lecture, 2 pause, 3 chargement, 5 en file.
    private func updateState(fromYouTubeCode code: Int) {
        switch code {
        case 0: state = .ended
        case 1: state = .playing
        case 2: state = .paused
        case 3: state = .buffering
        default: state = .loading
        }
        schedulePauseOverlay()
    }

    /// Affiche la surcouche de pause avec un léger délai, pour éviter un clignotement
    /// lors d'un simple déplacement dans la barre de progression.
    private func schedulePauseOverlay() {
        pauseOverlayTask?.cancel()
        guard state == .paused else {
            showPauseOverlay = false
            return
        }
        pauseOverlayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled, let self, self.state == .paused else { return }
            self.showPauseOverlay = true
        }
    }

    /// Règle n° 5 : jamais au-dessus de 1,5×.
    private func enforceRateLimit(_ rate: Double) {
        if rate > AppConfig.maxPlaybackRate {
            jsExecutor?("ftSetRate(\(AppConfig.maxPlaybackRate));")
            playbackRate = AppConfig.maxPlaybackRate
        } else {
            playbackRate = rate
        }
    }

    private func errorMessage(forCode code: Int) -> String {
        switch code {
        case 2: return "Identifiant de vidéo invalide."
        case 5: return "Le lecteur HTML5 a rencontré une erreur."
        case 100: return "Cette vidéo est introuvable ou privée."
        case 101, 150: return "L'auteur n'autorise pas la lecture de cette vidéo en dehors de YouTube."
        default: return "Erreur de lecture (code \(code))."
        }
    }

    // MARK: - Commandes vers le lecteur

    func play() {
        jsExecutor?("ftPlay();")
    }

    func pause() {
        jsExecutor?("ftPause();")
    }

    func setPlaybackRate(_ rate: Double) {
        let clamped = min(rate, AppConfig.maxPlaybackRate)
        guard clamped != playbackRate else { return }
        playbackRate = clamped
        jsExecutor?("ftSetRate(\(clamped));")
    }
}
