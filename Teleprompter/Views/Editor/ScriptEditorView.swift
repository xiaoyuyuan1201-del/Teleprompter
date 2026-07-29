import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ScriptEditorView: View {
    @EnvironmentObject private var scriptStore: ScriptStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private let existingScript: PromptScript?
    private let workingID: UUID
    private let createdAt: Date
    private let folderID: UUID?

    @State private var title: String
    @State private var bodyText: String
    @State private var sourceFileName: String?
    @State private var showsPaywall = false
    @State private var showsFileImporter = false
    @State private var showsAIPolish = false
    @State private var importError: String?
    @State private var autosaveTask: Task<Void, Never>?
    @State private var autosaveLabel = ""
    @State private var hasUnsavedChanges = false
    @State private var showsUnsavedChangesAlert = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case body
    }

    init(script: PromptScript?, folderID: UUID? = nil) {
        existingScript = script
        workingID = script?.id ?? UUID()
        createdAt = script?.createdAt ?? .now
        self.folderID = script?.folderID ?? folderID
        _title = State(initialValue: script?.title ?? "")
        _bodyText = State(initialValue: script?.body ?? "")
        _sourceFileName = State(initialValue: script?.sourceFileName)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    statusRow
                    titleSection
                    scriptSection
                }
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(existingScript == nil ? "New Script" : "Edit Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    requestClose()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    finalizeScript()
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .onAppear {
            if existingScript == nil {
                focusedField = .title
            }
        }
        .onDisappear {
            autosaveTask?.cancel()
        }
        .onChange(of: title) { _, _ in
            hasUnsavedChanges = true
            scheduleAutosave()
        }
        .onChange(of: bodyText) { _, _ in
            hasUnsavedChanges = true
            scheduleAutosave()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                flushDraftIfNeeded()
            }
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: DocumentImportService.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(source: .inApp)
                .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $showsAIPolish) {
            AIPolishSheet(originalText: bodyText) { polished in
                bodyText = polished
                focusedField = .body
            }
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
        .alert("Discard changes?", isPresented: $showsUnsavedChangesAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You haven't saved your changes yet.")
        }
    }

    private var statusRow: some View {
        let preview = PromptScript(title: title, body: bodyText)

        return HStack(spacing: 10) {
            StatPill(icon: "text.word.spacing", text: "\(preview.wordCount) words")
            StatPill(icon: "clock", text: "About \(preview.estimatedMinutes) min")

            Spacer()

            if !autosaveLabel.isEmpty {
                Label(autosaveLabel, systemImage: autosaveLabel == "Saved" ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: autosaveLabel)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                SectionEyebrow(title: "Title")
                Spacer()
                if existingScript?.isDraft == true || existingScript == nil {
                    Text("DRAFT")
                        .font(.caption2.bold())
                        .tracking(0.5)
                        .foregroundStyle(Color.creatorViolet)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }

            TextField("Give your script a name", text: $title)
                .font(.title3.weight(.semibold))
                .textInputAutocapitalization(.sentences)
                .focused($focusedField, equals: .title)
                .padding(18)
                .contentCard()
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .body
                }
        }
    }

    private var scriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SectionEyebrow(title: "Script")

                Spacer()

                Menu {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }

                    Button {
                        focusedField = nil
                        showsFileImporter = true
                    } label: {
                        Label("Import TXT or PDF", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Label("Import", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(ToolSecondaryButtonStyle())

                Button {
                    focusedField = nil
                    if purchaseManager.isPro {
                        showsAIPolish = true
                    } else {
                        showsPaywall = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("AI Polish")
                        if !purchaseManager.isPro {
                            Text("PRO")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.4)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.creatorViolet.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(ToolSecondaryButtonStyle())
                .tint(.creatorViolet)
                .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("AI Polish")
                .accessibilityHint(purchaseManager.isPro ? "Opens script polishing options" : "Opens Teleprompter Pro membership options")
            }

            if let sourceFileName {
                Label(sourceFileName, systemImage: "doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $bodyText)
                    .font(.body)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .body)
                    .padding(12)
                    .frame(minHeight: 430)
                    .contentCard()

                if bodyText.isEmpty {
                    Text("Paste, import, or write what you want to say...")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 22)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var workingScript: PromptScript {
        PromptScript(
            id: workingID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt,
            updatedAt: .now,
            isFavorite: existingScript?.isFavorite ?? false,
            isDraft: true,
            sourceFileName: sourceFileName,
            folderID: folderID
        )
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        guard canSave else {
            autosaveLabel = ""
            return
        }

        autosaveLabel = "Saving"
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            scriptStore.autosave(workingScript)
            autosaveLabel = "Saved"
        }
    }

    private func requestClose() {
        if hasUnsavedChanges {
            showsUnsavedChangesAlert = true
        } else {
            dismiss()
        }
    }

    private func flushDraftIfNeeded() {
        autosaveTask?.cancel()
        guard hasUnsavedChanges, canSave else { return }
        scriptStore.autosave(workingScript)
    }

    private func finalizeScript() {
        autosaveTask?.cancel()
        guard canSave else { return }
        var final = workingScript
        final.isDraft = false
        scriptStore.finalize(final)
        dismiss()
    }

    private func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            importError = "There is no text on the clipboard."
            return
        }
        if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bodyText = text
        } else {
            bodyText += "\n\n" + text
        }
        focusedField = .body
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let imported = try DocumentImportService.read(from: url)
            sourceFileName = imported.fileName
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = imported.title
            }
            if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bodyText = imported.text
            } else {
                bodyText += "\n\n" + imported.text
            }
            focusedField = .body
        } catch {
            importError = error.localizedDescription
        }
    }
}

private struct AIPolishSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var service = AIPolishService()

    let originalText: String
    let onApply: (String) -> Void

    @State private var selectedStyle: PolishStyle = .conversational
    @State private var polishedText = ""
    @State private var previewMode = PreviewMode.original

    private enum PreviewMode: String, CaseIterable, Identifiable {
        case original = "Before"
        case polished = "After"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Choose how to improve it")
                                .font(.title2.bold())
                            Text("Your original text stays available until you apply the result.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 10) {
                            ForEach(PolishStyle.allCases) { style in
                                Button {
                                    selectedStyle = style
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: style.systemImage)
                                            .font(.title3)
                                        Text(style.title)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(selectedStyle == style ? Color.white : Color.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 78)
                                    .background(
                                        selectedStyle == style ? Color.creatorViolet : Color.appSurface,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !polishedText.isEmpty {
                            Picker("Preview", selection: $previewMode) {
                                ForEach(PreviewMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Text(previewMode == .polished && !polishedText.isEmpty ? polishedText : originalText)
                            .font(.body)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
                            .padding(18)
                            .contentCard()

                        Button {
                            Task {
                                if let result = await service.polish(originalText, style: selectedStyle) {
                                    polishedText = result
                                    previewMode = .polished
                                }
                            }
                        } label: {
                            VioletGlassButtonLabel(
                                title: service.isProcessing ? "Polishing..." : "Polish script",
                                systemImage: service.isProcessing ? nil : "sparkles"
                            )
                            .overlay(alignment: .leading) {
                                if service.isProcessing {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.leading, 18)
                                }
                            }
                        }
                        .buttonStyle(ToolPrimaryButtonStyle())
                        .tint(.creatorViolet)
                        .disabled(service.isProcessing)

                        if !polishedText.isEmpty {
                            Button {
                                onApply(polishedText)
                                dismiss()
                            } label: {
                                Label("Use polished version", systemImage: "checkmark")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            }
                            .buttonStyle(ToolSecondaryButtonStyle())
                            .tint(.creatorViolet)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("AI Polish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .alert("AI Polish", isPresented: Binding(
            get: { service.errorMessage != nil },
            set: { if !$0 { service.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                service.errorMessage = nil
            }
        } message: {
            Text(service.errorMessage ?? "")
        }
    }
}

private struct StatPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.creatorViolet)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
