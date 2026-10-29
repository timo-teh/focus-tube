import SwiftUI

/// Aiguillage entre les trois écrans. Applique le thème global.
struct RootView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        Group {
            switch app.screen {
            case .setup:
                APIKeySetupView()
            case .search:
                SearchView(viewModel: app.searchViewModel)
            case .player(let video):
                // `.id` garantit un lecteur neuf à chaque vidéo.
                PlayerView(video: video)
                    .id(video.id)
            }
        }
        .frame(minWidth: 820, minHeight: 580)
        .background(Theme.background)
        .foregroundColor(Theme.textPrimary)
        .preferredColorScheme(.dark)
        .tint(Color(white: 0.7))
    }
}
