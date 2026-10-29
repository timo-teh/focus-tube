import SwiftUI

/// Barre de contrôle de Focus Tube, en niveaux de gris. Remplace entièrement celle de YouTube.
/// Lecture/pause, position, temps, volume, vitesse (plafonnée) et plein écran.
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

    // MARK: - Liaisons

    private var progressBinding: Binding<Double> {
        Binding(
            get: { viewModel.displayedTime },
            set: { viewModel.sliderValueChanged($0) }
        )
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { viewModel.isMuted ? 0 : viewModel.volume },
            set: { viewModel.setVolume($0) }
        )
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
