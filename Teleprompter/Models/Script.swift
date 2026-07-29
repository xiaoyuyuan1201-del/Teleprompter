import Foundation

struct PromptScript: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool
    var isDraft: Bool
    var sourceFileName: String?

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isFavorite: Bool = false,
        isDraft: Bool = false,
        sourceFileName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.isDraft = isDraft
        self.sourceFileName = sourceFileName
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled script" : trimmed
    }

    var wordCount: Int {
        let separatedWords = body.split { $0.isWhitespace || $0.isPunctuation }.count
        let containsWhitespace = body.contains { $0.isWhitespace }
        return containsWhitespace ? separatedWords : body.filter { !$0.isWhitespace }.count
    }

    var estimatedMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 140.0)))
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case createdAt
        case updatedAt
        case isFavorite
        case isDraft
        case sourceFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isDraft = try container.decodeIfPresent(Bool.self, forKey: .isDraft) ?? false
        sourceFileName = try container.decodeIfPresent(String.self, forKey: .sourceFileName)
    }
}

enum ScriptSortOption: String, CaseIterable, Identifiable {
    case updatedNewest
    case updatedOldest
    case title

    var id: String { rawValue }

    var title: String {
        switch self {
        case .updatedNewest: "Newest first"
        case .updatedOldest: "Oldest first"
        case .title: "Title A-Z"
        }
    }

    var systemImage: String {
        switch self {
        case .updatedNewest: "arrow.down"
        case .updatedOldest: "arrow.up"
        case .title: "textformat"
        }
    }
}
