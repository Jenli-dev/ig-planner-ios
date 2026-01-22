import SwiftUI

// Быстрый hex-инициализатор
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r)/255,
                  green: Double(g)/255,
                  blue: Double(b)/255,
                  opacity: Double(a)/255)
    }
}

enum AppGradient {
    static let brand = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: "#FFD44E"), location: 0.00), // yellow
            .init(color: Color(hex: "#FF8A3D"), location: 0.45), // orange
            .init(color: Color(hex: "#FF3D85"), location: 1.00)  // pink
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// Глобальный модификатор фона
struct BrandBackground: ViewModifier {
    var dimInDark: Bool = true
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        ZStack {
            AppGradient.brand
                .opacity(dimInDark && scheme == .dark ? 0.92 : 1.0)
                .ignoresSafeArea()
            content
        }
    }
}

extension View {
    func brandBackground(dimInDark: Bool = true) -> some View {
        self.modifier(BrandBackground(dimInDark: dimInDark))
    }
}
