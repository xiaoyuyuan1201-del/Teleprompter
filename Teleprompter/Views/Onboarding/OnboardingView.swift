import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @AppStorage("onboardingUseCase") private var useCase = OnboardingUseCase.creator.rawValue
    @AppStorage("onboardingDistance") private var recordingDistance = RecordingDistance.tripod.rawValue
    @AppStorage("defaultPromptFontSize") private var defaultFontSize = 48.0
    @AppStorage("defaultPromptSpeed") private var defaultPromptSpeed = 44.0
    @AppStorage("defaultCountdownEnabled") private var countdownEnabled = true
    @AppStorage("defaultPromptFocusNearLens") private var focusNearLens = true

    @State private var step: OnboardingStep = .welcome
    @State private var showsPaywall = false

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    stepContent
                        .frame(maxWidth: 620)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                }
                .scrollBounceBehavior(.basedOnSize)

                bottomAction
            }
        }
        .animation(.snappy(duration: 0.38), value: step)
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(source: .onboarding) {
                showsPaywall = false
                onComplete()
            }
            .environmentObject(purchaseManager)
        }
    }

    private var header: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                if step != .welcome {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.appSubheadline)
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Back")
                } else {
                    Color.clear
                        .frame(width: 42, height: 42)
                }

                Spacer(minLength: 0)

                OnboardingProgress(
                    count: OnboardingStep.allCases.count,
                    selection: step.rawValue
                )
                .frame(width: 160, height: 5)

                Spacer(minLength: 0)

                Color.clear
                    .frame(width: 42, height: 42)
            }

            VStack(spacing: 8) {
                if let headerEyebrow {
                    Text(headerEyebrow)
                        .font(.appCaptionEmphasis)
                        .tracking(1)
                        .foregroundStyle(Color.creatorViolet)
                }

                Text(headerTitle)
                    .font(.appTitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.84)
                    .frame(maxWidth: 520)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, AppLayout.screenHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color.appCanvas)
    }

    private var headerTitle: String {
        switch step {
        case .welcome:
            return "Your words. Naturally delivered."
        case .eyeContact:
            return "Keep your eyes near the lens"
        case .smoothTake:
            return "Record while the words move with you"
        case .useCase:
            return "What will you use Teleprompter for?"
        case .distance:
            return "How far will the screen usually be?"
        case .fontSize:
            return "Choose a comfortable text size"
        case .pace:
            return "Set your natural speaking pace"
        case .preferences:
            return "A few finishing preferences"
        case .ready:
            return "Your setup is ready"
        }
    }

    private var headerEyebrow: String? {
        switch step {
        case .welcome:
            return "TELEPROMPTER"
        case .eyeContact:
            return "READ NATURALLY"
        case .smoothTake:
            return "ONE SMOOTH TAKE"
        case .useCase:
            return "SETUP 1 OF 5"
        case .distance:
            return "SETUP 2 OF 5"
        case .fontSize:
            return "SETUP 3 OF 5"
        case .pace:
            return "SETUP 4 OF 5"
        case .preferences:
            return "SETUP 5 OF 5"
        case .ready:
            return "PERSONALIZED FOR YOU"
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            WelcomeStep()
                .transition(stepTransition)

        case .eyeContact:
            FeatureStep(
                eyebrow: "READ NATURALLY",
                title: "Keep your eyes near the lens",
                message: "Your script stays close to the camera so your delivery feels direct, relaxed and confident.",
                visual: .eyeContact
            )
            .transition(stepTransition)

        case .smoothTake:
            FeatureStep(
                eyebrow: "ONE SMOOTH TAKE",
                title: "Record while the words move with you",
                message: "Set a comfortable pace, pause whenever you need and stay focused on what you want to say.",
                visual: .recording
            )
            .transition(stepTransition)

        case .useCase:
            UseCaseStep(selection: $useCase)
                .transition(stepTransition)

        case .distance:
            DistanceStep(
                selection: $recordingDistance,
                onSelect: applyRecommendedFontSize
            )
            .transition(stepTransition)

        case .fontSize:
            FontSizeStep(fontSize: $defaultFontSize)
                .transition(stepTransition)

        case .pace:
            PaceStep(speed: $defaultPromptSpeed)
                .transition(stepTransition)

        case .preferences:
            PreferencesStep(
                countdownEnabled: $countdownEnabled,
                focusNearLens: $focusNearLens
            )
            .transition(stepTransition)

        case .ready:
            ReadyStep(
                useCase: OnboardingUseCase(rawValue: useCase) ?? .creator,
                distance: RecordingDistance(rawValue: recordingDistance) ?? .tripod,
                fontSize: defaultFontSize,
                speed: defaultPromptSpeed,
                countdownEnabled: countdownEnabled,
                focusNearLens: focusNearLens
            )
            .transition(stepTransition)
        }
    }

    private var bottomAction: some View {
        VStack(spacing: 12) {
            Button {
                continueFlow()
            } label: {
                VioletGlassButtonLabel(
                    title: step == .ready ? "See Pro options" : buttonTitle,
                    systemImage: step == .ready ? "crown.fill" : "arrow.right"
                )
            }
            .buttonStyle(ToolPrimaryButtonStyle())
            .tint(.creatorViolet)

            if step == .ready {
                Text("Your preferences are already saved")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var buttonTitle: String {
        switch step {
        case .welcome:
            return "Set up my teleprompter"
        case .smoothTake:
            return "Personalize my setup"
        default:
            return "Continue"
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func continueFlow() {
        guard step != .ready else {
            showsPaywall = true
            return
        }

        withAnimation(.snappy(duration: 0.38)) {
            step = OnboardingStep(rawValue: step.rawValue + 1) ?? .ready
        }
    }

    private func goBack() {
        guard step.rawValue > 0 else { return }
        withAnimation(.snappy(duration: 0.38)) {
            step = OnboardingStep(rawValue: step.rawValue - 1) ?? .welcome
        }
    }

    private func applyRecommendedFontSize(_ distance: RecordingDistance) {
        recordingDistance = distance.rawValue
        withAnimation(.snappy) {
            defaultFontSize = distance.recommendedFontSize
        }
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case eyeContact
    case smoothTake
    case useCase
    case distance
    case fontSize
    case pace
    case preferences
    case ready
}

private enum OnboardingVisual {
    case eyeContact
    case recording
}

private enum OnboardingUseCase: String, CaseIterable, Identifiable {
    case creator
    case work
    case education
    case speech

    var id: String { rawValue }

    var title: String {
        switch self {
        case .creator: return "Videos & social content"
        case .work: return "Work & presentations"
        case .education: return "Lessons & courses"
        case .speech: return "Speeches & performances"
        }
    }

    var detail: String {
        switch self {
        case .creator: return "Reels, YouTube, product videos"
        case .work: return "Updates, pitches, video calls"
        case .education: return "Tutorials, classes, training"
        case .speech: return "Keynotes, lyrics, live delivery"
        }
    }

    var icon: String {
        switch self {
        case .creator: return "play.rectangle.fill"
        case .work: return "briefcase.fill"
        case .education: return "graduationcap.fill"
        case .speech: return "mic.fill"
        }
    }
}

private enum RecordingDistance: String, CaseIterable, Identifiable {
    case handheld
    case tripod
    case room

    var id: String { rawValue }

    var title: String {
        switch self {
        case .handheld: return "Close to the phone"
        case .tripod: return "Phone on a tripod"
        case .room: return "Across the room"
        }
    }

    var detail: String {
        switch self {
        case .handheld: return "Around arm’s length"
        case .tripod: return "About 1–2 metres away"
        case .room: return "More than 2 metres away"
        }
    }

    var icon: String {
        switch self {
        case .handheld: return "hand.raised.fill"
        case .tripod: return "camera.fill"
        case .room: return "person.wave.2.fill"
        }
    }

    var recommendedFontSize: Double {
        switch self {
        case .handheld: return 38
        case .tripod: return 48
        case .room: return 62
        }
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 22)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.creatorViolet.opacity(0.22),
                                Color.creatorVioletLight.opacity(0.10),
                                Color.appSurface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 370)

                Circle()
                    .fill(Color.creatorViolet.opacity(0.13))
                    .frame(width: 230, height: 230)
                    .offset(x: 128, y: -122)

                PromptPhoneMockup()
                    .rotationEffect(.degrees(-4))
                    .shadow(color: .black.opacity(0.18), radius: 30, y: 20)
            }

            Text("A simple teleprompter that helps you stay confident, keep eye contact and finish every take smoothly.")
                .font(.appHeadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
        }
    }
}

private struct PromptPhoneMockup: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.promptBlack)
                .frame(width: 214, height: 330)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(.black)
                    .frame(width: 72, height: 22)
                    .padding(.top, 12)

                Spacer()

                VStack(spacing: 12) {
                    Text("Speak clearly and")
                        .foregroundStyle(.white.opacity(0.46))
                    Text("look right at the lens")
                        .foregroundStyle(.white)
                    Text("while your script moves")
                        .foregroundStyle(.white.opacity(0.46))
                }
                .font(.appHeadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

                Spacer()

                HStack(spacing: 16) {
                    Circle().fill(.white.opacity(0.12)).frame(width: 38, height: 38)
                    Circle()
                        .fill(.red)
                        .frame(width: 54, height: 54)
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                    Circle().fill(.white.opacity(0.12)).frame(width: 38, height: 38)
                }
                .padding(.bottom, 24)
            }
            .frame(width: 214, height: 330)
        }
    }
}

private struct FeatureStep: View {
    let eyebrow: String
    let title: String
    let message: String
    let visual: OnboardingVisual

    var body: some View {
        VStack(spacing: 24) {
            FeatureVisual(type: visual)
                .frame(height: 390)

            Text(message)
                .font(.appHeadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 12)
        }
    }
}

private struct FeatureVisual: View {
    let type: OnboardingVisual

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)

            RadialGradient(
                colors: [Color.creatorViolet.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 330
            )

            switch type {
            case .eyeContact:
                eyeContactVisual
            case .recording:
                recordingVisual
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.75)
        }
    }

    private var eyeContactVisual: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.creatorViolet.opacity(0.13))
                    .frame(width: 112, height: 112)

                Image(systemName: "camera.aperture")
                    .font(.appHero)
                    .foregroundStyle(Color.creatorViolet)
            }

            VStack(spacing: 12) {
                Text("Your message starts here")
                    .foregroundStyle(.primary)
                    .fontWeight(.bold)
                Text("Stay relaxed and keep your eyes close to the camera")
                    .foregroundStyle(.secondary)
            }
            .font(.appHeadline)
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: 300)
            .contentCard()

            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                Text("Less visible eye movement")
            }
            .font(.appSubheadline)
            .foregroundStyle(Color.creatorViolet)
        }
        .padding(28)
    }

    private var recordingVisual: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.promptBlack)
                    .frame(height: 220)

                VStack(spacing: 12) {
                    Text("This line is coming next")
                        .foregroundStyle(.white.opacity(0.40))
                    Text("Speak at your own pace")
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                    Text("Pause whenever you need")
                        .foregroundStyle(.white.opacity(0.40))
                }
                .font(.appHeadline)

                Capsule()
                    .fill(Color.creatorViolet.opacity(0.22))
                    .frame(height: 54)
                    .padding(.horizontal, 16)

                HStack {
                    Label("00:12", systemImage: "record.circle")
                        .foregroundStyle(.white)
                        .font(.appCaptionEmphasis.monospacedDigit())
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .glassEffect(.regular, in: Capsule())
                    Spacer()
                }
                .padding(16)
                .frame(maxHeight: .infinity, alignment: .top)
            }

            HStack(spacing: 12) {
                MiniFeature(icon: "pause.fill", title: "Pause")
                MiniFeature(icon: "speedometer", title: "Adjust")
                MiniFeature(icon: "arrow.counterclockwise", title: "Restart")
            }
        }
        .padding(24)
    }
}

private struct MiniFeature: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.appHeadline)
                .foregroundStyle(Color.creatorViolet)
            Text(title)
                .font(.appCaptionEmphasis)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .contentCard()
    }
}

private struct UseCaseStep: View {
    @Binding var selection: String

    var body: some View {
        SetupStepHeader(
            number: "1",
            title: "What will you use Teleprompter for?",
            message: "We’ll use this to shape your starting setup. You can change everything later."
        ) {
            VStack(spacing: 12) {
                ForEach(OnboardingUseCase.allCases) { item in
                    ChoiceCard(
                        icon: item.icon,
                        title: item.title,
                        detail: item.detail,
                        isSelected: selection == item.rawValue
                    ) {
                        withAnimation(.snappy) {
                            selection = item.rawValue
                        }
                    }
                }
            }
        }
    }
}

private struct DistanceStep: View {
    @Binding var selection: String
    let onSelect: (RecordingDistance) -> Void

    var body: some View {
        SetupStepHeader(
            number: "2",
            title: "How far will the screen usually be?",
            message: "Distance changes the most comfortable starting text size."
        ) {
            VStack(spacing: 12) {
                ForEach(RecordingDistance.allCases) { item in
                    ChoiceCard(
                        icon: item.icon,
                        title: item.title,
                        detail: "\(item.detail) · \(Int(item.recommendedFontSize)) pt recommended",
                        isSelected: selection == item.rawValue
                    ) {
                        onSelect(item)
                    }
                }
            }
        }
    }
}

private struct FontSizeStep: View {
    @Binding var fontSize: Double

    var body: some View {
        SetupStepHeader(
            number: "3",
            title: "Choose a comfortable text size",
            message: "Adjust this as though the phone were at your normal recording distance."
        ) {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.promptBlack)

                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.appCaption)
                            .foregroundStyle(.white.opacity(0.44))

                        Text("Look confident on camera")
                            .font(.system(size: fontSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.45)
                            .lineLimit(2)
                            .padding(.horizontal, 24)
                    }
                }
                .frame(height: 250)

                VStack(spacing: 16) {
                    HStack {
                        Label("Text size", systemImage: "textformat.size")
                            .font(.appHeadline)
                        Spacer()
                        Text("\(Int(fontSize)) pt")
                            .font(.appHeadline.monospacedDigit())
                            .foregroundStyle(Color.creatorViolet)
                            .contentTransition(.numericText())
                    }

                    Slider(value: $fontSize, in: 32...72, step: 1)
                        .tint(.creatorViolet)

                    HStack {
                        Text("Smaller")
                        Spacer()
                        Text("Larger")
                    }
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
                .contentCard()
            }
        }
    }
}

private struct PaceStep: View {
    @Binding var speed: Double

    var body: some View {
        SetupStepHeader(
            number: "4",
            title: "Set your natural speaking pace",
            message: "Most people read too quickly at first. Start relaxed and fine-tune it during a take."
        ) {
            VStack(spacing: 20) {
                PacePreview(speed: speed)
                    .frame(height: 250)

                VStack(spacing: 16) {
                    HStack {
                        Label("Scroll speed", systemImage: "speedometer")
                            .font(.appHeadline)
                        Spacer()
                        Text(paceName)
                            .font(.appHeadline)
                            .foregroundStyle(Color.creatorViolet)
                    }

                    Slider(value: $speed, in: 22...82, step: 1)
                        .tint(.creatorViolet)

                    HStack {
                        Text("Relaxed")
                        Spacer()
                        Text("Natural")
                        Spacer()
                        Text("Brisk")
                    }
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
                .contentCard()
            }
        }
    }

    private var paceName: String {
        switch speed {
        case ..<36: return "Relaxed"
        case 36..<58: return "Natural"
        default: return "Brisk"
        }
    }
}

private struct PacePreview: View {
    let speed: Double

    var body: some View {
        TimelineView(.animation) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            let cycle = 4.6
            let progress = (seconds * max(speed / 44, 0.4)).truncatingRemainder(dividingBy: cycle) / cycle

            GeometryReader { proxy in
                let travel = proxy.size.height + 160

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.promptBlack)

                    VStack(spacing: 16) {
                        Text("Start with a calm breath")
                        Text("Speak as if you are talking")
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("to one person you know")
                        Text("Pause between each idea")
                    }
                    .font(.appTitle)
                    .foregroundStyle(.white.opacity(0.38))
                    .multilineTextAlignment(.center)
                    .offset(y: travel * (0.56 - progress))

                    Rectangle()
                        .fill(Color.creatorViolet.opacity(0.16))
                        .frame(height: 58)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.creatorViolet)
                                .frame(width: 4, height: 42)
                                .padding(.leading, 12)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

private struct PreferencesStep: View {
    @Binding var countdownEnabled: Bool
    @Binding var focusNearLens: Bool

    var body: some View {
        SetupStepHeader(
            number: "5",
            title: "A few finishing preferences",
            message: "These defaults make it easier to start recording without adjusting the same controls every time."
        ) {
            VStack(spacing: 16) {
                PreferenceCard(
                    icon: "timer",
                    title: "3-second countdown",
                    detail: "Give me a moment before recording begins",
                    isOn: $countdownEnabled
                )

                PreferenceCard(
                    icon: "camera.metering.center.weighted",
                    title: "Keep text near the lens",
                    detail: "Prioritize stronger eye contact over showing more lines",
                    isOn: $focusNearLens
                )

                VStack(alignment: .leading, spacing: 16) {
                    Label("You’re always in control", systemImage: "slider.horizontal.3")
                        .font(.appHeadline)
                        .foregroundStyle(Color.creatorViolet)

                    Text("Font size, scrolling speed, position and recording controls remain available during every session.")
                        .font(.appSecondary)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .contentCard()
            }
        }
    }
}

private struct ReadyStep: View {
    let useCase: OnboardingUseCase
    let distance: RecordingDistance
    let fontSize: Double
    let speed: Double
    let countdownEnabled: Bool
    let focusNearLens: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(Color.creatorViolet.opacity(0.13))
                    .frame(width: 154, height: 154)

                Circle()
                    .fill(Color.creatorViolet)
                    .frame(width: 104, height: 104)
                    .shadow(color: Color.creatorViolet.opacity(0.30), radius: 24, y: 14)

                Image(systemName: "checkmark")
                    .font(.appHero)
                    .foregroundStyle(.white)
            }

            Text("We’ve saved a comfortable starting point for your first recording.")
                .font(.appHeadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            VStack(spacing: 0) {
                SummaryRow(icon: useCase.icon, title: "Use", value: useCase.title)
                Divider().padding(.leading, 52)
                SummaryRow(icon: distance.icon, title: "Distance", value: distance.title)
                Divider().padding(.leading, 52)
                SummaryRow(icon: "textformat.size", title: "Text", value: "\(Int(fontSize)) pt")
                Divider().padding(.leading, 52)
                SummaryRow(icon: "speedometer", title: "Pace", value: speed < 36 ? "Relaxed" : speed < 58 ? "Natural" : "Brisk")
                Divider().padding(.leading, 52)
                SummaryRow(
                    icon: "sparkles",
                    title: "Preferences",
                    value: preferenceSummary
                )
            }
            .contentCard(cornerRadius: 16)
        }
    }

    private var preferenceSummary: String {
        var items: [String] = []
        if countdownEnabled { items.append("Countdown") }
        if focusNearLens { items.append("Lens focus") }
        return items.isEmpty ? "Standard" : items.joined(separator: " · ")
    }
}

private struct SetupStepHeader<Content: View>: View {
    let number: String
    let title: String
    let message: String
    let content: Content

    init(
        number: String,
        title: String,
        message: String,
        @ViewBuilder content: () -> Content
    ) {
        self.number = number
        self.title = title
        self.message = message
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(message)
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)

            content
        }
    }
}

private struct ChoiceCard: View {
    let icon: String
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.appHeadline)
                    .foregroundStyle(isSelected ? .white : Color.creatorViolet)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected ? Color.creatorViolet : Color.creatorViolet.opacity(0.11),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.appSecondary)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.appHeadline)
                    .foregroundStyle(isSelected ? Color.creatorViolet : Color.secondary.opacity(0.35))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? Color.creatorViolet.opacity(0.08) : Color.appSurface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.creatorViolet : Color.primary.opacity(0.055),
                        lineWidth: isSelected ? 1.5 : 0.75
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PreferenceCard: View {
    let icon: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.appHeadline)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 48, height: 48)
                .background(Color.creatorViolet.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appHeadline)
                Text(detail)
                    .font(.appSecondary)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.creatorViolet)
        }
        .padding(16)
        .contentCard()
    }
}

private struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 28)

            Text(title)
                .font(.appSubheadline)

            Spacer()

            Text(value)
                .font(.appSecondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

private struct OnboardingProgress: View {
    let count: Int
    let selection: Int

    private var progress: CGFloat {
        CGFloat(selection + 1) / CGFloat(max(count, 1))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))

                Capsule()
                    .fill(Color.primary)
                    .frame(width: max(22, proxy.size.width * progress))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(selection + 1) of \(count)")
    }
}
