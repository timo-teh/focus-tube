import SwiftUI

/// Barre de contrôle de Focus Tube, en niveaux de gris. Remplace entièrement celle de YouTube.
/// Lecture/pause, position, temps, volume, sous-titres, langue audio, vitesse (plafonnée), plein écran.
struct PlayerControlBar: View {
    @ObservedObject var viewModel: PlayerViewModel
    let isFullScreen: Bool
    let toggleFullScreen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            controlButton(viewModel.isPlaying ? "pause.fill" : "play.fill",
                          help: viewModel.isPlaying ? "Pause (Espace)" : "Lecture (Espace)") {
                viewModel.togglePlayPause()
            }

            Text(PlayerViewModel.format(viewModel.displayedTime))
                .font(.caption.monospacedDigit())
                .foregroundColor(Theme.textSecondary)
                .frame(width: 56, alignment: .trailing)

            Slider(value: progressBinding,
                   in: 0...max(viewModel.duration, 1),
                   onEditingChanged: viewModel.sliderEditingChanged)
                .controlSize(.small)
                .help("Position (← → : ±10 s)")

            Text(PlayerViewModel.format(viewModel.duration))
                .font(.caption.monospacedDigit())
                .foregroundColor(Theme.textSecondary)
                .frame(width: 56, alignment: .leading)

            controlButton(volumeIcon, help: viewModel.isMuted ? "Réactiver le son" : "Couper le son") {
                viewModel.toggleMute()
            }

            Slider(value: volumeBinding, in: 0...100)
                .controlSize(.small)
                .frame(width: 80)
                .help("Volume")

            captionsMenu
            audioMenu

            Picker("", selection: rateBinding) {
                ForEach(AppConfig.allowedPlaybackRates, id: \.self) { rate in
                    Text("\(rate.formatted())×").tag(rate)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 78)
            .help("Vitesse (maximum \(AppConfig.maxPlaybackRate.formatted())×)")

            controlButton(isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                          help: isFullScreen ? "Quitter le plein écran (F)" : "Plein écran (F)") {
                toggleFullScreen()
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.09))
        .disabled(!viewModel.isReady)
    }

    // MARK: - Sous-titres

    /// Menu « Sous-titres » : désactivés ou l'une des pistes proposées par YouTube (clic simple = bascule : touche C).
    private var captionsMenu: some View {
        Menu {
            if viewModel.captionTracks.isEmpty {
                Text("Aucun sous-titre disponible pour cette vidéo")
            } else {
                Picker("Sous-titres", selection: captionsBinding) {
                    Text("Désactivés").tag("")
                    ForEach(viewModel.captionTracks) { track in
                        Text(track.name).tag(track.code)
                    }
                }
                .pickerStyle(.inline)
            }
        } label: {
            Image(systemName: viewModel.captionsEnabled ? "captions.bubble.fill" : "captions.bubble")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 26, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(viewModel.captionsEnabled ? "Sous-titres activés (C)" : "Sous-titres désactivés (C)")
    }

    // MARK: - Audio

    /// Menu « Audio » : automatique ou une langue de `LanguagesConfig.audioLanguages`.
    /// YouTube joue le doublage correspondant s'il existe, sinon la piste originale.
    private var audioMenu: some View {
        Menu {
            Picker("Langue audio", selection: audioBinding) {
                Text("Automatique").tag("")
                ForEach(LanguagesConfig.audioLanguages, id: \.code) { language in
                    Text(language.name).tag(language.code)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Text("Doublage joué s'il existe pour la vidéo, sinon piste originale")
        } label: {
            Image(systemName: viewModel.audioLanguage == nil ? "waveform" : "waveform.badge.magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 26, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Langue audio (si disponible)")
    }

    // MARK: - Liaisons

    private var progressBinding: Binding<Double> {
        Binding(get: { viewModel.displayedTime }, set: { viewModel.sliderValueChanged($0) })
    }

    private var volumeBinding: Binding<Double> {
        Binding(get: { viewModel.isMuted ? 0 : viewModel.volume }, set: { viewModel.setVolume($0) })
    }

    private var rateBinding: Binding<Double> {
        Binding(
            get: {
                let current = viewModel.playbackRate
                return AppConfig.allowedPlaybackRates.min { abs($0 - current) < abs($1 - current) } ?? 1.0
            },
            set: { viewModel.setPlaybackRate($0) }
        )
    }

    private var captionsBinding: Binding<String> {
        Binding(get: { viewModel.captionSelection }, set: { viewModel.selectCaptions($0) })
    }

    private var audioBinding: Binding<String> {
        Binding(get: { viewModel.audioSelection }, set: { viewModel.selectAudioLanguage($0) })
    }

    private var volumeIcon: String {
        if viewModel.isMuted || viewModel.volume == 0 { return "speaker.slash.fill" }
        if viewModel.volume < 50 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    // MARK: - Composants

    private func controlButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
