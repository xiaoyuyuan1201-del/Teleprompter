import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var scriptStore: ScriptStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var recordingStore: RecordingStore

    @State private var selectedTab: AppTab = .home
    @State private var showsQuickActions = false
    @State private var showsScriptEditor = false
    @State private var editingScript: PromptScript?
    @State private var showsPaywall = false
    @State private var showsFileImporter = false
    @State private var importError: String?
    @State private var showsNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showsNewVideoFolderAlert = false
    @State private var newVideoFolderName = ""
    @State private var showsAIScript = false
    @State private var showsAIScriptWriter = false

    private enum AppTab: Hashable {
        case home
        case videos
        case mine
    }

    private enum QuickAction: String, CaseIterable, Identifiable {
        case newVideoFolder
        case newFolder
        case aiScriptWriter
        case aiScript
        case importFile
        case newScript

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newVideoFolder: "New Video Folder"
            case .newFolder: "New Folder"
            case .aiScriptWriter: "Write a New Script"
            case .aiScript: "AI Script"
            case .importFile: "Import File"
            case .newScript: "New Script"
            }
        }

        var systemImage: String {
            switch self {
            case .newVideoFolder: "play.rectangle.fill"
            case .newFolder: "folder.fill"
            case .aiScriptWriter: "wand.and.stars"
            case .aiScript: "sparkles"
            case .importFile: "square.and.arrow.up.fill"
            case .newScript: "pencil.and.scribble"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(AppTab.home)
                    .tabItem {
                        Label("Home", systemImage: selectedTab == .home ? "house.fill" : "house")
                    }

                VideosView(onGoToHome: { selectedTab = .home })
                    .tag(AppTab.videos)
                    .tabItem {
                        Label("Videos", systemImage: selectedTab == .videos ? "play.rectangle.fill" : "play.rectangle")
                    }

                MineView()
                    .tag(AppTab.mine)
                    .tabItem {
                        Label("Settings", systemImage: selectedTab == .mine ? "gearshape.fill" : "gearshape")
                    }
            }
            .tint(.creatorViolet)

            if selectedTab == .home && scriptStore.scripts.isEmpty {
                HandDrawnPointerArrow()
                    .stroke(Color.primary.opacity(0.65), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 80, height: 130)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 40)
                    .padding(.bottom, 66)
                    .allowsHitTesting(false)
                    .ignoresSafeArea(.container, edges: .bottom)
            }

            HStack {
                Spacer()
                fabButton
                    .padding(.trailing, 16)
            }
            .padding(.bottom, 8)
            .ignoresSafeArea(.container, edges: .bottom)

            if showsQuickActions {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.snappy) { showsQuickActions = false }
                    }
                    .transition(.opacity)

                VStack(spacing: 16) {
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
        .alert("New video folder", isPresented: $showsNewVideoFolderAlert) {
            TextField("Folder name", text: $newVideoFolderName)
            Button("Cancel", role: .cancel) {
                newVideoFolderName = ""
            }
            Button("Create") {
                recordingStore.createFolder(name: newVideoFolderName)
                newVideoFolderName = ""
            }
        } message: {
            Text("Give your folder a name to help sort your videos.")
        }
    }

    private var fabButton: some View {
        Button {
            withAnimation(.snappy) {
                showsQuickActions.toggle()
            }
        } label: {
            Image(systemName: showsQuickActions ? "xmark" : "plus")
                .font(.appHeadline)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(
                        colors: [.creatorViolet, .creatorVioletLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: Color.creatorViolet.opacity(0.35), radius: 8, y: 3)
        }
        .accessibilityLabel(showsQuickActions ? "Close quick actions" : "Quick actions")
    }

    private var quickActionMenu: some View {
        VStack(spacing: 12) {
            ForEach(QuickAction.allCases) { action in
                Button {
                    perform(action)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: action.systemImage)
                            .font(.appSubheadline)
                            .foregroundStyle(Color.creatorViolet)
                            .frame(width: 34, height: 34)
                            .background(Color.creatorViolet.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Text(action.title)
                            .font(.appSubheadline)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 72)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        case .newVideoFolder:
            newVideoFolderName = ""
            showsNewVideoFolderAlert = true
        case .newFolder:
            newFolderName = ""
            showsNewFolderAlert = true
        case .aiScriptWriter:
            if purchaseManager.isPro {
                showsAIScriptWriter = true
            } else {
                showsPaywall = true
            }
        case .aiScript:
            if purchaseManager.isPro {
                showsAIScript = true
            } else {
                showsPaywall = true
            }
        case .importFile:
            showsFileImporter = true
        case .newScript:
            showsScriptEditor = true
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
