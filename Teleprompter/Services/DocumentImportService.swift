import Foundation
import PDFKit
import UniformTypeIdentifiers

struct ImportedScriptDocument {
    let title: String
    let text: String
    let fileName: String
}

enum DocumentImportError: LocalizedError {
    case unsupportedType
    case emptyDocument
    case cannotOpen

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            "Choose a TXT or PDF file."
        case .emptyDocument:
            "No readable text was found in this file."
        case .cannotOpen:
            "The selected file could not be opened."
        }
    }
}

enum DocumentImportService {
    static let allowedContentTypes: [UTType] = [.plainText, .pdf]

    static func read(from url: URL) throws -> ImportedScriptDocument {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .nameKey])
        let contentType = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        let fileName = values?.name ?? url.lastPathComponent
        let title = url.deletingPathExtension().lastPathComponent

        let text: String
        if contentType?.conforms(to: .pdf) == true || url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else {
                throw DocumentImportError.cannotOpen
            }
            text = (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string }
                .joined(separator: "\n\n")
        } else if contentType?.conforms(to: .plainText) == true || url.pathExtension.lowercased() == "txt" {
            let data = try Data(contentsOf: url)
            text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .unicode)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
        } else {
            throw DocumentImportError.unsupportedType
        }

        let cleaned = normalize(text)
        guard !cleaned.isEmpty else {
            throw DocumentImportError.emptyDocument
        }

        return ImportedScriptDocument(title: title, text: cleaned, fileName: fileName)
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
