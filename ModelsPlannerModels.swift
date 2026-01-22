import Foundation
import SwiftUI

// MARK: - /ig/schedule list + cancel models

struct PlannerJob: Identifiable, Hashable {
    let id: String
    let status: String              // scheduled | done | error | canceled
    let publishAtUTC: Date?
    let creationId: String?
    let error: String?
    let resultSummary: String?
    let caption: String            // <-- добавили caption

    var statusColor: Color {
        switch status.lowercased() {
        case "scheduled": return .yellow
        case "done":      return .green
        case "error":     return .red
        case "canceled":  return .gray
        default:          return .white.opacity(0.9)
        }
    }
}

// Удобная строка для UI
extension PlannerJob {
    var captionOrPlaceholder: String {
        let c = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return c.isEmpty ? "Scheduled post" : c
    }
}

// Сырые поля из бэка (jobs — словарь job_id -> джоб)
struct ScheduleListResp: Decodable {
    let ok: Bool
    let jobs: [String: PlannerJobRaw]
}

struct PlannerJobRaw: Decodable {
    let status: String?
    let creation_id: String?
    let publish_at: String?           // ISO 8601 строка
    let result: PlannerJobResultRaw?
    let error: String?
}

struct PlannerJobResultRaw: Decodable {
    // структура не фиксирована; возьмём короткое резюме
    let id: String?
    let permalink: String?
    let caption: String?
}

// MARK: - ISO8601 utility
func parseISO8601(_ s: String?) -> Date? {
    guard let s else { return nil }
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = fmt.date(from: s) { return d }           // с миллисекундами
    fmt.formatOptions = [.withInternetDateTime]         // без миллисекунд
    return fmt.date(from: s)
}

// MARK: - Mapping Raw -> UI model
extension PlannerJob {
    static func fromRaw(id: String, raw: PlannerJobRaw) -> PlannerJob {
        // короткое резюме результата
        var summary: String?
        if let r = raw.result {
            var parts: [String] = []
            if let rid = r.id { parts.append("#\(rid)") }
            if let link = r.permalink { parts.append(link) }
            summary = parts.isEmpty ? nil : parts.joined(separator: " • ")
        }

        return PlannerJob(
            id: id,
            status: (raw.status ?? "").lowercased(),
            publishAtUTC: parseISO8601(raw.publish_at),
            creationId: raw.creation_id,
            error: raw.error,
            resultSummary: summary,
            caption: raw.result?.caption ?? ""   // <-- сюда кладём подпись
        )
    }
}
