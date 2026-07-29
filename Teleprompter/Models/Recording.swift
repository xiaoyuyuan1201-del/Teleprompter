import Foundation

struct RecordedVideo: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date
    let fileName: String
    let duration: TimeInterval
    let fileSizeBytes: Int64
    let hasAudio: Bool

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        fileName: String,
        duration: TimeInterval,
        fileSizeBytes: Int64,
        hasAudio: Bool
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.fileName = fileName
        self.duration = duration
        self.fileSizeBytes = fileSizeBytes
        self.hasAudio = hasAudio
    }

    var durationText: String {
        let total = max(0, Int(duration.rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
}
