import SwiftUI

/// Premier lancement : saisie de la clé YouTube Data API.
/// La clé est testée (1 unité) puis enregistrée dans le Trousseau.
struct APIKeySetupView: View {
    @EnvironmentObject private var app: AppViewModel

    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()

            Text("Focus Tube")
                .font(.system(size: 34, weight: .semibold))

            Text("Un client YouTube sans recommandations, sans Shorts et sans divertissement. "
                 + "Pour commencer, l'application a besoin de votre propre clé YouTube Data API v3.")
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Comment obtenir une clé")
                    .font(.headline)
                Text("1. Ouvrez la Google Cloud Console et créez un projet.\n"
                     + "2. Dans « API et services » › « Bibliothèque », activez YouTube Data API v3.\n"
                     + "3. Dans « Identifiants », créez une clé API et collez-la ci-dessous.\n"
                     + "Le guide détaillé se trouve dans le README du projet.")
                    .font(.callout)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Ouvrir la Google Cloud Console", destination: URL(string: "https://console.cloud.google.com/apis/library/youtube.googleapis.com")!)
                    .font(.callout)
                    .foregroundColor(Theme.textPrimary)
                    .underline()
            }

            SecureField("Clé API YouTube Data v3", text: $apiKey)
                .monoField()
                .onSubmit { submit() }
                .disabled(isValidating)

            HStack(spacing: 12) {
                Button(action: submit) {
                    HStack(spacing: 8) {
                        if isValidating {
                            ProgressView().controlSize(.small)
                        }
                        Text(isValidating ? "Vérification…" : "Enregistrer la clé")
                    }
                }
                .buttonStyle(MonoButtonStyle(prominent: true))
                .disabled(isValidating || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)

                Text("Stockée uniquement dans le Trousseau macOS.")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundColor(Theme.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .cornerRadius(6)
            }

            Spacer()
            Spacer()
        }
        .padding(48)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submit() {
        guard !isValidating else { return }
        isValidating = true
        errorMessage = nil
        Task {
            do {
                try await app.validateAndSave(apiKey: apiKey)
            } catch {
                errorMessage = error.localizedDescription
            }
            isValidating = false
        }
    }
}
