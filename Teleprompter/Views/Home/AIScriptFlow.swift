import SwiftUI

/// The "Write with AI" flow: type or paste a script, pick a polishing style,
/// watch AI refine it, then review and compare the result before saving.
struct AIScriptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = AIPolishService()

    let onUse: (String, String, Bool) -> Void

    @State private var scriptTitle = ""
    @State private var rawText = ""
    @State private var polishedText = ""
    @State private var selectedStyle: PolishStyle = .casual
    @State private var step: Step = .input
    @State private var showsStyleSelect = false
    @State private var showsDiffHighlight = false
    @State private var hasUnsavedChanges = false
    @State private var showsUnsavedChangesAlert = false
    @FocusState private var focusedField: Field?

    private enum Step {
        case input
        case polishing
        case result
    }

    private enum Field {
        case title
        case body
    }

    private var wordCount: Int {
        Self.wordCount(for: rawText)
    }

    private var estimatedMinutes: Int {
        Self.estimatedMinutes(for: wordCount)
    }

    private var hasTitle: Bool {
        !scriptTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canStartPolishing: Bool {
        hasTitle && !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSaveDraft: Bool {
        hasTitle && !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSavePolished: Bool {
        hasTitle && !polishedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func wordCount(for text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private static func estimatedMinutes(for wordCount: Int) -> Int {
        max(1, Int(ceil(Double(wordCount) / 140.0)))
    }

    private var reductionPercent: Int? {
        let originalWords = rawText.split(whereSeparator: \.isWhitespace).count
        let polishedWords = polishedText.split(whereSeparator: \.isWhitespace).count
        guard originalWords > 0, polishedWords < originalWords else { return nil }
        return Int(((1 - Double(polishedWords) / Double(originalWords)) * 100).rounded())
    }

    private func requestClose() {
        if hasUnsavedChanges {
            showsUnsavedChangesAlert = true
        } else {
            dismiss()
        }
    }

    private func saveDraft() {
        guard canSaveDraft else { return }
        onUse(scriptTitle, rawText, false)
        dismiss()
    }

    private func savePolished() {
        guard canSavePolished else { return }
        onUse(scriptTitle, polishedText, true)
        dismiss()
    }

    private func startPolishing() {
        showsStyleSelect = false
        withAnimation(.snappy) { step = .polishing }

        Task {
            // TEMPORARY TEST STUB: Apple Intelligence isn't available in the
            // simulator, so fall back to placeholder text instead of bailing
            // out — lets the polishing/result/compare screens be tested
            // end-to-end. Remove this fallback once testing is done.
            let result = await service.polish(rawText, style: selectedStyle) ?? "hahahahha"
            polishedText = result
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
                case .polishing:
                    polishingStep
                case .result:
                    resultStep
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .onChange(of: scriptTitle) { _, _ in hasUnsavedChanges = true }
        .onChange(of: rawText) { _, _ in
            hasUnsavedChanges = true
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .alert("Discard changes?", isPresented: $showsUnsavedChangesAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You haven't saved your changes yet.")
        }
        .sheet(isPresented: $showsStyleSelect) {
            StyleSelectSheet(selectedStyle: $selectedStyle, onConfirm: startPolishing)
        }
        .alert("AI Polish", isPresented: Binding(
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
        case .input, .polishing: "AI Script"
        case .result: "Polish Result"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        switch step {
        case .input:
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { requestClose() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveDraft() }
                    .fontWeight(.semibold)
                    .disabled(!canSaveDraft)
            }
        case .polishing:
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
                Button("Save") { savePolished() }
                    .fontWeight(.semibold)
                    .disabled(!canSavePolished)
            }
        }
    }

    // MARK: - Input

    private var inputStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    StatPill(icon: "text.word.spacing", text: "\(wordCount) words")
                    StatPill(icon: "clock", text: "About \(estimatedMinutes) min")
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionEyebrow(title: "Script")

                    noteCard
                }

                tipCallout

                if let error = service.errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundStyle(.orange)
                }

                Button {
                    focusedField = nil
                    showsStyleSelect = true
                } label: {
                    VioletGlassButtonLabel(title: "Choose Style & Start Polishing", systemImage: "sparkles")
                }
                .buttonStyle(ToolPrimaryButtonStyle())
                .tint(.creatorViolet)
                .disabled(!canStartPolishing)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.immediately)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
    }

    // A single note-style card: title flows straight into the body, like
    // Apple Notes, instead of separate title/body boxes.
    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Script title", text: $scriptTitle)
                .font(.appHeadline)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .body
                }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $rawText)
                    .font(.appBody)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(.leading, -5)
                    .focused($focusedField, equals: .body)

                if rawText.isEmpty {
                    Text("Paste or write your script here...")
                        .font(.appBody)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(16)
        .contentCard()
    }

    private var tipCallout: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color.creatorViolet)
            Text("After you're done writing, pick a style — Formal, Academic, Literary, and more — and AI will refine the wording and pacing.")
                .font(.appSecondary)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.creatorViolet.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Polishing

    private var polishingStep: some View {
        VStack(spacing: 28) {
            Spacer()

            PolishingAnimationView()

            VStack(spacing: 8) {
                Text("AI is polishing...")
                    .font(.appTitle)
                Text("Hang tight — we're refining tone and pacing for you. This usually takes a few seconds.")
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
        let diff = WordDiff(before: rawText, after: polishedText)

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    if let reductionPercent {
                        Text("Trimmed \(reductionPercent)% of filler words")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        withAnimation(.snappy) { showsDiffHighlight.toggle() }
                    } label: {
                        Text(showsDiffHighlight ? "Hide Changes" : "Highlight Changes")
                            .font(.appCaptionEmphasis)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.creatorViolet)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionEyebrow(title: "Before Polishing")

                    HStack(spacing: 12) {
                        StatPill(icon: "text.word.spacing", text: "\(Self.wordCount(for: rawText)) words")
                        StatPill(icon: "clock", text: "About \(Self.estimatedMinutes(for: Self.wordCount(for: rawText))) min")
                    }

                    Group {
                        if showsDiffHighlight {
                            diff.beforeText
                        } else {
                            Text(rawText)
                        }
                    }
                    .font(.appBody)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
                    .contentCard()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionEyebrow(title: "After Polishing")
                        Spacer()
                        Button {
                            showsStyleSelect = true
                        } label: {
                            HStack(spacing: 4) {
                                Label(selectedStyle.title, systemImage: selectedStyle.systemImage)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .font(.appCaptionEmphasis)
                            .foregroundStyle(Color.creatorViolet)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Color.creatorViolet.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 12) {
                        StatPill(icon: "text.word.spacing", text: "\(Self.wordCount(for: polishedText)) words")
                        StatPill(icon: "clock", text: "About \(Self.estimatedMinutes(for: Self.wordCount(for: polishedText))) min")
                    }

                    Group {
                        if showsDiffHighlight {
                            diff.afterText
                        } else {
                            Text(polishedText)
                        }
                    }
                    .font(.appBody)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.creatorViolet.opacity(0.6), lineWidth: 1.5)
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Spelling checked, sentence flow reorganized, and wording made more natural.")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    withAnimation(.snappy) { step = .input }
                } label: {
                    Label("Edit Again", systemImage: "pencil")
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

/// A modal style picker: pick the tone AI should polish toward, then confirm.
struct StyleSelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStyle: PolishStyle
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose a Polishing Style")
                                .font(.appTitle)
                            Text("Pick the tone that fits how you'll use this script.")
                                .font(.appSecondary)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 12) {
                            ForEach(PolishStyle.allCases) { style in
                                let isSelected = selectedStyle == style
                                Button {
                                    selectedStyle = style
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: style.systemImage)
                                            .font(.appHeadline)
                                            .foregroundStyle(isSelected ? Color.white : Color.creatorViolet)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                isSelected ? Color.creatorViolet : Color.creatorViolet.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(style.title)
                                                .font(.appSubheadline)
                                                .foregroundStyle(.primary)
                                            Text(style.subtitle)
                                                .font(.appCaption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.creatorViolet)
                                        }
                                    }
                                    .padding(14)
                                    .contentCard()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }

                VStack {
                    Spacer()
                    Button {
                        dismiss()
                        onConfirm()
                    } label: {
                        VioletGlassButtonLabel(title: "Confirm & Polish", systemImage: "sparkles")
                    }
                    .buttonStyle(ToolPrimaryButtonStyle())
                    .tint(.creatorViolet)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

/// A centered, looping sparkles glyph orbited by three small dots — the
/// "AI is thinking" moment between submitting text and seeing a result.
struct PolishingAnimationView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.creatorViolet.opacity(0.12))
                .frame(width: 140, height: 140)

            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.creatorViolet)
                .scaleEffect(isAnimating ? 1.08 : 0.92)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: 12, height: 12)
                    .offset(y: -80)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0) + .degrees(Double(index) * 120))
            }
        }
        .frame(height: 180)
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isAnimating)
    }

    private func dotColor(for index: Int) -> Color {
        switch index {
        case 0: Color.creatorViolet
        case 1: Color.green
        default: Color.orange
        }
    }
}

/// Three dots that bounce in sequence beneath the polishing message.
struct BouncingDotsView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.creatorViolet)
                    .frame(width: 8, height: 8)
                    .opacity(isAnimating ? 1 : 0.25)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}

/// A simple word-level diff between the original and polished script, used to
/// highlight what changed on the compare screen.
private struct WordDiff {
    private let beforeWords: [Substring]
    private let afterWords: [Substring]
    private let removedIndices: Set<Int>
    private let insertedIndices: Set<Int>

    init(before: String, after: String) {
        beforeWords = before.split(whereSeparator: \.isWhitespace)
        afterWords = after.split(whereSeparator: \.isWhitespace)

        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in afterWords.difference(from: beforeWords) {
            switch change {
            case .remove(let offset, _, _):
                removed.insert(offset)
            case .insert(let offset, _, _):
                inserted.insert(offset)
            }
        }
        removedIndices = removed
        insertedIndices = inserted
    }

    var beforeText: Text {
        Self.buildText(words: beforeWords, highlighted: removedIndices) { text in
            text.strikethrough().foregroundStyle(.red)
        }
    }

    var afterText: Text {
        Self.buildText(words: afterWords, highlighted: insertedIndices) { text in
            text.foregroundStyle(Color.creatorViolet).fontWeight(.semibold)
        }
    }

    private static func buildText(words: [Substring], highlighted: Set<Int>, style: (Text) -> Text) -> Text {
        words.enumerated().reduce(Text("")) { partial, pair in
            let (index, word) = pair
            let separator = index == words.count - 1 ? "" : " "
            let segment = Text(String(word) + separator)
            return partial + (highlighted.contains(index) ? style(segment) : segment)
        }
    }
}
