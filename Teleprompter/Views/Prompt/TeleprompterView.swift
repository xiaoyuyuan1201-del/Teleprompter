import AVKit
import SwiftUI
import UIKit

struct TeleprompterView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var recordingStore: RecordingStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraManager()

    let script: PromptScript

    @AppStorage("defaultPromptSpeed") private var speed = 44.0
    @AppStorage("defaultPromptFontSize") private var fontSize = 48.0
    @AppStorage("defaultCountdownEnabled") private var countdownEnabled = true
    @AppStorage("defaultPromptFocusNearLens") private var focusNearLens = true
    @AppStorage("defaultPromptMargin") private var promptMargin = 24.0
    @AppStorage("defaultPromptTimingMode") private var timingModeRaw = PromptScrollTimingMode.fixed.rawValue
    @AppStorage("defaultPromptTargetMinutes") private var targetMinutes = 2.0
    @AppStorage("defaultPromptAreaHeight") private var promptAreaHeight = 430.0
    @AppStorage("defaultPromptLineSpacing") private var lineSpacing = 0.0
    @AppStorage("defaultPromptUppercase") private var uppercase = false
    @AppStorage("defaultPromptFontStyle") private var fontStyleRaw = PromptFontStyle.standard.rawValue
    @AppStorage("defaultPromptUseOpenDyslexicFont") private var useOpenDyslexicFont = false
    @AppStorage("defaultPromptUseLexendFont") private var useLexendFont = false
    @AppStorage("defaultPromptShowCueIndicator") private var showCueIndicator = true
    @AppStorage("defaultPromptMirrorHorizontal") private var defaultMirrorHorizontal = false
    @AppStorage("defaultPromptMirrorVertical") private var defaultMirrorVertical = false
    @AppStorage("defaultPromptApplyMarginToRecordScreen") private var applyMarginToRecordScreen = true

    @State private var isPlaying = false
    @State private var resizeDragStartHeight: CGFloat?
    @State private var isMirrored = false
    @State private var isMirroredVertical = false
    @State private var resetToken = 0
    @State private var showsControls = false
    @State private var showsPaywall = false
    @State private var showsPreflight = false
    @State private var showsReview = false
    @State private var countdownValue: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var libraryRecordingID: UUID?

    private var timingMode: Binding<PromptScrollTimingMode> {
        Binding(
            get: { PromptScrollTimingMode(rawValue: timingModeRaw) ?? .fixed },
            set: { timingModeRaw = $0.rawValue }
        )
    }

    private var fontStyle: PromptFontStyle {
        PromptFontStyle(rawValue: fontStyleRaw) ?? .standard
    }

    private var effectiveMargin: Double {
        applyMarginToRecordScreen ? promptMargin : 24.0
    }

    var body: some View {
        ZStack {
            Color.promptBlack.ignoresSafeArea()

            if camera.authorizationDenied {
                permissionView
            } else {
                cameraLayer
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 12)
                    promptArea
                    Spacer(minLength: 14)
                    bottomControls
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }

            if let warning = camera.silentWarning {
                warningBanner(warning)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if camera.savedVideo {
                savedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let countdownValue {
                countdownOverlay(value: countdownValue)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            if camera.isFinalizing {
                finalizingOverlay
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            camera.start()
            UIApplication.shared.isIdleTimerDisabled = true
            if purchaseManager.isPro {
                isMirrored = defaultMirrorHorizontal
                isMirroredVertical = defaultMirrorVertical
            }
        }
        .onDisappear {
            countdownTask?.cancel()
            camera.stop()
            if !camera.isRecording {
                camera.discardCompletedRecording()
            }
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: camera.completedRecordingURL) { _, newValue in
            guard let newValue else {
                showsReview = false
                return
            }
            persistRecordingInLibrary(from: newValue)
            showsReview = true
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(source: .inApp)
                .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $showsControls) {
            adjustmentPanel
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showsPreflight) {
            RecordingPreflightSheet(snapshot: camera.preflightSnapshot()) {
                showsPreflight = false
                startRecordingAfterPreflight()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showsReview) {
            if let url = camera.completedRecordingURL {
                RecordingReviewView(
                    url: url,
                    verification: camera.verification,
                    isSaved: camera.savedVideo,
                    onSave: { deliveredURL in
                        camera.saveCompletedRecording(from: deliveredURL)
                    },
                    onRetake: {
                        showsReview = false
                        if let libraryRecordingID,
                           let recording = recordingStore.recording(with: libraryRecordingID) {
                            recordingStore.delete(recording)
                        }
                        self.libraryRecordingID = nil
                        camera.discardCompletedRecording()
                        resetToken += 1
                        isPlaying = false
                    },
                    onDone: {
                        showsReview = false
                        libraryRecordingID = nil
                    }
                )
                .environmentObject(purchaseManager)
            }
        }
        .alert("Teleprompter", isPresented: Binding(
            get: { camera.errorMessage != nil },
            set: { if !$0 { camera.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                camera.errorMessage = nil
            }
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }

    private var cameraLayer: some View {
        ZStack {
            CameraPreview(session: camera.session)

            LinearGradient(
                colors: [
                    .black.opacity(0.62),
                    .clear,
                    .black.opacity(0.76)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            PromptGlassButton(icon: "xmark", label: "Close") {
                if camera.isRecording {
                    camera.stopRecordingSession()
                    isPlaying = false
                } else if !camera.isFinalizing {
                    dismiss()
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(script.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(script.wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()

            if camera.isRecording {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 7) {
                        Circle()
                            .fill(camera.isPaused ? .yellow : .red)
                            .frame(width: 8, height: 8)

                        Text(camera.isPaused ? "PAUSED" : recordingDuration(camera.elapsedRecordingTime))
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .glassEffect(.regular, in: Capsule())
                }
            }

            PromptGlassButton(
                icon: "arrow.triangle.2.circlepath.camera.fill",
                label: "Switch camera",
                action: camera.switchCamera
            )
            .opacity(camera.isRecording ? 0.45 : 1)
            .allowsHitTesting(!camera.isRecording)
        }
    }

    private var promptArea: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.black.opacity(0.38))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.75)
                }

            AutoScrollingTextView(
                text: script.body,
                fontSize: CGFloat(fontSize),
                speed: CGFloat(speed),
                timingMode: timingMode.wrappedValue,
                targetDuration: targetMinutes * 60,
                horizontalPadding: CGFloat(effectiveMargin),
                isPlaying: isPlaying,
                resetToken: resetToken,
                topPadding: focusNearLens ? 72 : 170,
                lineSpacing: CGFloat(lineSpacing),
                uppercase: uppercase,
                fontStyle: fontStyle,
                useOpenDyslexicFont: useOpenDyslexicFont,
                useLexendFont: useLexendFont
            )
            .scaleEffect(x: isMirrored ? -1 : 1, y: isMirroredVertical ? -1 : 1)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if showCueIndicator {
                VStack(spacing: 0) {
                    if focusNearLens {
                        Spacer().frame(height: 66)
                    } else {
                        Spacer()
                    }

                    Rectangle()
                        .fill(Color.creatorViolet.opacity(0.16))
                        .frame(height: max(CGFloat(fontSize) * 1.72, 64))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.creatorViolet)
                                .frame(width: 4, height: max(CGFloat(fontSize) * 1.15, 44))
                                .padding(.leading, 8)
                        }

                    Spacer()
                }
                .allowsHitTesting(false)
            }

            resizeHandle
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(promptAreaHeight))
        .accessibilityLabel("Teleprompter script")
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.and.down")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 32, height: 32)
            .background(.black.opacity(0.45), in: Circle())
            .overlay {
                Circle().stroke(.white.opacity(0.18), lineWidth: 0.75)
            }
            .padding(.trailing, 8)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let startHeight = resizeDragStartHeight ?? CGFloat(promptAreaHeight)
                        resizeDragStartHeight = startHeight
                        let proposed = startHeight + value.translation.height
                        promptAreaHeight = Double(min(640, max(220, proposed)))
                    }
                    .onEnded { _ in
                        resizeDragStartHeight = nil
                    }
            )
            .accessibilityLabel("Resize teleprompter area")
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if camera.isRecording {
                Button {
                    if camera.isPaused {
                        camera.resumeRecording()
                        isPlaying = true
                    } else {
                        camera.pauseRecording()
                        isPlaying = false
                    }
                } label: {
                    Label(
                        camera.isPaused ? "Resume recording" : "Pause recording",
                        systemImage: camera.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.glass)
                .tint(camera.isPaused ? .creatorViolet : .white)
                .disabled(camera.isTransitioning)
            }

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 10) {
                    PromptGlassButton(icon: "backward.end.fill", label: "Restart") {
                        resetToken += 1
                        isPlaying = false
                    }

                    PromptGlassButton(
                        icon: isPlaying ? "pause.fill" : "play.fill",
                        label: isPlaying ? "Pause prompt" : "Play prompt",
                        tint: .creatorViolet
                    ) {
                        withAnimation(.snappy) {
                            isPlaying.toggle()
                        }
                    }

                    recordButton

                    PromptGlassButton(
                        icon: isMirrored ? "rectangle.on.rectangle.slash.fill" : "rectangle.on.rectangle.fill",
                        label: "Mirror mode",
                        tint: isMirrored ? .creatorViolet : .white
                    ) {
                        if purchaseManager.isPro {
                            isMirrored.toggle()
                        } else {
                            showsPaywall = true
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if !purchaseManager.isPro {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.creatorViolet, in: Circle())
                                .offset(x: 4, y: -4)
                        }
                    }

                    PromptGlassButton(
                        icon: "slider.horizontal.3",
                        label: "Prompt settings",
                        tint: showsControls ? .creatorViolet : .white
                    ) {
                        withAnimation(.snappy) {
                            showsControls.toggle()
                        }
                    }
                }
            }
        }
    }

    private var adjustmentPanel: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Picker("Timing", selection: timingMode) {
                        ForEach(PromptScrollTimingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if timingMode.wrappedValue == .fixed {
                        ControlSlider(
                            icon: "speedometer",
                            title: "Speed",
                            value: $speed,
                            range: 18...110,
                            valueText: "\(Int(speed))"
                        )
                    } else {
                        ControlSlider(
                            icon: "timer",
                            title: "Target duration",
                            value: $targetMinutes,
                            range: 0.5...10,
                            step: 0.5,
                            valueText: targetDurationText
                        )
                    }

                    ControlSlider(
                        icon: "textformat.size",
                        title: "Text size",
                        value: $fontSize,
                        range: 28...72,
                        valueText: "\(Int(fontSize))"
                    )

                    ControlSlider(
                        icon: "arrow.left.and.right",
                        title: "Side margins",
                        value: $promptMargin,
                        range: 16...76,
                        valueText: "\(Int(promptMargin))"
                    )

                    Toggle("3-second countdown", isOn: $countdownEnabled)
                        .font(.subheadline.weight(.semibold))
                        .tint(.creatorViolet)

                    Toggle("Keep reading line near camera", isOn: $focusNearLens)
                        .font(.subheadline.weight(.semibold))
                        .tint(.creatorViolet)

                    Text("You can drag the script at any time. Automatic scrolling resumes after you release it.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .background(Color.promptBlack.ignoresSafeArea())
            .navigationTitle("Prompt settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showsControls = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var recordButton: some View {
        Button {
            if camera.isRecording {
                camera.stopRecordingSession()
                isPlaying = false
            } else {
                showsPreflight = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.94))
                    .frame(width: 68, height: 68)

                RoundedRectangle(
                    cornerRadius: camera.isRecording ? 7 : 28,
                    style: .continuous
                )
                .fill(.red)
                .frame(
                    width: camera.isRecording ? 27 : 52,
                    height: camera.isRecording ? 27 : 52
                )
                .animation(.snappy, value: camera.isRecording)
            }
        }
        .buttonStyle(.plain)
        .disabled(countdownValue != nil || camera.isFinalizing || camera.isTransitioning)
        .accessibilityLabel(camera.isRecording ? "Stop recording" : "Start recording")
    }

    private var permissionView: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 84, height: 84)
                .glassEffect(.regular.tint(Color.creatorViolet.opacity(0.18)), in: Circle())

            Text("Camera access is off")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Enable camera and microphone access in Settings to record while reading your script.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)

            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.glassProminent)
            .tint(.creatorViolet)
        }
        .padding(24)
    }

    private func countdownOverlay(value: Int) -> some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Get ready")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.78))

                Text("\(value)")
                    .font(.system(size: 104, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .padding(38)
            .glassEffect(.regular.tint(Color.black.opacity(0.18)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .allowsHitTesting(true)
    }

    private var finalizingOverlay: some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Checking your recording...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(28)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private func warningBanner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .glassEffect(.regular.tint(Color.orange.opacity(0.24)), in: Capsule())
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 64)
            .padding(.horizontal, 24)
    }

    private var savedToast: some View {
        Label("Saved to Photos", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 46)
            .glassEffect(.regular.tint(Color.creatorViolet.opacity(0.25)), in: Capsule())
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 18)
    }

    private var targetDurationText: String {
        if targetMinutes < 1 {
            return "30 sec"
        }
        if targetMinutes.rounded() == targetMinutes {
            return "\(Int(targetMinutes)) min"
        }
        return String(format: "%.1f min", targetMinutes)
    }

    private func persistRecordingInLibrary(from url: URL) {
        guard libraryRecordingID == nil else { return }

        do {
            let recording = try recordingStore.importRecording(
                from: url,
                title: script.displayTitle,
                verification: camera.verification
            )
            libraryRecordingID = recording.id
        } catch {
            camera.errorMessage = "The recording was created, but it could not be added to your video library. " + error.localizedDescription
        }
    }

    private func recordingDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func startRecordingAfterPreflight() {
        guard countdownValue == nil else { return }
        if countdownEnabled {
            beginCountdown()
        } else {
            beginRecording()
        }
    }

    private func beginCountdown() {
        countdownTask?.cancel()
        isPlaying = false

        countdownTask = Task { @MainActor in
            for value in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                withAnimation(.snappy) {
                    countdownValue = value
                }
                try? await Task.sleep(for: .seconds(1))
            }

            guard !Task.isCancelled else { return }
            withAnimation(.snappy) {
                countdownValue = nil
            }
            beginRecording()
        }
    }

    private func beginRecording() {
        camera.startRecordingSession()
        isPlaying = true
    }
}

private struct RecordingPreflightSheet: View {
    @Environment(\.dismiss) private var dismiss
    let snapshot: RecordingPreflightSnapshot
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready to record?")
                        .font(.title2.bold())
                    Text("A quick check helps avoid a silent, incomplete, or unsaved take.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    PreflightRow(
                        icon: "camera.fill",
                        title: "Camera",
                        detail: snapshot.cameraAuthorized ? "1080p camera ready" : "Camera permission needed",
                        isReady: snapshot.cameraAuthorized
                    )
                    Divider().padding(.leading, 56)
                    PreflightRow(
                        icon: "mic.fill",
                        title: "Microphone",
                        detail: snapshot.microphoneAuthorized ? snapshot.microphoneName : "Recording will have no voice audio",
                        isReady: snapshot.microphoneAuthorized
                    )
                    Divider().padding(.leading, 56)
                    PreflightRow(
                        icon: "internaldrive.fill",
                        title: "Storage",
                        detail: snapshot.storageDescription + " available",
                        isReady: snapshot.availableStorageBytes >= 250_000_000
                    )
                }
                .contentCard(cornerRadius: 10)

                if !snapshot.microphoneAuthorized {
                    Label("You can continue, but the video will be recorded without microphone audio.", systemImage: "speaker.slash.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !snapshot.cameraAuthorized {
                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.creatorViolet)
                } else {
                    Button {
                        onStart()
                    } label: {
                        VioletGlassButtonLabel(title: "Start recording", systemImage: "record.circle")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.creatorViolet)
                    .disabled(snapshot.hasBlockingIssue)
                }
            }
            .padding(20)
            .navigationTitle("Pre-record check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PreflightRow: View {
    let icon: String
    let title: String
    let detail: String
    let isReady: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 42, height: 42)
                .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isReady ? Color.green : Color.orange)
        }
        .padding(16)
    }
}

private struct RecordingReviewView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    let sourceURL: URL
    let verification: RecordingVerification?
    let isSaved: Bool
    let onSave: (URL) -> Void
    let onRetake: () -> Void
    let onDone: () -> Void

    @State private var player: AVPlayer?
    @State private var exportedURL: URL?
    @State private var isPreparingAsset = true
    @State private var watermarkFailed = false
    @State private var showsShare = false
    @State private var showsPaywall = false

    init(
        url: URL,
        verification: RecordingVerification?,
        isSaved: Bool,
        onSave: @escaping (URL) -> Void,
        onRetake: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.sourceURL = url
        self.verification = verification
        self.isSaved = isSaved
        self.onSave = onSave
        self.onRetake = onRetake
        self.onDone = onDone
    }

    private var deliveredURL: URL {
        exportedURL ?? sourceURL
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 18) {
                    ZStack {
                        if let player {
                            VideoPlayer(player: player)
                        }

                        if isPreparingAsset {
                            ZStack {
                                Color.black.opacity(0.55)
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Preparing preview...")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 0.75)
                    }

                    verificationCard

                    if watermarkFailed {
                        Label("Couldn't prepare the watermark. Saving the original recording instead.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    HStack(spacing: 12) {
                        Button {
                            onRetake()
                            dismiss()
                        } label: {
                            Label("Retake", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .buttonStyle(.glass)

                        Button {
                            showsShare = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .buttonStyle(.glass)
                        .disabled(isPreparingAsset)
                    }

                    if !purchaseManager.isPro {
                        Button {
                            showsPaywall = true
                        } label: {
                            Label("Remove Watermark", systemImage: "seal")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                        }
                        .buttonStyle(.glass)
                        .tint(.creatorViolet)
                    }

                    Button {
                        onSave(deliveredURL)
                    } label: {
                        VioletGlassButtonLabel(
                            title: isSaved ? "Saved to Photos" : "Save to Photos",
                            systemImage: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.creatorViolet)
                    .disabled(isSaved || isPreparingAsset)
                }
                .padding(16)
            }
            .navigationTitle("Review recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsShare) {
            SystemShareSheet(items: [deliveredURL])
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(source: .inApp)
                .environmentObject(purchaseManager)
        }
        .task(id: purchaseManager.isPro) {
            await prepareAsset()
        }
        .onDisappear {
            player?.pause()
            if let exportedURL, exportedURL != sourceURL {
                try? FileManager.default.removeItem(at: exportedURL)
            }
        }
    }

    private func prepareAsset() async {
        if purchaseManager.isPro {
            exportedURL = nil
            isPreparingAsset = false
            player = AVPlayer(url: sourceURL)
            return
        }

        isPreparingAsset = true
        watermarkFailed = false

        await withCheckedContinuation { continuation in
            VideoWatermarkService.export(sourceURL: sourceURL) { result in
                switch result {
                case .success(let url):
                    exportedURL = url
                case .failure:
                    watermarkFailed = true
                    exportedURL = nil
                }
                isPreparingAsset = false
                player = AVPlayer(url: deliveredURL)
                continuation.resume()
            }
        }
    }

    private var verificationCard: some View {
        HStack(spacing: 14) {
            VerificationItem(
                icon: "checkmark.seal.fill",
                title: "Video",
                value: verification?.hasVideo == true ? "Verified" : "Check failed",
                isReady: verification?.hasVideo == true
            )
            VerificationItem(
                icon: "waveform",
                title: "Audio",
                value: verification?.hasAudio == true ? "Included" : "No audio",
                isReady: verification?.hasAudio == true
            )
            VerificationItem(
                icon: "clock",
                title: verification?.durationText ?? "--:--",
                value: verification?.fileSizeText ?? "--",
                isReady: true
            )
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct VerificationItem: View {
    let icon: String
    let title: String
    let value: String
    let isReady: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(isReady ? Color.green : Color.orange)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PromptGlassButton: View {
    let icon: String
    let label: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.glass)
        .tint(tint)
        .foregroundStyle(tint)
        .accessibilityLabel(label)
    }
}

private struct ControlSlider: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    let valueText: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()

                Text(valueText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Slider(value: $value, in: range, step: step)
                .tint(.creatorViolet)
        }
    }
}
