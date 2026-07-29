import Combine
import Foundation
import FoundationModels

enum PolishStyle: String, CaseIterable, Identifiable {
    case grammar
    case conversational
    case concise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grammar: "Grammar"
        case .conversational: "Natural"
        case .concise: "Concise"
        }
    }

    var systemImage: String {
        switch self {
        case .grammar: "checkmark.seal"
        case .conversational: "quote.bubble"
        case .concise: "text.line.last.and.arrowtriangle.forward"
        }
    }

    var instruction: String {
        switch self {
        case .grammar:
            "Correct grammar, punctuation, and awkward wording without changing the meaning or tone."
        case .conversational:
            "Rewrite the script so it sounds natural when spoken aloud. Keep the meaning and make sentences easy to say on camera."
        case .concise:
            "Make the script shorter and clearer while preserving every important point. Remove repetition and filler."
        }
    }
}

enum AIPolishError: LocalizedError {
    case emptyText
    case modelUnavailable
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .emptyText:
            "Add some script text before using AI Polish."
        case .modelUnavailable:
            "AI Polish requires an Apple Intelligence compatible device with Apple Intelligence enabled."
        case .emptyResponse:
            "AI Polish did not return any text. Try again."
        }
    }
}

@MainActor
final class AIPolishService: ObservableObject {
    @Published private(set) var isProcessing = false
    @Published var errorMessage: String?

    private let model = SystemLanguageModel.default

    var isAvailable: Bool {
        model.isAvailable
    }

    func polish(_ text: String, style: PolishStyle) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = AIPolishError.emptyText.localizedDescription
            return nil
        }
        guard model.isAvailable else {
            errorMessage = AIPolishError.modelUnavailable.localizedDescription
            return nil
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let session = LanguageModelSession(instructions: """
                You edit scripts for a teleprompter. Return only the revised script with no explanation, title, markdown, or quotation marks. Preserve the original language.
                """)
            let response = try await session.respond(to: """
                Editing goal: \(style.instruction)

                Script:
                \(trimmed)
                """)
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.isEmpty else {
                throw AIPolishError.emptyResponse
            }
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
