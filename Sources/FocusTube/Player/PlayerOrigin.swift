import Foundation

/// Origine (schéma + hôte) qui sert d'« identité » à Focus Tube auprès du lecteur YouTube.
///
/// Depuis 2025, YouTube exige que toute page qui intègre son lecteur envoie un en-tête HTTP
/// `Referer` en https identifiant le site ou l'application hôte. À défaut, le lecteur refuse de
/// jouer et affiche l'erreur 152 (« This video is not available ») ou 153
/// (« Video player configuration error »).
///
/// Pour une application native, la pratique reprise par plusieurs SDK consiste à utiliser
/// l'identifiant de bundle comme nom d'hôte. Cette URL ne pointe vers aucun serveur : elle sert
/// uniquement de base au document HTML chargé dans la WKWebView, ce qui fixe à la fois le
/// `Referer` envoyé à YouTube et la valeur de `window.location.origin` (transmise au paramètre
/// `origin` du lecteur). Aucune requête n'est envoyée vers cet hôte.
enum PlayerOrigin {
    /// Doit rester identique à `CFBundleIdentifier` dans Resources/Info.plist.
    static let host = "com.focustube.app"
    static let url = URL(string: "https://\(host)")!
}
