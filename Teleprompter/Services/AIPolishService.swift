import Combine
import Foundation
import FoundationModels

enum PolishStyle: String, CaseIterable, Identifiable {
    case formal
    case casual
    case academic
    case literary
    case concise
    case humorous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .formal: "Formal"
        case .casual: "Casual"
        case .academic: "Academic"
        case .literary: "Literary"
        case .concise: "Concise"
        case .humorous: "Humorous"
        }
    }

    var subtitle: String {
        switch self {
        case .formal: "Polished, professional wording for reports and pitches."
        case .casual: "Relaxed and full of personality — easy to say on camera."
        case .academic: "Precise, rigorous language suited for research and papers."
        case .literary: "Rich, evocative phrasing with a literary flair."
        case .concise: "Tight and to the point — every word earns its place."
        case .humorous: "Witty and playful, made to bring a smile."
        }
    }

    var systemImage: String {
        switch self {
        case .formal: "briefcase.fill"
        case .casual: "face.smiling.fill"
        case .academic: "graduationcap.fill"
        case .literary: "feather"
        case .concise: "scissors"
        case .humorous: "theatermasks.fill"
        }
    }

    var instruction: String {
        switch self {
        case .formal:
            "Rewrite in a professional, business-appropriate tone suitable for formal presentations or reports."
        case .casual:
            "Rewrite so it sounds relaxed, friendly, and full of personality — natural for casual video content."
        case .academic:
            "Rewrite using precise, rigorous academic language suitable for scholarly work."
        case .literary:
            "Rewrite with rich, evocative, literary phrasing and vivid imagery."
        case .concise:
            "Make the script shorter and clearer while preserving every important point. Remove repetition and filler."
        case .humorous:
            "Rewrite with witty, playful humor while keeping the meaning intact."
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

enum AIScriptWriterError: LocalizedError {
    case emptyTopic
    case modelUnavailable
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .emptyTopic:
            "Add a topic before generating a script."
        case .modelUnavailable:
            "Writing with AI requires an Apple Intelligence compatible device with Apple Intelligence enabled."
        case .emptyResponse:
            "AI did not return any text. Try again."
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

    func write(topic: String, style: PolishStyle) async -> String? {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = AIScriptWriterError.emptyTopic.localizedDescription
            return nil
        }
        guard model.isAvailable else {
            errorMessage = AIScriptWriterError.modelUnavailable.localizedDescription
            return nil
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let session = LanguageModelSession(instructions: """
                You write scripts for a teleprompter, meant to be read aloud on camera. Return only the finished script with no explanation, title, markdown, or quotation marks.
                """)
            let response = try await session.respond(to: """
                Write a complete, ready-to-read teleprompter script about: \(trimmed)

                Tone: \(style.instruction)
                """)
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.isEmpty else {
                throw AIScriptWriterError.emptyResponse
            }
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
