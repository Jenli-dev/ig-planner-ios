import SwiftUI
import UIKit

// MARK: - Chat models

private struct ChatMessage: Identifiable, Equatable {
    enum Role: String { case user, assistant }

    let id = UUID()
    let role: Role
    let text: String
    let created = Date()
}

private extension ChatMessage {
    /// Формат для бэка: {"role":"user|assistant", "content":"..."}
    func toBackend() -> [String: String] {
        ["role": role.rawValue, "content": text]
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let msg: ChatMessage
    private var isUser: Bool { msg.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isUser { Spacer(minLength: 20) }

            VStack(alignment: .leading, spacing: 6) {
                Text(msg.text)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .regular))
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isUser ? Color.white.opacity(0.18) : Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isUser ? 0.28 : 0.18), lineWidth: 1)
            )

            if !isUser { Spacer(minLength: 20) }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.white.opacity(0.8)).frame(width: 6, height: 6)
            Circle().fill(Color.white.opacity(0.8)).frame(width: 6, height: 6)
            Circle().fill(Color.white.opacity(0.8)).frame(width: 6, height: 6)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
// MARK: - AIChatView

struct AIChatView: View {
    @State private var messages: [ChatMessage] = [
        .init(role: .assistant, text: "Hey! Ask me anything about your posts, analytics, or ideas ✨")
    ]
    @State private var inputText: String = ""
    @State private var isSending = false
    @State private var errorText: String?

    // автоскролл к последнему сообщению
    @State private var lastMessageID = UUID()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("AI Chat")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 6)

                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.horizontal, 12)

                // Messages
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { msg in
                                MessageBubble(msg: msg)
                                    .id(msg.id)
                            }

                            if isSending {
                                TypingIndicator()
                                    .id(lastMessageID)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    // iOS 17+ синтаксис onChange (старый не нужен, таргетим 17)
                    .onChange(of: messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: isSending) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(messages.last?.id ?? lastMessageID, anchor: .bottom)
                        }
                    }
                } // <- закрыли ScrollViewReader

                // Input bar
                inputBar
                    .background(.ultraThinMaterial.opacity(0.2))
                    .overlay(
                        Divider().background(Color.white.opacity(0.12)),
                        alignment: .top
                    )
            }
        }
        .brandBackground() 
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            ),
            actions: { Button("OK") { errorText = nil } },
            message: { Text(errorText ?? "") }
        )
    }

    // MARK: - Input

        private var inputBar: some View {
            HStack(spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("Write a message…")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $inputText)
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 42, maxHeight: 120)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }

                Button {
                    Task { await sendCurrent() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSending || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      ? Color.white.opacity(0.18) : Color.blue)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .disabled(isSending || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .keyboardDismissGesture()
        }

        // MARK: - Actions

        private func sendCurrent() async {
            let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            await MainActor.run {
                inputText = ""
                let userMsg = ChatMessage(role: .user, text: text)
                messages.append(userMsg)
                lastMessageID = userMsg.id
                isSending = true
            }

            do {
                let reply = try await sendToBackend(history: messages)
                await MainActor.run {
                    messages.append(.init(role: .assistant, text: reply))
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    messages.append(.init(role: .assistant, text: "Oops, I couldn't reply right now. Please try again."))
                }
            }

            await MainActor.run { isSending = false }
        }

        // MARK: - Networking

        /// NOTE: /ai/chat endpoint is not implemented in the backend yet.
        /// This is a placeholder that returns a helpful message.
        /// TODO: Implement /ai/chat endpoint in backend or replace with alternative AI service
        private func sendToBackend(history: [ChatMessage]) async throws -> String {
            // Placeholder: return a message indicating the feature is not available yet
            // In the future, this can be replaced with actual AI chat API call
            let lastUserMessage = history.last { $0.role == .user }?.text ?? ""
            
            // Simple placeholder response
            if lastUserMessage.lowercased().contains("help") || lastUserMessage.lowercased().contains("помощь") {
                return """
                I'm here to help! Currently, the AI chat feature is being set up. 
                In the meantime, you can:
                • Use AI image generation (Text-to-Image, Image-to-Image, Batch)
                • Schedule and publish posts
                • View analytics and insights
                • Edit photos and videos
                
                The full AI chat will be available soon! 🚀
                """
            }
            
            return """
            Thanks for your message! The AI chat feature is currently being developed.
            For now, you can use other features like AI image generation, post scheduling, and analytics.
            Full chat support coming soon! ✨
            """
        }
    }

    // MARK: - Helpers

    private extension View {
        /// Скрывать клавиатуру по тапу за пределами TextEditor
        func keyboardDismissGesture() -> some View {
            self.onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            }
        }
    }
