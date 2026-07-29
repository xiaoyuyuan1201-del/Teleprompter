import Combine
import Foundation

@MainActor
final class ScriptStore: ObservableObject {
    @Published private(set) var scripts: [PromptScript] = []
    @Published var sortOption: ScriptSortOption {
        didSet {
            UserDefaults.standard.set(sortOption.rawValue, forKey: sortKey)
            sortAndSave()
        }
    }

    private let storageKey = "teleprompter.savedScripts.v2"
    private let legacyStorageKey = "teleprompter.savedScripts.v1"
    private let sortKey = "teleprompter.scriptSortOption"
    let freeScriptLimit = 3

    init() {
        let storedSort = UserDefaults.standard.string(forKey: sortKey)
        sortOption = ScriptSortOption(rawValue: storedSort ?? "") ?? .updatedNewest
        load()
        if scripts.isEmpty {
            scripts = [
                PromptScript(
                    title: "Welcome to Teleprompter",
                    body: "Hi! This is your first script. Keep your eyes near the camera, speak at your own pace, and let Teleprompter keep every line right where you need it."
                )
            ]
            save()
        }
        sortScripts()
    }

    func script(with id: UUID) -> PromptScript? {
        scripts.first { $0.id == id }
    }

    func upsert(_ script: PromptScript, touchUpdatedAt: Bool = true) {
        var updated = script
        if touchUpdatedAt {
            updated.updatedAt = .now
        }

        if let index = scripts.firstIndex(where: { $0.id == updated.id }) {
            scripts[index] = updated
        } else {
            scripts.append(updated)
        }

        sortAndSave()
    }

    func autosave(_ script: PromptScript) {
        var draft = script
        draft.isDraft = true
        upsert(draft)
    }

    func finalize(_ script: PromptScript) {
        var final = script
        final.isDraft = false
        upsert(final)
    }

    func rename(_ script: PromptScript, to title: String) {
        guard var updated = self.script(with: script.id) else { return }
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        upsert(updated)
    }

    func duplicate(_ script: PromptScript) {
        let duplicate = PromptScript(
            title: script.displayTitle + " Copy",
            body: script.body,
            isDraft: true,
            sourceFileName: script.sourceFileName
        )
        upsert(duplicate)
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where scripts.indices.contains(index) {
            scripts.remove(at: index)
        }
        save()
    }

    func delete(_ script: PromptScript) {
        scripts.removeAll { $0.id == script.id }
        save()
    }

    func toggleFavorite(_ script: PromptScript) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index].isFavorite.toggle()
        scripts[index].updatedAt = .now
        sortAndSave()
    }

    func canCreateScript(isPro: Bool) -> Bool {
        isPro || scripts.count < freeScriptLimit
    }

    private func sortAndSave() {
        sortScripts()
        save()
    }

    private func sortScripts() {
        scripts.sort { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite && !rhs.isFavorite
            }

            switch sortOption {
            case .updatedNewest:
                return lhs.updatedAt > rhs.updatedAt
            case .updatedOldest:
                return lhs.updatedAt < rhs.updatedAt
            case .title:
                return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
            }
        }
    }

    private var storageURL: URL {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return baseURL
            .appendingPathComponent("Teleprompter", isDirectory: true)
            .appendingPathComponent("scripts.json", isDirectory: false)
    }

    private func load() {
        let defaults = UserDefaults.standard
        let fileData = try? Data(contentsOf: storageURL)
        let legacyData = defaults.data(forKey: storageKey) ?? defaults.data(forKey: legacyStorageKey)
        guard let data = fileData ?? legacyData else { return }

        do {
            scripts = try JSONDecoder().decode([PromptScript].self, from: data)
            if fileData == nil {
                save()
            }
        } catch {
            scripts = []
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        let directory = storageURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Keep a small compatibility backup if the file system write fails.
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
