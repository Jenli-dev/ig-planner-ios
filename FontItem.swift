import Foundation

/// Модель шрифта из /util/fonts
struct FontItem: Codable, Hashable {
    let name: String      // системное имя (то, что шлём на бэк)
    let display: String?  // красивое имя для UI
}
