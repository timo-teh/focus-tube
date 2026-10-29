import SwiftUI

/// Commentaires sous la vidéo : auteur, ancienneté, texte, réponses. Aucun compteur.
struct CommentsSection: View {
    @ObservedObject var viewModel: CommentsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider().overlay(Theme.border)

            Text("Commentaires")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            content
        }
        .frame(maxWidth: 1100, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .idle, .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Chargement des commentaires…")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }

        case .failed(let message):
            Text(message)
                .font(.callout)
                .foregroundColor(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

        case .loaded:
            if viewModel.threads.isEmpty {
                Text("Aucun commentaire.")
                    .font(.callout)
                    .foregroundColor(Theme.textTertiary)
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.threads) { thread in
                        CommentThreadRow(
                            thread: thread,
                            isExpanded: viewModel.expandedThreads.contains(thread.id),
                            isLoadingReplies: viewModel.threadsLoadingReplies.contains(thread.id)
                        ) {
                            Task { await viewModel.toggleReplies(for: thread) }
                        }
                    }
                }

                if viewModel.nextPageToken != nil {
                    Button(viewModel.isLoadingMore ? "Chargement…" : "Charger la suite") {
                        Task { await viewModel.loadMore() }
                    }
                    .buttonStyle(MonoButtonStyle())
                    .disabled(viewModel.isLoadingMore)
                    .padding(.top, 4)
                }
            }
        }
    }
}

/// Un commentaire de premier niveau et, repliées par défaut, ses réponses.
struct CommentThreadRow: View {
    let thread: CommentThread
    let isExpanded: Bool
    let isLoadingReplies: Bool
    let onToggleReplies: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CommentBody(comment: thread.comment)

            if thread.hasReplies {
                Button(action: onToggleReplies) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        Text(isExpanded ? "Masquer les réponses" : "Afficher les réponses")
                    }
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(thread.replies) { reply in
                            CommentBody(comment: reply)
                        }
                        if isLoadingReplies {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .padding(.leading, 18)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Theme.border).frame(width: 1)
                    }
                }
            }
        }
    }
}

struct CommentBody: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(comment.author)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.textSecondary)
                if let date = comment.publishedAt {
                    Text(CommentDates.relative(date))
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                }
            }
            Text(comment.text)
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
