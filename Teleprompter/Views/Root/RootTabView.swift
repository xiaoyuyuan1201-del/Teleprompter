import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var scriptStore: ScriptStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var recordingStore: RecordingStore

    @State private var selectedTab: AppTab = .home
    @State private var lastRealTab: AppTab = .home
    @State private var showsQuickActions = false
    @State private var showsScriptEditor = false
    @State private var editingScript: PromptScript?
    @State private var freeformScript: PromptScript?
    @State private var showsPaywall = false
    @State private var showsFileImporter = false
    @State private var importError: String?
    @State private var showsNewFolderAlert = false
    @State private var newFolderName = ""

    private enum AppTab: Hashable {
        case home
        case videos
        case add
        case mine
    }

    private enum QuickAction: String, CaseIterable, Identifiable {
        case newFolder
        case recordWithoutScript
        case importFile
        case newScript

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newFolder: "New Folder"
            case .recordWithoutScript: "Record Without Script"
            case .importFile: "Import File"
            case .newScript: "New Script"
            }
        }

        var systemImage: String {
            switch self {
            case .newFolder: "folder.fill"
            case .recordWithoutScript: "video.fill"
            case .importFile: "square.and.arrow.up.fill"
            case .newScript: "pencil.and.scribble"
            }
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(AppTab.home)
                    .tabItem {
                        Label("Home", systemImage: selectedTab == .home ? "house.fill" : "house")
                    }

                VideosView()
                    .tag(AppTab.videos)
                    .tabItem {
                        Label("Videos", systemImage: selectedTab == .videos ? "play.rectangle.fill" : "play.rectangle")
                    }

                Color.clear
                    .tag(AppTab.add)
                    .tabItem {
                        Label("Add", systemImage: "plus.circle.fill")
                    }

                MineView()
                    .tag(AppTab.mine)
                    .tabItem {
                        Label("Mine", systemImage: selectedTab == .mine ? "person.crop.circle.fill" : "person.crop.circle")
                    }
            }
            .tint(.creatorViolet)
            .onChange(of: selectedTab) { _, newValue in
                if newValue == .add {
                    selectedTab = lastRealTab
                    withAnimation(.snappy) { showsQuickActions = true }
                } else {
                    lastRealTab = newValue
                }
            }

            if showsQuickActions {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.snappy) { showsQuickActions = false }
                    }
                    .transition(.opacity)

                VStack(spacing: 14) {
                    Spacer()
                    quickActionMenu
                    Spacer()
                }
                .padding(.bottom, 60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showsScriptEditor) {
            NavigationStack {
                ScriptEditorView(script: nil)
            }
            .environmentObject(scriptStore)
            .environmentObject(purchaseManager)
        }
        .sheet(item: $editingScript) { script in
            NavigationStack {
                ScriptEditorView(script: scriptStore.script(with: script.id) ?? script)
            }
            .environmentObject(scriptStore)
            .environmentObject(purchaseManager)
        }
        .fullScreenCover(item: $freeformScript) { script in
            TeleprompterView(script: script)
                .environmentObject(purchaseManager)
                .environmentObject(recordingStore)
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(source: .inApp)
                .environmentObject(purchaseManager)
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
        .alert("New folder", isPresented: $showsNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                scriptStore.createFolder(name: newFolderName)
                newFolderName = ""
            }
        } message: {
            Text("Give your folder a name to help sort your scripts.")
        }
    }

    private var quickActionMenu: some View {
        VStack(spacing: 10) {
            ForEach(QuickAction.allCases) { action in
                Button {
                    perform(action)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: action.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.creatorViolet)
                            .frame(width: 34, height: 34)
                            .background(Color.creatorViolet.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(action.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppLayout.screenHorizontalPadding)
    }

    private func perform(_ action: QuickAction) {
        withAnimation(.snappy) {
            showsQuickActions = false
        }

        switch action {
        case .newFolder:
            newFolderName = ""
            showsNewFolderAlert = true
        case .recordWithoutScript:
            freeformScript = PromptScript(title: "", body: "")
        case .importFile:
            if scriptStore.canCreateScript(isPro: purchaseManager.isPro) {
                showsFileImporter = true
            } else {
                showsPaywall = true
            }
        case .newScript:
            if scriptStore.canCreateScript(isPro: purchaseManager.isPro) {
                showsScriptEditor = true
            } else {
                showsPaywall = true
            }
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
            editingScript = script
        } catch {
            importError = error.localizedDescription
        }
    }
}
