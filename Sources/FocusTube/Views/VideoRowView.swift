import SwiftUI

/// Ligne de résultat : miniature en niveaux de gris, titre, chaîne, durée.
/// Pas de vues, pas de likes, pas de date, pas de badge.
struct VideoRowView: View {
    let video: Video
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                thumbnail
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(video.channelTitle)
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(video.formattedDuration) · \(video.categoryName)")
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(isHovered ? Theme.surface : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    /// Miniature forcée en niveaux de gris (règle n° 6).
    private var thumbnail: some View {
        ZStack {
            Theme.surface
            if let url = video.thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color.clear
                    }
                }
            }
        }
        .frame(width: 168, height: 94)
        .clipped()
        .cornerRadius(4)
        .saturation(0)
    }
}
