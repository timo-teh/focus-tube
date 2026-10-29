import Foundation
import Combine

/// ViewModel du lecteur.
/// Reçoit les événements du lecteur IFrame (via JavaScript) et lui envoie des commandes.
/// C'est lui, et non le lecteur YouTube, qui alimente la barre de contrôle de l'application.
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
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double
    @Published private(set) var volume: Double = 100
    @Published private(set) var isMuted = false
    @Published private(set) var isScrubbing = false
    /// Position visée pendant que l'utilisateur déplace le curseur.
    @Published var scrubTime: Double = 0

    /// Exécute du JavaScript dans la WKWebView. Injecté par `YouTubePlayerWebView`.
    var jsExecutor: ((String) -> Void)?

    private var pauseOverlayTask: Task<Void, Never>?

    init(video: Video) {
        self.video = video
        self.duration = Double(video.durationSeconds)
    }

    // MARK: - État dérivé

    var isPlaying: Bool { state == .playing || state == .buffering }

    var isReady: Bool {
        switch state {
        case .loading, .error: return false
        default: return true
        }
    }

    /// Temps affiché : la position visée pendant un déplacement, sinon la position réelle.
    var displayedTime: Double { isScrubbing ? scrubTime : currentTime }

    // MARK: - Événements venant du JavaScript

    /// Message reçu du lecteur : `{ event: String, data: Any? }`.
    func handle(message: [String: Any]) {
        guard let event = message["event"] as? String else { return }

        switch event {
        case "ready":
            state = .buffering
            if let data = message["data"] as? [String: Any],
               let seconds = data["duration"] as? Double, seconds > 0 {
                duration = seconds
            }

        case "stateChange":
            guard let code = message["data"] as? Int else { return }
            updateState(fromYouTubeCode: code)

        case "time":
            guard let data = message["data"] as? [String: Any] else { return }
            if let seconds = data["duration"] as? Double, seconds > 0 {
                duration = seconds
            }
            if let current = data["current"] as? Double, !isScrubbing {
                currentTime = min(max(current, 0), duration > 0 ? duration : current)
            }

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
        case 0:
            state = .ended
            if duration > 0 { currentTime = duration }
        case 1: state = .playing
        case 2: state = .paused
        case 3: state = .buffering
        default: state = .loading
        }
        schedulePauseOverlay()
    }

    /// Surcouche de pause avec un léger délai (évite un clignotement lors d'un simple déplacement).
    private func schedulePauseOverlay() {
        pauseOverlayTask?.cancel()
        guard state == .paused else {
            showPauseOverlay = false
            return
        }
        pauseOverlayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
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
        case 152, 153:
            return "YouTube n'a pas pu identifier l'application (code 152/153). Relancez Focus Tube ; si le problème persiste, installez la dernière version."
        default: return "Erreur de lecture (code \(code))."
        }
    }

    // MARK: - Commandes vers le lecteur (API officielle uniquement)

    func play() {
        jsExecutor?("ftPlay();")
    }

    func pause() {
        jsExecutor?("ftPause();")
    }

    func togglePlayPause() {
        switch state {
        case .playing, .buffering: pause()
        case .paused: play()
        case .ended: replay()
        default: break
        }
    }

    func replay() {
        seek(to: 0)
        play()
    }

    func seek(to seconds: Double) {
        let upper = duration > 0 ? duration : Double.greatestFiniteMagnitude
        let target = min(max(seconds, 0), upper)
        currentTime = target
        jsExecutor?("ftSeek(\(target));")
    }

    func seek(by delta: Double) {
        seek(to: displayedTime + delta)
    }

    /// Appelé par le curseur de progression : début (true) et fin (false) du déplacement.
    func sliderEditingChanged(_ editing: Bool) {
        if editing {
            scrubTime = currentTime
            isScrubbing = true
        } else {
            isScrubbing = false
            seek(to: scrubTime)
        }
    }

    /// Nouvelle valeur du curseur (déplacement en cours ou touche clavier sur le curseur).
    func sliderValueChanged(_ seconds: Double) {
        scrubTime = seconds
        if !isScrubbing {
            seek(to: seconds)
        }
    }

    func setPlaybackRate(_ rate: Double) {
        let clamped = min(rate, AppConfig.maxPlaybackRate)
        guard clamped != playbackRate else { return }
        playbackRate = clamped
        jsExecutor?("ftSetRate(\(clamped));")
    }

    func setVolume(_ value: Double) {
        let clamped = min(max(value, 0), 100)
        volume = clamped
        jsExecutor?("ftSetVolume(\(Int(clamped)));")
        if clamped > 0, isMuted {
            isMuted = false
            jsExecutor?("ftUnmute();")
        }
    }

    func toggleMute() {
        isMuted.toggle()
        jsExecutor?(isMuted ? "ftMute();" : "ftUnmute();")
    }

    // MARK: - Formatage

    /// « 12:34 » ou « 1:05:20 ».
    static func format(_ seconds: Double) -> String {
        let total = max(Int(seconds.rounded(.down)), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
