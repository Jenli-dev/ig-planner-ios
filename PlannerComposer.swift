import SwiftUI

struct PlannerComposer: View {
    // Callbacks
    var onCreated: (PlannerJob) -> Void
    var onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // FORM
    @State private var creationId: String = ""                  // обязателен для бекенда
    @State private var caption: String = ""                     // опционально, только для UI
    @State private var date: Date = Date().addingTimeInterval(60 * 60) // +1 час по умолчанию
    
    // UI
    @State private var isSaving = false
    @State private var errorText: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schedule post")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 160, height: 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    
                    // CREATION ID
                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CREATION ID")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.65))
                            
                            TextField("Paste creation_id…", text: $creationId)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundColor(.white)
                                .tint(.white)
                                .padding(12)
                                .background(
                                    Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                        }
                    }
                    
                    // CAPTION
                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CAPTION")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.65))
                            
                            TextEditor(text: $caption)
                                .font(.system(size: 16))
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .foregroundColor(.white)
                                .tint(.white)
                                .padding(8)
                                .background(
                                    Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                        }
                    }
                    // PUBLISH TIME
                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PUBLISH TIME (UTC)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.65))
                            
                            HStack(spacing: 10) {
                                DatePicker("Publish at",
                                           selection: $date,
                                           displayedComponents: .date)
                                .labelsHidden()
                                .tint(.white)
                                
                                DatePicker("",
                                           selection: $date,
                                           displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(.white)
                            }
                            
                            // быстрые пресеты
                            HStack(spacing: 8) {
                                chip("+1h")  { date = roundTo5Min(Date().addingTimeInterval(60 * 60)) }
                                chip("+3h")  { date = roundTo5Min(Date().addingTimeInterval(60 * 60 * 3)) }
                                chip("Tomorrow 09:00") { date = roundTo5Min(nextDayAt(hour: 9, minute: 0)) }
                                chip("Next Mon 09:00") { date = roundTo5Min(nextWeekday(.monday, hour: 9)) }
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    // CTA
                    Button {
                        Task { await createJob(caption: caption, publishUTC: toUTC(date)) }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving { ProgressView().tint(.white) }
                            Text(isSaving ? "Saving…" : "Schedule")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppGradient.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                        .foregroundColor(.white)
                    }
                    .disabled(isSaving || creationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity((isSaving || creationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1)
                    
                    if let err = errorText {
                        Text(err)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                    
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        // ВАЖНО: делаем фон шита прозрачным, чтобы был виден brandBackground
        .presentationBackground(.clear)
        .brandBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .tint(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving…" : "Schedule") {
                    Task { await createJob(caption: caption, publishUTC: toUTC(date)) }
                }
                .disabled(isSaving || creationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar) // убираем баровый фон
        .onAppear {
            // округляем стартовую дату к ближайшим 5 минутам — удобнее выбирать
            date = roundTo5Min(date)
        }
    }
    // MARK: - Card & Chip
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                .foregroundColor(.white)
        }
    }

    // MARK: - Date helpers (внутри View!)
    private func roundTo5Min(_ d: Date) -> Date {
        let step: TimeInterval = 5 * 60
        let t = d.timeIntervalSince1970
        return Date(timeIntervalSince1970: floor((t + step / 2) / step) * step)
    }

    private enum Weekday: Int { case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday }

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

    private func toUTC(_ local: Date) -> Date {
        let tz = TimeZone.current
        let seconds = -TimeInterval(tz.secondsFromGMT(for: local))
        return Date(timeInterval: seconds, since: local)
    }

    // MARK: - Networking
    private func createJob(caption: String, publishUTC: Date) async {
        guard !creationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run { errorText = "Please paste creation_id" }
            return
        }

        await MainActor.run { isSaving = true; errorText = nil }
        defer { Task { await MainActor.run { isSaving = false } } }

        do {
            // ISO-8601 в UTC
            let iso = ISO8601DateFormatter()
            iso.timeZone = TimeZone(secondsFromGMT: 0)
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let publishAtISO = iso.string(from: publishUTC)

            // POST /ig/schedule
            var req = URLRequest(url: API.url("/ig/schedule"))
            req.httpMethod = "POST"
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "creation_id": creationId,
                "publish_at": publishAtISO
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200...299).contains(http.statusCode) else {
                let text = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw NSError(domain: "PlannerComposer", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: text])
            }

            struct Resp: Decodable {
                let ok: Bool
                let job_id: String
                let status: String
                let publish_at_utc: String
            }
            let r = try JSONDecoder().decode(Resp.self, from: data)

            let parsedUTC: Date = {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                iso.timeZone = TimeZone(secondsFromGMT: 0)
                return iso.date(from: r.publish_at_utc) ?? publishUTC
            }()

            let job = PlannerJob(
                id: r.job_id,
                status: r.status.lowercased(),
                publishAtUTC: parsedUTC,
                creationId: creationId,
                error: nil,
                resultSummary: nil,
                caption: caption
            )

            await MainActor.run {
                onCreated(job)
                dismiss()
            }
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
        }
    }
}
