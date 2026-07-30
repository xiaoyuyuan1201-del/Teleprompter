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
    @State private var showsSearchField = false
    @State private var libraryTab: LibraryTab = .scripts
    @State private var openedFolder: ScriptFolder?
    @State private var showsAIScript = false
    @State private var showsAIScriptWriter = false
    @FocusState private var isSearchFieldFocused: Bool
    private let searchFieldScrollID = "homeSearchField"

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
        .sheet(isPresented: $showsAIScript) {
            AIScriptSheet { title, finalText, wasPolished in
                let script = PromptScript(title: title, body: finalText, isDraft: false, isAIPolished: wasPolished)
                scriptStore.upsert(script)
            }
        }
        .sheet(isPresented: $showsAIScriptWriter) {
            AIScriptWriterSheet { title, finalText, wasPolished in
                let script = PromptScript(title: title, body: finalText, isDraft: false, isAIPolished: wasPolished)
                scriptStore.upsert(script)
            }
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
                    recordingStore.clearFolder(folderDeleteTarget.id)
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
                    if purchaseManager.isPro {
                        proBadge
                    } else {
                        proButton
                    }
                }

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 32) {
                            quickStartCard
                            libraryList
                        }
                        .padding(.horizontal, AppLayout.screenHorizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                    .onChange(of: isSearchFieldFocused) { _, isFocused in
                        guard isFocused else { return }
                        withAnimation {
                            proxy.scrollTo(searchFieldScrollID, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private var proButton: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
            Text("Pro")
                .font(.appCaptionEmphasis)
        }
        .foregroundStyle(Color.creatorViolet)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Color.creatorViolet.opacity(0.10), in: Capsule(style: .continuous))
        .contentShape(Capsule())
        .accessibilityLabel("Teleprompter Pro")
        .onTapGesture(count: 5) {
            purchaseManager.setDebugPro(true)
        }
    }

    private var proBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
            Text("Pro")
                .font(.appCaptionEmphasis)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Color.creatorViolet, in: Capsule(style: .continuous))
        .contentShape(Capsule())
        .accessibilityLabel("Teleprompter Pro member")
        .onTapGesture(count: 5) {
            purchaseManager.setDebugPro(false)
        }
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
                    Text("Write a New Script")
                        .font(.appTitle)
                        .foregroundStyle(.white)

                    Text("Let AI help you draft the perfect script")
                        .font(.appSecondary)
                        .foregroundStyle(.white.opacity(0.80))
                        .lineLimit(1)
                }

                Button {
                    if purchaseManager.isPro {
                        showsAIScriptWriter = true
                    } else {
                        showsPaywall = true
                    }
                } label: {
                    Label("Get Started", systemImage: "sparkles")
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

    private enum LibraryTab: String, CaseIterable, Identifiable {
        case scripts
        case folders

        var id: String { rawValue }

        var title: String {
            switch self {
            case .scripts: "Scripts"
            case .folders: "Folders"
            }
        }
    }

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            QuickActionButton(title: "Import", systemImage: "doc.text", action: importScript)
            QuickActionButton(title: "AI Script", systemImage: "sparkles") {
                if purchaseManager.isPro {
                    showsAIScript = true
                } else {
                    showsPaywall = true
                }
            }
            QuickActionButton(title: "New Folder", systemImage: "folder") {
                newFolderName = ""
                showsNewFolderAlert = true
            }
        }
    }

    private var libraryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            quickActionsRow

            libraryHeader

            if scriptStore.scripts.isEmpty {
                emptyState
            } else {
                switch libraryTab {
                case .scripts:
                    if filteredScripts.isEmpty {
                        emptyFilterState
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
                                        scriptStore.duplicate(script)
                                    },
                                    onMove: { folderID in
                                        scriptStore.move(script, toFolder: folderID)
                                    },
                                    onDelete: { scriptStore.delete(script) }
                                )
                            }
                        }
                    }
                case .folders:
                    if visibleFolders.isEmpty {
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
                        }
                    }
                }
            }
        }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsSearchField {
                HStack(spacing: 12) {
                    searchField

                    Button("Cancel") {
                        withAnimation(.snappy) {
                            showsSearchField = false
                            searchText = ""
                            isSearchFieldFocused = false
                        }
                    }
                    .font(.appHeadline)
                    .foregroundStyle(Color.creatorViolet)
                }
            } else {
                HStack(spacing: 16) {
                    Text("My Scripts")
                        .font(.appSectionTitle)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        withAnimation(.snappy) {
                            showsSearchField = true
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.5))
                    }

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
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.5))
                    }
                    .accessibilityLabel("Sort")
                }
            }

            HStack(spacing: 8) {
                ForEach(LibraryTab.allCases) { tab in
                    Button {
                        withAnimation(.snappy) {
                            libraryTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.appSubheadline)
                            .foregroundStyle(libraryTab == tab ? .white : .primary)
                            .padding(.horizontal, 20)
                            .frame(height: 36)
                            .background(
                                libraryTab == tab ? Color.creatorViolet : Color.appSurface,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search scripts", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFieldFocused)
                .onAppear { isSearchFieldFocused = true }

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
        .id(searchFieldScrollID)
    }

    private var emptyFilterState: some View {
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let itemName = libraryTab == .scripts ? "scripts" : "folders"

        return VStack(spacing: 12) {
            Image(systemName: isSearching ? "eye.slash" : "tray")
                .font(.appTitle)
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background(Color.appSurface, in: Circle())

            Text(isSearching ? "No Results" : "Nothing here yet")
                .font(.appHeadline)

            Text(
                isSearching
                    ? "No \(itemName) match \"\(searchText)\""
                    : (libraryTab == .scripts
                        ? "Create or import a script to get started."
                        : "Create a folder to organize your scripts.")
            )
            .font(.appSecondary)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("No Scripts Yet")
                    .font(.appHeadline)
                Text("Tap + to create your first script")
                    .font(.appSecondary)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }

    private func importScript() {
        showsFileImporter = true
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

/// A sketchy, hand-drawn-style curved arrow with a small loop, pointing
/// toward the bottom-trailing corner (where the tab bar's + button lives).
struct HandDrawnPointerArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.58, y: 0))
        path.addCurve(
            to: CGPoint(x: w * 0.30, y: h * 0.30),
            control1: CGPoint(x: w * 0.80, y: h * 0.06),
            control2: CGPoint(x: w * 0.58, y: h * 0.16)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.34),
            control1: CGPoint(x: w * 0.06, y: h * 0.44),
            control2: CGPoint(x: w * 0.92, y: h * 0.46)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.38, y: h * 0.20),
            control1: CGPoint(x: w * 0.58, y: h * 0.22),
            control2: CGPoint(x: w * 0.48, y: h * 0.14)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.92, y: h * 0.92),
            control1: CGPoint(x: w * 0.55, y: h * 0.42),
            control2: CGPoint(x: w * 0.76, y: h * 0.62)
        )

        let tip = CGPoint(x: w * 0.92, y: h * 0.92)
        path.move(to: CGPoint(x: tip.x - w * 0.24, y: tip.y - h * 0.04))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x - w * 0.06, y: tip.y - h * 0.26))

        return path
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

    @State private var showsDeleteConfirm = false

    private var canPrompt: Bool {
        !script.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: script.isAIPolished ? "sparkles" : "text.alignleft")
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
                    Button(role: .destructive) {
                        showsDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 30, height: 30)
                }
                .tint(.primary)
                .alert("Delete script?", isPresented: $showsDeleteConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive, action: onDelete)
                } message: {
                    Text("This will permanently delete \"\(script.displayTitle)\". This can't be undone.")
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
            .tint(.primary)
        }
        .padding(16)
        .contentCard()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onOpen)
    }
}
