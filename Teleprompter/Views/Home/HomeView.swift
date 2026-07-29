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
                    LazyVStack(alignment: .leading, spacing: 24) {
                        welcomeHeader
                        quickStartCard
                        scriptsSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
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
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.creatorViolet, .creatorVioletLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.11))
                .frame(width: 220, height: 220)
                .offset(x: 210, y: -80)

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 120, height: 120)
                .offset(x: 280, y: 90)

            VStack(alignment: .leading, spacing: 18) {
                Label("QUICK START", systemImage: "video.fill")
                    .font(.caption.bold())
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.84))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready for your next take?")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text("Open your latest script and start prompting instantly.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineSpacing(2)
                }

                Button {
                    if let script = scriptStore.scripts.filter({ !$0.body.isEmpty }).max(by: { $0.updatedAt < $1.updatedAt }) {
                        activePrompt = script
                    } else {
                        createScript()
                    }
                } label: {
                    Label("Start prompting", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                }
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(Color.creatorViolet)
            }
            .padding(24)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.creatorViolet.opacity(0.20), radius: 24, y: 14)
    }

    private var scriptsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your scripts")
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
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Sort scripts")

                Button {
                    createScript()
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .tint(.creatorViolet)
            }

            if scriptStore.scripts.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
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
        VStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.creatorViolet)

            Text("Create your first script")
                .font(.headline)

            Text("Paste or import what you want to say, then open the camera and start prompting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("New script") {
                createScript()
            }
            .buttonStyle(.glassProminent)
            .tint(.creatorViolet)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .contentCard(cornerRadius: 26)
    }

    private var scriptCountDescription: String {
        let draftCount = scriptStore.scripts.filter(\.isDraft).count
        let draftText = draftCount == 0 ? "" : " · \(draftCount) draft\(draftCount == 1 ? "" : "s")"
        return purchaseManager.isPro
            ? "Unlimited scripts with Pro" + draftText
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.creatorViolet)
                    .frame(width: 46, height: 46)
                    .background(Color.creatorViolet.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
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
                                .tracking(0.4)
                                .foregroundStyle(Color.creatorViolet)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.creatorViolet.opacity(0.10), in: Capsule())
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
                        .frame(width: 32, height: 32)
                }
            }

            Divider()

            HStack {
                HStack(spacing: 13) {
                    Label("\(script.wordCount) words", systemImage: "text.word.spacing")
                    Label("~\(script.estimatedMinutes) min", systemImage: "clock")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: onPrompt) {
                    Label("Prompt", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .tint(.creatorViolet)
                .disabled(script.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(17)
        .contentCard(cornerRadius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onEdit)
    }
}
