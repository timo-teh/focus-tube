import Foundation

/// Liste des catégories YouTube autorisées.
///
/// C'EST ICI QU'ON MODIFIE LE FILTRE.
/// Ajoutez ou retirez un identifiant dans `ids` pour changer ce que l'app accepte.
/// Toute vidéo dont `categoryId` n'est pas dans cette liste est exclue des résultats.
///
/// Référence des catégories YouTube (identifiants officiels de l'API Data v3) :
///
///  Autorisées par défaut
///   2  — Autos & Vehicles
///  19  — Travel & Events
///  25  — News & Politics
///  26  — Howto & Style
///  27  — Education
///  28  — Science & Technology
///  29  — Nonprofits & Activism
///
///  Exclues par défaut (divertissement)
///   1  — Film & Animation
///  10  — Music
///  15  — Pets & Animals
///  17  — Sports
///  20  — Gaming
///  22  — People & Blogs
///  23  — Comedy
///  24  — Entertainment
///  30 à 44 — Movies, Anime, Action/Adventure, Classics, Comedy, Documentary,
///            Drama, Family, Foreign, Horror, Sci-Fi/Fantasy, Thriller, Shorts,
///            Shows, Trailers
enum AllowedCategories {

    /// Identifiants de catégories acceptés.
    static let ids: Set<String> = [
        "2",   // Autos & Vehicles
        "19",  // Travel & Events
        "25",  // News & Politics
        "26",  // Howto & Style
        "27",  // Education
        "28",  // Science & Technology
        "29"   // Nonprofits & Activism
    ]

    /// Noms lisibles, utilisés uniquement pour l'affichage et le débogage.
    static let names: [String: String] = [
        "1": "Film & Animation",
        "2": "Autos & Vehicles",
        "10": "Music",
        "15": "Pets & Animals",
        "17": "Sports",
        "19": "Travel & Events",
        "20": "Gaming",
        "22": "People & Blogs",
        "23": "Comedy",
        "24": "Entertainment",
        "25": "News & Politics",
        "26": "Howto & Style",
        "27": "Education",
        "28": "Science & Technology",
        "29": "Nonprofits & Activism",
        "30": "Movies",
        "31": "Anime/Animation",
        "32": "Action/Adventure",
        "33": "Classics",
        "34": "Comedy",
        "35": "Documentary",
        "36": "Drama",
        "37": "Family",
        "38": "Foreign",
        "39": "Horror",
        "40": "Sci-Fi/Fantasy",
        "41": "Thriller",
        "42": "Shorts",
        "43": "Shows",
        "44": "Trailers"
    ]

    /// Nom lisible d'une catégorie (ou l'identifiant brut si inconnu).
    static func name(for id: String) -> String {
        names[id] ?? "Catégorie \(id)"
    }
}
