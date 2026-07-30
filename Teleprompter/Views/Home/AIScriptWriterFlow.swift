import SwiftUI

/// The "Write a New Script" flow: give AI a topic, pick a tone, and it drafts
/// a complete, ready-to-read script from scratch — no source text required.
struct AIScriptWriterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = AIPolishService()

    let onUse: (String, String, Bool) -> Void

    @State private var scriptTitle = ""
    @State private var topic = ""
    @State private var generatedText = ""
    @State private var selectedStyle: PolishStyle = .casual
    @State private var step: Step = .input
    @State private var showsStyleSelect = false
    @State private var hasUnsavedChanges = false
    @State private var showsUnsavedChangesAlert = false
    @FocusState private var focusedField: Field?

    private enum Step {
        case input
        case generating
        case result
    }

    private enum Field {
        case title
        case topic
    }

    private var hasTitle: Bool {
        !scriptTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canGenerate: Bool {
        hasTitle && !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool {
        hasTitle && !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var wordCount: Int {
        generatedText.split(whereSeparator: \.isWhitespace).count
    }

    private var estimatedMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 140.0)))
    }

    private func requestClose() {
        if hasUnsavedChanges {
            showsUnsavedChangesAlert = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard canSave else { return }
        onUse(scriptTitle, generatedText, false)
        dismiss()
    }

    private func startGenerating() {
        showsStyleSelect = false
        withAnimation(.snappy) { step = .generating }

        Task {
            // TEMPORARY TEST STUB: Apple Intelligence isn't available in the
            // simulator, so fall back to placeholder text instead of bailing
            // out. Remove this fallback once testing is done.
            let result = await service.write(topic: topic, style: selectedStyle) ?? "hahahahha"
            generatedText = result
            hasUnsavedChanges = true
            withAnimation(.snappy) { step = .result }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                switch step {
                case .input:
                    inputStep
                case .generating:
                    generatingStep
                case .result:
                    resultStep
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .onChange(of: scriptTitle) { _, _ in hasUnsavedChanges = true }
        .onChange(of: topic) { _, _ in hasUnsavedChanges = true }
        .onChange(of: generatedText) { _, _ in hasUnsavedChanges = true }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .alert("Discard changes?", isPresented: $showsUnsavedChangesAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You haven't saved your changes yet.")
        }
        .sheet(isPresented: $showsStyleSelect) {
            StyleSelectSheet(selectedStyle: $selectedStyle, onConfirm: startGenerating)
        }
        .alert("Write with AI", isPresented: Binding(
            get: { service.errorMessage != nil },
            set: { if !$0 { service.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { service.errorMessage = nil }
        } message: {
            Text(service.errorMessage ?? "")
        }
    }

    private var navigationTitle: String {
        switch step {
        case .input, .generating: "Write a New Script"
        case .result: "Your Script"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        switch step {
        case .input:
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { requestClose() }
            }
        case .generating:
            ToolbarItem(placement: .cancellationAction) {
                EmptyView()
            }
        case .result:
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    withAnimation(.snappy) { step = .input }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
    }

    // MARK: - Input

    private var inputStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                TextField("Script title", text: $scriptTitle)
                    .font(.appHeadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .contentCard(cornerRadius: 16)
                    .focused($focusedField, equals: .title)

                VStack(alignment: .leading, spacing: 12) {
                    SectionEyebrow(title: "Topic")

                    TextEditor(text: $topic)
                        .font(.appBody)
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                        .padding(12)
                        .contentCard()
                        .focused($focusedField, equals: .topic)
                        .overlay(alignment: .topLeading) {
                            if topic.isEmpty {
                                Text("e.g. \"How to brew the perfect cup of coffee at home\"")
                                    .font(.appBody)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                if let error = service.errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundStyle(.orange)
                }

                Button {
                    focusedField = nil
                    showsStyleSelect = true
                } label: {
                    VioletGlassButtonLabel(title: "Choose Style & Generate", systemImage: "sparkles")
                }
                .buttonStyle(ToolPrimaryButtonStyle())
                .tint(.creatorViolet)
                .disabled(!canGenerate)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.immediately)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
    }

    // MARK: - Generating

    private var generatingStep: some View {
        VStack(spacing: 28) {
            Spacer()

            PolishingAnimationView()

            VStack(spacing: 8) {
                Text("AI is writing...")
                    .font(.appTitle)
                Text("Hang tight — we're drafting your script. This usually takes a few seconds.")
                    .font(.appSecondary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            BouncingDotsView()

            Spacer()
        }
    }

    // MARK: - Result

    private var resultStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Label(selectedStyle.title, systemImage: selectedStyle.systemImage)
                    .font(.appCaptionEmphasis)
                    .foregroundStyle(Color.creatorViolet)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color.creatorViolet.opacity(0.12), in: Capsule())

                HStack(spacing: 12) {
                    StatPill(icon: "text.word.spacing", text: "\(wordCount) words")
                    StatPill(icon: "clock", text: "About \(estimatedMinutes) min")
                }

                TextEditor(text: $generatedText)
                    .font(.appBody)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 280)
                    .padding(12)
                    .contentCard()

                Button {
                    withAnimation(.snappy) { step = .input }
                } label: {
                    Label("Try a Different Topic", systemImage: "arrow.counterclockwise")
                        .font(.appHeadline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(ToolSecondaryButtonStyle())
                .tint(.creatorViolet)
            }
            .padding(20)
        }
    }
}
