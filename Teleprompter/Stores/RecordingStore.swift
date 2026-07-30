import Combine
import Foundation

@MainActor
final class RecordingStore: ObservableObject {
    @Published private(set) var recordings: [RecordedVideo] = []
    @Published private(set) var folders: [VideoFolder] = []

    private let fileManager = FileManager.default

    init() {
        createDirectoryIfNeeded()
        load()
        loadFolders()
        removeMissingEntries()
    }

    @discardableResult
    func createFolder(name: String) -> VideoFolder {
        let folder = VideoFolder(name: name)
        folders.append(folder)
        folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveFolders()
        return folder
    }

    func renameFolder(_ folder: VideoFolder, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveFolders()
    }

    func deleteFolder(_ folder: VideoFolder) {
        folders.removeAll { $0.id == folder.id }
        saveFolders()
        clearFolder(folder.id)
    }

    func move(_ recording: RecordedVideo, toFolder folderID: UUID?) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index].folderID = folderID
        save()
    }

    func fileURL(for recording: RecordedVideo) -> URL {
        recordingsDirectory.appendingPathComponent(recording.fileName)
    }

    @discardableResult
    func importRecording(
        from sourceURL: URL,
        title: String,
        verification: RecordingVerification?,
        folderID: UUID? = nil
    ) throws -> RecordedVideo {
        createDirectoryIfNeeded()

        let id = UUID()
        let pathExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let fileName = "\(id.uuidString).\(pathExtension)"
        let destinationURL = recordingsDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path)
        let storedFileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let recording = RecordedVideo(
            id: id,
            title: cleanTitle.isEmpty ? "Untitled recording" : cleanTitle,
            fileName: fileName,
            duration: verification?.duration ?? 0,
            fileSizeBytes: verification?.fileSizeBytes ?? storedFileSize,
            hasAudio: verification?.hasAudio ?? false,
            folderID: folderID
        )

        recordings.insert(recording, at: 0)
        sortAndSave()
        return recording
    }

    func recordings(in folderID: UUID?) -> [RecordedVideo] {
        recordings.filter { $0.folderID == folderID }
    }

    /// Clears the folder tag from any recordings pointing at a folder that
    /// was just deleted.
    func clearFolder(_ folderID: UUID) {
        var didChange = false
        for index in recordings.indices where recordings[index].folderID == folderID {
            recordings[index].folderID = nil
            didChange = true
        }
        if didChange { save() }
    }

    func rename(_ recording: RecordedVideo, to title: String) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        recordings[index].title = cleanTitle
        sortAndSave()
    }

    func toggleFavorite(_ recording: RecordedVideo) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index].isFavorite.toggle()
        save()
    }

    func delete(_ recording: RecordedVideo) {
        let url = fileURL(for: recording)
        try? fileManager.removeItem(at: url)
        recordings.removeAll { $0.id == recording.id }
        save()
    }

    func recording(with id: UUID) -> RecordedVideo? {
        recordings.first { $0.id == id }
    }

    private var appDirectory: URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return baseURL.appendingPathComponent("Teleprompter", isDirectory: true)
    }

    private var recordingsDirectory: URL {
        appDirectory.appendingPathComponent("Recordings", isDirectory: true)
    }

    private var metadataURL: URL {
        appDirectory.appendingPathComponent("recordings.json", isDirectory: false)
    }

    private var foldersStorageURL: URL {
        appDirectory.appendingPathComponent("videoFolders.json", isDirectory: false)
    }

    private func loadFolders() {
        guard let data = try? Data(contentsOf: foldersStorageURL) else { return }
        folders = (try? JSONDecoder().decode([VideoFolder].self, from: data)) ?? []
    }

    private func saveFolders() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        createDirectoryIfNeeded()
        try? data.write(to: foldersStorageURL, options: .atomic)
    }

    private func createDirectoryIfNeeded() {
        try? fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
    }

    private func load() {
        guard let data = try? Data(contentsOf: metadataURL),
              let saved = try? JSONDecoder().decode([RecordedVideo].self, from: data) else {
            recordings = []
            return
        }
        recordings = saved.sorted { $0.createdAt > $1.createdAt }
    }

    private func removeMissingEntries() {
        let validRecordings = recordings.filter {
            fileManager.fileExists(atPath: fileURL(for: $0).path)
        }
        guard validRecordings.count != recordings.count else { return }
        recordings = validRecordings
        save()
    }

    private func sortAndSave() {
        recordings.sort { $0.createdAt > $1.createdAt }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(recordings) else { return }
        createDirectoryIfNeeded()
        try? data.write(to: metadataURL, options: .atomic)
    }
}
