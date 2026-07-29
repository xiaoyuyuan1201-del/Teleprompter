import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var scriptStore: ScriptStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var recordingStore: RecordingStore

    @State private var editorMode: EditorMode?
    @State private var activePrompt: PromptScript?
    @State private var showsPaywall = false
    @State private var renameTarget: PromptScript?
    @State private var renameText = ""
    @State private var showsFileImporter = false
    @State private var importError: String?
    @State private var showsNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var folderRenameTarget: ScriptFolder?
    @State private var folderRenameText = ""
    @State private var folderDeleteTarget: ScriptFolder?
    @State private var searchText = ""
    @State private var openedFolder: ScriptFolder?

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

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

    var body: some View {
        NavigationStack {
            mainContent
                .hidesSystemNavigationBar()
                .navigationDestination(item: $openedFolder) { folder in
                    FolderDetailView(folder: folder)
                        .environmentObject(scriptStore)
                        .environmentObject(purchaseManager)
                        .environmentObject(recordingStore)
                }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                switch mode {
                case .new:
                    ScriptEditorView(script: nil)
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
        .alert("New folder", isPresented: $showsNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                let folder = scriptStore.createFolder(name: newFolderName)
                newFolderName = ""
                openedFolder = folder
            }
        } message: {
            Text("Give your folder a name to help sort your scripts.")
        }
        .alert("Rename folder", isPresented: Binding(
            get: { folderRenameTarget != nil },
            set: { if !$0 { folderRenameTarget = nil } }
        )) {
            TextField("Folder name", text: $folderRenameText)
            Button("Cancel", role: .cancel) {
                folderRenameTarget = nil
            }
            Button("Rename") {
                if let folderRenameTarget {
                    scriptStore.renameFolder(folderRenameTarget, to: folderRenameText)
                }
                folderRenameTarget = nil
            }
        }
        .alert("Delete folder?", isPresented: Binding(
            get: { folderDeleteTarget != nil },
            set: { if !$0 { folderDeleteTarget = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                folderDeleteTarget = nil
            }
            Button("Delete", role: .destructive) {
                if let folderDeleteTarget {
                    scriptStore.deleteFolder(folderDeleteTarget)
                }
                folderDeleteTarget = nil
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

    private var mainContent: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                AppHeaderRow(title: "Teleprompter", onTitleTap: { hasCompletedOnboarding = false }) {
                    if !purchaseManager.isPro {
                        proButton
                    }
                }

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        quickStartCard
                        libraryList
                    }
                    .padding(.horizontal, AppLayout.screenHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var proButton: some View {
        Button {
            showsPaywall = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                Text("Pro")
                    .font(.appCaptionEmphasis)
            }
            .foregroundStyle(Color.creatorViolet)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Color.creatorViolet.opacity(0.10), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Teleprompter Pro")
    }

    private var quickStartCard: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.creatorViolet, .creatorVioletLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 210, height: 210)
                .offset(x: 220, y: -86)

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 116, height: 116)
                .offset(x: 286, y: 92)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready for your next take?")
                        .font(.appTitle)
                        .foregroundStyle(.white)

                    Text(latestScriptDescription)
                        .font(.appSecondary)
                        .foregroundStyle(.white.opacity(0.80))
                        .lineLimit(1)
                }

                Button {
                    if let script = latestUsableScript {
                        activePrompt = script
                    } else {
                        createScript()
                    }
                } label: {
                    Label("Start prompting", systemImage: "play.fill")
                        .font(.appHeadline)
                        .foregroundStyle(Color.creatorViolet)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(
                            Color.white,
                            in: Capsule(style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
        }
        .shadow(color: Color.creatorViolet.opacity(0.14), radius: 14, y: 8)
    }

    private var visibleFolders: [ScriptFolder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return scriptStore.folders }
        return scriptStore.folders.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    private var filteredScripts: [PromptScript] {
        let base = scriptStore.scripts(in: nil)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(query) ||
            $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            QuickActionButton(title: "Import", systemImage: "doc.text", action: importScript)
            QuickActionButton(title: "AI Script", systemImage: "sparkles", action: createScript)
            QuickActionButton(title: "New Folder", systemImage: "folder") {
                newFolderName = ""
                showsNewFolderAlert = true
            }
        }
    }

    private var libraryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            quickActionsRow

            searchBar

            if scriptStore.scripts.isEmpty {
                emptyState
            } else if filteredScripts.isEmpty && visibleFolders.isEmpty {
                emptyFilterState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(visibleFolders) { folder in
                        FolderRow(
                            folder: folder,
                            count: scriptStore.scripts(in: folder.id).count,
                            onOpen: { openedFolder = folder },
                            onRename: {
                                folderRenameText = folder.displayName
                                folderRenameTarget = folder
                            },
                            onDelete: { folderDeleteTarget = folder }
                        )
                    }

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
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search scripts", text: $searchText)
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

            Menu {
                Section("Sort") {
                    ForEach(ScriptSortOption.allCases) { option in
                        Button {
                            scriptStore.sortOption = option
                        } label: {
                            Label(option.title, systemImage: option.systemImage)
                        }
                    }
                }

                Button {
                    newFolderName = ""
                    showsNewFolderAlert = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.creatorViolet)
                    .frame(width: 46, height: 46)
                    .contentCard(cornerRadius: 16)
            }
            .accessibilityLabel("Sort and filter")
        }
    }

    private var emptyFilterState: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "folder")
                .font(.appHeadline)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 38, height: 38)
                .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text("No scripts here")
                    .font(.appHeadline)
                Text("Move a script into this folder from its menu, or create a new one.")
                    .font(.appSecondary)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .contentCard()
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text")
                .font(.appHeadline)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 38, height: 38)
                .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text("No scripts")
                    .font(.appHeadline)
                Text("Create or import a script to begin recording.")
                    .font(.appSecondary)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                importScript()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(ToolSecondaryButtonStyle(height: 32, horizontalPadding: 10))
        }
        .padding(16)
        .contentCard()
    }

    private var latestUsableScript: PromptScript? {
        scriptStore.scripts
            .filter { !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .max(by: { $0.updatedAt < $1.updatedAt })
    }

    private var latestScriptDescription: String {
        latestUsableScript.map { "Continue: \($0.displayTitle)" } ?? "Create a script before recording"
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
                sourceFileName: imported.fileName
            )
            scriptStore.upsert(script)
            editorMode = .edit(script)
        } catch {
            importError = error.localizedDescription
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.appHeadline)
                    .foregroundStyle(Color.creatorViolet)
                    .frame(width: 36, height: 36)
                    .background(
                        Color.creatorViolet.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                Text(title)
                    .font(.appSubheadline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .contentCard()
        }
        .buttonStyle(.plain)
    }
}

struct ScriptRow: View {
    let script: PromptScript
    let folders: [ScriptFolder]
    let onEdit: () -> Void
    let onPrompt: () -> Void
    let onFavorite: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onMove: (UUID?) -> Void
    let onDelete: () -> Void

    private var canPrompt: Bool {
        !script.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "text.alignleft")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.creatorViolet)
                    .frame(width: 36, height: 36)
                    .background(
                        Color.creatorViolet.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(script.displayTitle)
                            .font(.appHeadline)
                            .lineLimit(1)

                        if script.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.appCaption)
                                .foregroundStyle(Color.creatorViolet)
                        }

                        if script.isDraft {
                            Text("DRAFT")
                                .font(.appMicro)
                                .tracking(1)
                                .foregroundStyle(Color.creatorViolet)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 4)
                                .background(
                                    Color.creatorViolet.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                        }
                    }

                    Text(script.body.isEmpty ? "No script text yet" : script.body)
                        .font(.appSecondary)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .lineSpacing(4)
                }

                Spacer(minLength: 4)

                Menu {
                    Button(action: onFavorite) {
                        Label(script.isFavorite ? "Remove favorite" : "Favorite", systemImage: script.isFavorite ? "star.slash" : "star")
                    }
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: onRename) {
                        Label("Rename", systemImage: "character.cursor.ibeam")
                    }
                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Menu {
                        if script.folderID != nil {
                            Button {
                                onMove(nil)
                            } label: {
                                Label("No Folder", systemImage: "circle.slash")
                            }
                            Divider()
                        }
                        ForEach(folders) { folder in
                            Button {
                                onMove(folder.id)
                            } label: {
                                if script.folderID == folder.id {
                                    Label(folder.displayName, systemImage: "checkmark")
                                } else {
                                    Text(folder.displayName)
                                }
                            }
                        }
                    } label: {
                        Label("Move to Folder", systemImage: "folder")
                    }
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 30, height: 30)
                }
            }

            Divider()

            HStack {
                HStack(spacing: 12) {
                    Label("\(script.wordCount) words", systemImage: "text.word.spacing")
                    Label("~\(script.estimatedMinutes) min", systemImage: "clock")
                }
                .font(.appCaption)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: onPrompt) {
                    Label("Prompt", systemImage: "play.fill")
                }
                .buttonStyle(ToolPrimaryButtonStyle(height: 36, horizontalPadding: 12))
                .disabled(!canPrompt)
            }
        }
        .padding(16)
        .contentCard()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onEdit)
    }
}

struct FolderRow: View {
    let folder: ScriptFolder
    let count: Int
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.appSubheadline)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 36, height: 36)
                .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.displayName)
                    .font(.appHeadline)
                    .lineLimit(1)

                Text("\(count) script\(count == 1 ? "" : "s")")
                    .font(.appSecondary)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.appCaptionEmphasis)
                .foregroundStyle(.tertiary)

            Menu {
                Button(action: onRename) {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 30, height: 30)
            }
        }
        .padding(16)
        .contentCard()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onOpen)
    }
}
