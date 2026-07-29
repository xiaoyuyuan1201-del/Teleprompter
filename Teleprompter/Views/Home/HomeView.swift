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
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        welcomeHeader
                        quickStartCard
                        scriptsSection
                    }
                    .padding(.horizontal, AppLayout.screenHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Teleprompter")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !purchaseManager.isPro {
                        Button {
                            showsPaywall = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "crown.fill")
                                Text("Pro")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .tint(.creatorViolet)
                        .accessibilityLabel("Teleprompter Pro")
                    }
                }
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
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Speak clearly. Stay natural.")
                .font(.title2.bold())

            Text("Create a script, set your pace and record without looking away from the lens.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
    }

    private var quickStartCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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

            VStack(alignment: .leading, spacing: 18) {
                Label("QUICK START", systemImage: "video.fill")
                    .font(.caption.bold())
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.84))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready for your next take?")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text(latestScriptDescription)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.80))
                        .lineLimit(2)
                        .lineSpacing(2)
                }

                Button {
                    if let script = latestUsableScript {
                        activePrompt = script
                    } else {
                        createScript()
                    }
                } label: {
                    Label("Start prompting", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(Color.creatorViolet)
                        .padding(.horizontal, 16)
                        .frame(height: 46)
                        .background(
                            Color.white,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .frame(height: 228)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
        }
        .shadow(color: Color.creatorViolet.opacity(0.14), radius: 14, y: 8)
    }

    private var scriptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scripts")
                        .font(.title3.bold())
                    Text(scriptCountDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    ForEach(ScriptSortOption.allCases) { option in
                        Button {
                            scriptStore.sortOption = option
                        } label: {
                            Label(option.title, systemImage: option.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(ToolSecondaryButtonStyle(height: 36, horizontalPadding: 0))
                .accessibilityLabel("Sort scripts")

                Button {
                    createScript()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(ToolPrimaryButtonStyle(height: 36, horizontalPadding: 12))
            }

            if scriptStore.scripts.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(scriptStore.scripts) { script in
                        ScriptCard(
                            script: script,
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
                            onDelete: { scriptStore.delete(script) }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 38, height: 38)
                .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text("No scripts")
                    .font(.headline)
                Text("Create or import a script to begin recording.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
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

    private var scriptCountDescription: String {
        let draftCount = scriptStore.scripts.filter(\.isDraft).count
        let draftText = draftCount == 0 ? "" : " · \(draftCount) draft\(draftCount == 1 ? "" : "s")"
        return purchaseManager.isPro
            ? "\(scriptStore.scripts.count) scripts" + draftText
            : "\(scriptStore.scripts.count) of \(scriptStore.freeScriptLimit) free scripts" + draftText
    }

    private func createScript() {
        if scriptStore.canCreateScript(isPro: purchaseManager.isPro) {
            editorMode = .new
        } else {
            showsPaywall = true
        }
    }
}

private struct ScriptCard: View {
    let script: PromptScript
    let onEdit: () -> Void
    let onPrompt: () -> Void
    let onFavorite: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.creatorViolet)
                    .frame(width: 36, height: 36)
                    .background(
                        Color.creatorViolet.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(script.displayTitle)
                            .font(.headline)
                            .lineLimit(1)

                        if script.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(Color.creatorViolet)
                        }

                        if script.isDraft {
                            Text("DRAFT")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.35)
                                .foregroundStyle(Color.creatorViolet)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Color.creatorViolet.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                                )
                        }
                    }

                    Text(script.body.isEmpty ? "No script text yet" : script.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .lineSpacing(2)
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
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: onPrompt) {
                    Label("Prompt", systemImage: "play.fill")
                }
                .buttonStyle(ToolPrimaryButtonStyle(height: 36, horizontalPadding: 12))
                .disabled(script.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .contentCard()
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(perform: onEdit)
    }
}
