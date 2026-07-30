import SwiftUI

struct FolderDetailView: View {
    @EnvironmentObject private var scriptStore: ScriptStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var recordingStore: RecordingStore
    @Environment(\.dismiss) private var dismiss

    let folder: ScriptFolder

    @State private var searchText = ""
    @State private var editorMode: EditorMode?
    @State private var activePrompt: PromptScript?
    @State private var showsPaywall = false
    @State private var renameTarget: PromptScript?
    @State private var renameText = ""
    @State private var showsFileImporter = false
    @State private var importError: String?
    @State private var showsRenameFolderAlert = false
    @State private var folderRenameText = ""
    @State private var showsDeleteFolderAlert = false

    private enum EditorMode: Identifiable {
        case new
        case edit(PromptScript)

        var id: String {
            switch self {
            case .new:
                "new"
            case .edit(let script):
                script.id.uuidString
            }
        }
    }

    private var currentFolder: ScriptFolder {
        scriptStore.folders.first { $0.id == folder.id } ?? folder
    }

    private var filteredScripts: [PromptScript] {
        let base = scriptStore.scripts(in: folder.id)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(query) ||
            $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    searchBar

                    if scriptStore.scripts(in: folder.id).isEmpty {
                        emptyState
                    } else if filteredScripts.isEmpty {
                        emptySearchState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredScripts) { script in
                                ScriptRow(
                                    script: script,
                                    folders: scriptStore.folders,
                                    onEdit: { editorMode = .edit(script) },
                                    onPrompt: { activePrompt = script },
                                    onFavorite: { scriptStore.toggleFavorite(script) },
                                    onRename: {
                                        renameText = script.displayTitle
                                        renameTarget = script
                                    },
                                    onDuplicate: {
                                        if scriptStore.canCreateScript(isPro: purchaseManager.isPro) {
                                            scriptStore.duplicate(script)
                                        } else {
                                            showsPaywall = true
                                        }
                                    },
                                    onMove: { folderID in
                                        scriptStore.move(script, toFolder: folderID)
                                    },
                                    onDelete: { scriptStore.delete(script) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(currentFolder.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        createScript()
                    } label: {
                        Label("New Script", systemImage: "plus")
                    }
                    Button {
                        importScript()
                    } label: {
                        Label("Import File", systemImage: "square.and.arrow.down")
                    }
                    Divider()
                    Button {
                        folderRenameText = currentFolder.displayName
                        showsRenameFolderAlert = true
                    } label: {
                        Label("Rename Folder", systemImage: "character.cursor.ibeam")
                    }
                    Button(role: .destructive) {
                        showsDeleteFolderAlert = true
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                switch mode {
                case .new:
                    ScriptEditorView(script: nil, folderID: folder.id)
                case .edit(let script):
                    ScriptEditorView(script: scriptStore.script(with: script.id) ?? script)
                }
            }
            .environmentObject(scriptStore)
            .environmentObject(purchaseManager)
        }
        .fullScreenCover(item: $activePrompt) { script in
            TeleprompterView(script: scriptStore.script(with: script.id) ?? script)
                .environmentObject(purchaseManager)
                .environmentObject(recordingStore)
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(source: .inApp)
                .environmentObject(purchaseManager)
        }
        .alert("Rename script", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Script title", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
            Button("Rename") {
                if let renameTarget {
                    scriptStore.rename(renameTarget, to: renameText)
                }
                renameTarget = nil
            }
        } message: {
            Text("Choose a clear name so the script is easy to find later.")
        }
        .alert("Rename folder", isPresented: $showsRenameFolderAlert) {
            TextField("Folder name", text: $folderRenameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                scriptStore.renameFolder(currentFolder, to: folderRenameText)
            }
        }
        .alert("Delete folder?", isPresented: $showsDeleteFolderAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                scriptStore.deleteFolder(currentFolder)
                recordingStore.clearFolder(currentFolder.id)
                dismiss()
            }
        } message: {
            Text("Scripts inside will move back to \"No Folder\". This can't be undone.")
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: DocumentImportService.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search in \(currentFolder.displayName)", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .contentCard(cornerRadius: 16)
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "folder")
                .font(.appHeadline)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 38, height: 38)
                .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text("No scripts here yet")
                    .font(.appHeadline)
                Text("Create or import a script, or move one in from its menu.")
                    .font(.appSecondary)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .contentCard()
    }

    private var emptySearchState: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.appHeadline)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 38, height: 38)
                .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text("No matches")
                    .font(.appHeadline)
                Text("Try a different search term.")
                    .font(.appSecondary)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .contentCard()
    }

    private func createScript() {
        if scriptStore.canCreateScript(isPro: purchaseManager.isPro) {
            editorMode = .new
        } else {
            showsPaywall = true
        }
    }

    private func importScript() {
        if scriptStore.canCreateScript(isPro: purchaseManager.isPro) {
            showsFileImporter = true
        } else {
            showsPaywall = true
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let imported = try DocumentImportService.read(from: url)
            let script = PromptScript(
                title: imported.title,
                body: imported.text,
                isDraft: true,
                sourceFileName: imported.fileName,
                folderID: folder.id
            )
            scriptStore.upsert(script)
            editorMode = .edit(script)
        } catch {
            importError = error.localizedDescription
        }
    }
}
