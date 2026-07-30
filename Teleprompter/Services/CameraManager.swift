import AVFoundation
import Photos
import SwiftUI

struct RecordingPreflightSnapshot {
    let cameraAuthorized: Bool
    let microphoneAuthorized: Bool
    let microphoneName: String
    let availableStorageBytes: Int64

    var hasBlockingIssue: Bool {
        !cameraAuthorized || availableStorageBytes < 250_000_000
    }

    var storageDescription: String {
        ByteCountFormatter.string(fromByteCount: availableStorageBytes, countStyle: .file)
    }
}

struct RecordingVerification {
    let duration: TimeInterval
    let fileSizeBytes: Int64
    let hasVideo: Bool
    let hasAudio: Bool

    var durationText: String {
        let total = max(0, Int(duration.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
}

final class CameraManager: NSObject, ObservableObject {
    @Published private(set) var authorizationDenied = false
    @Published private(set) var microphoneDenied = false
    @Published private(set) var isConfigured = false
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var isFinalizing = false
    @Published private(set) var isTransitioning = false
    @Published private(set) var savedVideo = false
    @Published private(set) var completedRecordingURL: URL?
    @Published private(set) var verification: RecordingVerification?
    @Published var silentWarning: String?
    @Published var errorMessage: String?
    /// Normalized microphone input level (0...1), updated live while the session is running.
    @Published private(set) var audioLevel: Float = 0

    let session = AVCaptureSession()

    private enum PendingStopAction {
        case pause
        case finish
    }

    private let sessionQueue = DispatchQueue(label: "teleprompter.camera.session")
    private let audioLevelQueue = DispatchQueue(label: "teleprompter.camera.audioLevel")
    private let movieOutput = AVCaptureMovieFileOutput()
    private let audioLevelOutput = AVCaptureAudioDataOutput()
    private var lastAudioLevelUpdate: Date = .distantPast
    private var currentPosition: AVCaptureDevice.Position = .front
    private var pendingStopAction: PendingStopAction?
    private var segmentURLs: [URL] = []
    private var recordingStartedAt: Date?
    private var pauseStartedAt: Date?
    private var accumulatedPauseDuration: TimeInterval = 0
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        observeSessionNotifications()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    var elapsedRecordingTime: TimeInterval {
        guard let recordingStartedAt else { return 0 }
        let currentPause = pauseStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        return max(0, Date().timeIntervalSince(recordingStartedAt) - accumulatedPauseDuration - currentPause)
    }

    func start() {
        requestAccessAndConfigure()
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
        audioLevel = 0
    }

    func switchCamera() {
        guard !isRecording, !isFinalizing else { return }
        currentPosition = currentPosition == .front ? .back : .front
        sessionQueue.async { [weak self] in
            self?.configureSession(resetInputs: true)
        }
    }

    func startRecordingSession() {
        guard isConfigured, !isRecording, !isFinalizing, !isTransitioning else { return }
        discardCompletedRecording()
        segmentURLs.removeAll()
        pendingStopAction = nil
        accumulatedPauseDuration = 0
        pauseStartedAt = nil
        recordingStartedAt = .now
        isRecording = true
        isPaused = false
        silentWarning = microphoneDenied ? "Recording without microphone audio" : nil
        startSegment()
    }

    func pauseRecording() {
        guard isRecording, !isPaused, movieOutput.isRecording, !isTransitioning else { return }
        isTransitioning = true
        pendingStopAction = .pause
        pauseStartedAt = .now
        movieOutput.stopRecording()
    }

    func resumeRecording() {
        guard isRecording, isPaused, !movieOutput.isRecording, !isTransitioning else { return }
        if let pauseStartedAt {
            accumulatedPauseDuration += Date().timeIntervalSince(pauseStartedAt)
        }
        self.pauseStartedAt = nil
        isPaused = false
        silentWarning = microphoneDenied ? "Recording without microphone audio" : nil
        startSegment()
    }

    func stopRecordingSession() {
        guard isRecording, !isTransitioning else { return }
        if isPaused {
            if let pauseStartedAt {
                accumulatedPauseDuration += Date().timeIntervalSince(pauseStartedAt)
            }
            self.pauseStartedAt = nil
            finalizeSegments()
        } else if movieOutput.isRecording {
            isTransitioning = true
            pendingStopAction = .finish
            movieOutput.stopRecording()
        } else {
            finalizeSegments()
        }
    }

    func togglePause() {
        isPaused ? resumeRecording() : pauseRecording()
    }

    func preflightSnapshot() -> RecordingPreflightSnapshot {
        let cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        let microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let routeName = AVAudioSession.sharedInstance().currentRoute.inputs.first?.portName ?? "No microphone input"
        let storage = availableStorageBytes()
        return RecordingPreflightSnapshot(
            cameraAuthorized: cameraAuthorized,
            microphoneAuthorized: microphoneAuthorized,
            microphoneName: routeName,
            availableStorageBytes: storage
        )
    }

    func saveCompletedRecording(from url: URL? = nil) {
        guard let saveURL = url ?? completedRecordingURL else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Allow photo access to save your recording."
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: saveURL)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    self?.savedVideo = success
                    if let error {
                        self?.errorMessage = error.localizedDescription
                    }
                    if success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            self?.savedVideo = false
                        }
                    }
                }
            }
        }
    }

    func discardCompletedRecording() {
        if let completedRecordingURL {
            try? FileManager.default.removeItem(at: completedRecordingURL)
        }
        completedRecordingURL = nil
        verification = nil
    }

    private func requestAccessAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestMicrophoneAndConfigure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authorizationDenied = !granted
                }
                if granted {
                    self?.requestMicrophoneAndConfigure()
                }
            }
        default:
            DispatchQueue.main.async { [weak self] in
                self?.authorizationDenied = true
            }
        }
    }

    private func requestMicrophoneAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            configureAudioSession()
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.microphoneDenied = !granted
                }
                self?.configureAudioSession()
                self?.configureAndRun()
            }
        default:
            DispatchQueue.main.async { [weak self] in
                self?.microphoneDenied = true
            }
            configureAudioSession()
            configureAndRun()
        }
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.silentWarning = "Microphone route could not be prepared"
            }
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSession(resetInputs: false)
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.isConfigured = true
            }
        }
    }

    private func configureSession(resetInputs: Bool) {
        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .high
        }

        if resetInputs {
            session.inputs.forEach { session.removeInput($0) }
        }

        if session.inputs.isEmpty {
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
               let videoInput = try? AVCaptureDeviceInput(device: camera),
               session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }

            if let microphone = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: microphone),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }

        if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        if !session.outputs.contains(audioLevelOutput), session.canAddOutput(audioLevelOutput) {
            audioLevelOutput.setSampleBufferDelegate(self, queue: audioLevelQueue)
            session.addOutput(audioLevelOutput)
        }

        configureOutputConnection()
        session.commitConfiguration()
    }

    private func configureOutputConnection() {
        guard let connection = movieOutput.connection(with: .video) else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = currentPosition == .front
        }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    private func startSegment() {
        guard !movieOutput.isRecording else { return }
        guard availableStorageBytes() >= 100_000_000 else {
            silentWarning = "Storage is almost full. Stop and free up space."
            stopRecordingSession()
            return
        }

        configureOutputConnection()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("teleprompter-segment-\(UUID().uuidString).mov")
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    private func finalizeSegments() {
        guard !isFinalizing else { return }
        isFinalizing = true
        isTransitioning = false
        isRecording = false
        isPaused = false
        pendingStopAction = nil
        pauseStartedAt = nil
        silentWarning = nil

        let urls = segmentURLs
        guard !urls.isEmpty else {
            isFinalizing = false
            recordingStartedAt = nil
            errorMessage = "No recording data was created."
            return
        }

        mergeSegments(urls) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isFinalizing = false
                self.isTransitioning = false
                self.recordingStartedAt = nil

                switch result {
                case .success(let url):
                    self.verification = self.verifyRecording(at: url)
                    self.completedRecordingURL = url
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }

                urls.forEach { segment in
                    if segment != self.completedRecordingURL {
                        try? FileManager.default.removeItem(at: segment)
                    }
                }
                self.segmentURLs.removeAll()
            }
        }
    }

    private func mergeSegments(_ urls: [URL], completion: @escaping (Result<URL, Error>) -> Void) {
        if urls.count == 1, let only = urls.first {
            completion(.success(only))
            return
        }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(.failure(RecordingError.cannotCreateComposition))
            return
        }
        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero
        var preferredTransform = CGAffineTransform.identity

        do {
            for (index, url) in urls.enumerated() {
                let asset = AVURLAsset(url: url)
                let duration = asset.duration
                let range = CMTimeRange(start: .zero, duration: duration)

                if let sourceVideoTrack = asset.tracks(withMediaType: .video).first {
                    try compositionVideoTrack.insertTimeRange(range, of: sourceVideoTrack, at: cursor)
                    if index == 0 {
                        preferredTransform = sourceVideoTrack.preferredTransform
                    }
                }

                if let sourceAudioTrack = asset.tracks(withMediaType: .audio).first,
                   let compositionAudioTrack {
                    try compositionAudioTrack.insertTimeRange(range, of: sourceAudioTrack, at: cursor)
                }

                cursor = CMTimeAdd(cursor, duration)
            }
            compositionVideoTrack.preferredTransform = preferredTransform
        } catch {
            completion(.failure(error))
            return
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("teleprompter-recording-\(UUID().uuidString).mov")
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(RecordingError.cannotCreateExporter))
            return
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(.success(outputURL))
            case .failed, .cancelled:
                completion(.failure(exporter.error ?? RecordingError.exportFailed))
            default:
                completion(.failure(RecordingError.exportFailed))
            }
        }
    }

    private func verifyRecording(at url: URL) -> RecordingVerification {
        let asset = AVURLAsset(url: url)
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        return RecordingVerification(
            duration: asset.duration.seconds.isFinite ? asset.duration.seconds : 0,
            fileSizeBytes: fileSize,
            hasVideo: !asset.tracks(withMediaType: .video).isEmpty,
            hasAudio: !asset.tracks(withMediaType: .audio).isEmpty
        )
    }

    private func availableStorageBytes() -> Int64 {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    private func observeSessionNotifications() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: AVCaptureSession.wasInterruptedNotification,
                object: session,
                queue: .main
            ) { [weak self] _ in
                guard self?.isRecording == true else { return }
                self?.silentWarning = "Camera session interrupted. Recording may pause."
            }
        )
        observers.append(
            center.addObserver(
                forName: AVCaptureSession.runtimeErrorNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                guard self?.isRecording == true else { return }
                let message = (notification.userInfo?[AVCaptureSessionErrorKey] as? Error)?.localizedDescription
                self?.silentWarning = message ?? "A camera issue occurred during recording."
            }
        )
    }
}

extension CameraManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let channel = connection.audioChannels.first else { return }

        let now = Date()
        guard now.timeIntervalSince(lastAudioLevelUpdate) > 1.0 / 15.0 else { return }
        lastAudioLevelUpdate = now

        // averagePowerLevel is in decibels, roughly -160 (silence) to 0 (max).
        let minDb: Float = -50
        let normalized = max(0, min(1, (channel.averagePowerLevel - minDb) / -minDb))

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = normalized
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.isTransitioning = false

            if let error {
                self.errorMessage = error.localizedDescription
                self.isRecording = false
                self.isPaused = false
                self.isFinalizing = false
                return
            }

            self.segmentURLs.append(outputFileURL)
            let action = self.pendingStopAction
            self.pendingStopAction = nil

            switch action {
            case .some(.pause):
                self.isPaused = true
                self.silentWarning = "Recording paused"
            case .some(.finish), .none:
                self.finalizeSegments()
            }
        }
    }
}

enum RecordingError: LocalizedError {
    case cannotCreateComposition
    case cannotCreateExporter
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .cannotCreateComposition:
            "The recording could not be assembled."
        case .cannotCreateExporter:
            "The recording exporter could not be created."
        case .exportFailed:
            "The recording could not be finalized."
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
