import SwiftUI

// Универсальный «круглый» стиль для текстфилдов на тёмном фоне
extension View {
    func textFieldStyleRounded() -> some View {
        self
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .foregroundColor(.white)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}
