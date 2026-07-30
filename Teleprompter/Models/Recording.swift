import Foundation

struct RecordedVideo: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date
    let fileName: String
    let duration: TimeInterval
    let fileSizeBytes: Int64
    let hasAudio: Bool
    var isFavorite: Bool
    var folderID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        fileName: String,
        duration: TimeInterval,
        fileSizeBytes: Int64,
        hasAudio: Bool,
        isFavorite: Bool = false,
        folderID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.fileName = fileName
        self.duration = duration
        self.fileSizeBytes = fileSizeBytes
        self.hasAudio = hasAudio
        self.isFavorite = isFavorite
        self.folderID = folderID
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, fileName, duration, fileSizeBytes, hasAudio, isFavorite, folderID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        fileSizeBytes = try container.decodeIfPresent(Int64.self, forKey: .fileSizeBytes) ?? 0
        hasAudio = try container.decodeIfPresent(Bool.self, forKey: .hasAudio) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
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

/// A folder that groups recorded videos. Independent from `ScriptFolder` —
/// videos and scripts are organized into two separate folder systems.
struct VideoFolder: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled folder" : trimmed
    }
}
