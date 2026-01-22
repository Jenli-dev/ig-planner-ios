import Foundation

@MainActor
final class VideoFilterVM: ObservableObject {
    @Published var isLoading = false
    @Published var progress: Int?
    @Published var outputURL: String?
    @Published var lastError: String?

    func reset() {
        isLoading = false
        progress = nil
        outputURL = nil
        lastError = nil
    }

    func runFilter(for url: String, preset: String, intensity: Double) async {
        isLoading = true
        lastError = nil
        outputURL = nil
        progress = nil
        do {
            let enq = try await MediaAPI.enqueueVideoFilter(url: url, preset: preset, intensity: intensity)
            while outputURL == nil {
                let st = try await MediaAPI.pollJob(jobID: enq.job_id)
                if st.status == "DONE" {
                    outputURL = st.result?.output_url
                } else if st.status == "ERROR" {
                    throw NSError(domain: "VideoFilter", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: st.error ?? "Unknown"])
                } else {
                    progress = st.result?.progress
                    try await Task.sleep(nanoseconds: 800_000_000)
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
    }
}
