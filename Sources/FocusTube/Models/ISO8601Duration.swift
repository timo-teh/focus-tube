import Foundation

/// Parseur minimal de durées ISO 8601 telles que renvoyées par YouTube.
/// Exemples : « PT4M13S », « PT1H2M3S », « PT45S », « P1DT2H », « P0D » (direct).
enum ISO8601Duration {

    /// Convertit une durée ISO 8601 en secondes. Retourne `nil` si le format est invalide.
    static func seconds(from iso: String) -> Int? {
        guard iso.hasPrefix("P") else { return nil }

        var total = 0
        var number = 0
        var inTimeSection = false

        for character in iso.dropFirst() {
            if let digit = character.wholeNumberValue {
                number = number * 10 + digit
                continue
            }

            switch character {
            case "T":
                inTimeSection = true
            case "Y":
                total += number * 365 * 86_400
            case "W":
                total += number * 7 * 86_400
            case "D":
                total += number * 86_400
            case "H":
                total += number * 3_600
            case "M":
                // « M » signifie mois avant le « T », minutes après.
                total += inTimeSection ? number * 60 : number * 30 * 86_400
            case "S":
                total += number
            default:
                return nil
            }
            number = 0
        }

        return total
    }
}
