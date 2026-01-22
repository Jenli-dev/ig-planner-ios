import Foundation

enum UtilAPI {
    // здесь могут быть другие методы утилит, если появятся
}

extension UtilAPI {
    static func fonts() async throws -> [FontItem] {
        // Явно указываем тип, чтобы убрать возможную неоднозначность дженерика
        let items: [FontItem] = try await API.getJSON("/util/fonts", params: nil)
        return items
    }
}
