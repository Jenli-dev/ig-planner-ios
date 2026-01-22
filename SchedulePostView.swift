import SwiftUI

struct SchedulePostView: View {
    // входные данные
    @Environment(\.dismiss) private var dismiss
    let onSchedule: (_ caption: String, _ publishUTC: Date) -> Void

    // состояние
    @State private var caption: String = ""
    @State private var publishLocal: Date = Date().addingTimeInterval(60*30) // через 30 минут
    @State private var isSaving = false
    @FocusState private var captionFocused: Bool

    // ограничения
    private let maxCaption = 2200

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerTitle

                    // Caption
                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CAPTION")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                            ZStack(alignment: .topLeading) {
                                if caption.isEmpty {
                                    Text("Write a caption…")
                                        .foregroundColor(.white.opacity(0.35))
                                        .padding(.top, 10)
                                        .padding(.horizontal, 12)
                                }
                                TextEditor(text: $caption)
                                    .font(.system(size: 16))
                                    .frame(minHeight: 120)
                                    .scrollContentBackground(.hidden)
                                    .foregroundColor(.white)
                                    .tint(.white)
                                    .focused($captionFocused)
                            }

                            HStack {
                                Spacer()
                                Text("\(caption.count)/\(maxCaption)")
                                    .font(.caption2)
                                    .foregroundColor(caption.count > maxCaption ? .red : .white.opacity(0.7))
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.5)
                            }
                        }
                    }

                    // Publish time
                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PUBLISH TIME (UTC)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                            // Date & time pickers по-отдельности — читаемо
                            HStack(spacing: 10) {
                                DatePicker(
                                    "Publish at",
                                    selection: $publishLocal,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .tint(.white)

                                DatePicker(
                                    "",
                                    selection: $publishLocal,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .tint(.white)
                            }

                            quickChips
                                .padding(.top, 4)

                            // Предпросмотр итогового UTC времени
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your local time: \(formatLocal(publishLocal))")
                                Text("Will be sent as UTC: \(formatUTC(publishLocal))")
                            }
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.75))
                            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                            .padding(.top, 2)
                        }
                    }

                    // CTA
                    Button(action: schedule) {
                        HStack(spacing: 8) {
                            if isSaving { ProgressView().tint(.white) }
                            Text("Schedule")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppGradient.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(.white.opacity(0.22), lineWidth: 1)
                        )
                        .foregroundColor(.white)
                    }
                    .disabled(!isValid || isSaving)
                    .opacity(!isValid ? 0.6 : 1)

                    Spacer(minLength: 8)
                }
                .padding(16)
            }
        }
        .brandBackground()   // ← единый бренд-фон
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .tint(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Schedule") { schedule() }
                    .disabled(!isValid || isSaving)
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
        .onAppear {
            // округлим к ближайшим 5 минутам (приятнее выбирать)
            publishLocal = roundTo5Min(Date().addingTimeInterval(60*30))
        }
        .onTapGesture { captionFocused = false }
    }

    // MARK: - Subviews

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Schedule post")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            // маленькая полоска-акцент
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.18))
                .frame(width: 160, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .overlay(content().padding(14), alignment: .topLeading)
    }

    private var quickChips: some View {
        HStack(spacing: 8) {
            chip("+1h")  { publishLocal = roundTo5Min(Date().addingTimeInterval(60*60)) }
            chip("+3h")  { publishLocal = roundTo5Min(Date().addingTimeInterval(60*60*3)) }
            chip("Tomorrow 09:00") {
                publishLocal = roundTo5Min(nextDayAt(hour: 9, minute: 0))
            }
            chip("Next Mon 09:00") {
                publishLocal = roundTo5Min(nextWeekday(.monday, hour: 9))
            }
        }
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .foregroundColor(.white)
        }
    }

    // MARK: - Logic & helpers

    private var isValid: Bool {
        !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        caption.count <= maxCaption
    }

    private func schedule() {
        guard isValid else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isSaving = true
        let utc = toUTC(publishLocal)
        onSchedule(caption, utc)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isSaving = false
            dismiss()
        }
    }

    // форматирование
    private func formatLocal(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.dateFormat = "d MMM yyyy, HH:mm"
        return df.string(from: d)
    }

    private func formatUTC(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "d MMM yyyy, HH:mm 'UTC'"
        return df.string(from: toUTC(d))
    }

    // округление к 5 минутам
    private func roundTo5Min(_ d: Date) -> Date {
        let step: TimeInterval = 5 * 60
        let t = d.timeIntervalSince1970
        return Date(timeIntervalSince1970: floor((t + step / 2) / step) * step)
    }

    // генераторы дат
    private func nextDayAt(hour: Int, minute: Int) -> Date {
        var cal = Calendar.current
        cal.timeZone = .current
        let now = Date()
        var comp = cal.dateComponents([.year, .month, .day], from: now)
        comp.day = (comp.day ?? 0) + 1
        comp.hour = hour
        comp.minute = minute
        return cal.date(from: comp) ?? now
    }

    private func nextWeekday(_ wd: Weekday, hour: Int) -> Date {
        var cal = Calendar.current
        cal.timeZone = .current
        let now = Date()
        let weekdayNow = cal.component(.weekday, from: now)
        let delta = (wd.rawValue - weekdayNow + 7) % 7
        var comp = cal.dateComponents([.year, .month, .day], from: now)
        comp.day = (comp.day ?? 0) + (delta == 0 ? 7 : delta)
        comp.hour = hour
        comp.minute = 0
        return cal.date(from: comp) ?? now
    }

    enum Weekday: Int { case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday }

    // локальное -> UTC
    private func toUTC(_ local: Date) -> Date {
        let tz = TimeZone.current
        let seconds = -TimeInterval(tz.secondsFromGMT(for: local))
        return Date(timeInterval: seconds, since: local)
    }
}
