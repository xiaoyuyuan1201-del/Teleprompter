import Foundation
import OSLog

enum AppAnalytics {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Teleprompter", category: "product-events")

    static func track(_ name: String, metadata: [String: String] = [:]) {
        let payload = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        logger.info("event=\(name, privacy: .public) \(payload, privacy: .public)")
    }
}
