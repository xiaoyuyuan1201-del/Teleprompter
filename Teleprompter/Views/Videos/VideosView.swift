import AVFoundation
import AVKit
import Photos
import SwiftUI
import UIKit

struct VideosView: View {
    @EnvironmentObject private var recordingStore: RecordingStore

    @State private var selectedRecording: RecordedVideo?
    @State private var renameTarget: RecordedVideo?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    AppHeaderRow(title: "Videos")

                    if recordingStore.recordings.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                summaryHeader

                                ForEach(recordingStore.recordings) { recording in
                                    RecordingCard(
                                        recording: recording,
                                        url: recordingStore.fileURL(for: recording),
                                        onOpen: { selectedRecording = recording },
                                        onRename: {
                                            renameText = recording.title
                                            renameTarget = recording
                                        },
                                        onDelete: { recordingStore.delete(recording) }
                                    )
                                }
                            }
                            .padding(.horizontal, AppLayout.screenHorizontalPadding)
                            .padding(.top, 8)
                            .padding(.bottom, 36)
                        }
                    }
                }
            }
            .hidesSystemNavigationBar()
        }
        .sheet(item: $selectedRecording) { recording in
            RecordingPlayerView(
                recording: recording,
                url: recordingStore.fileURL(for: recording)
            )
        }
        .alert("Rename video", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Video title", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
            Button("Rename") {
                if let renameTarget {
                    recordingStore.rename(renameTarget, to: renameText)
                }
                renameTarget = nil
            }
        } message: {
            Text("Use a name that helps you find this take later.")
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.appHeadline)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 50, height: 50)
                .background(Color.creatorViolet.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Your recordings")
                    .font(.appHeadline)
                Text("\(recordingStore.recordings.count) saved in Teleprompter")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .contentCard()
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.appHero)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 76, height: 76)
                .background(Color.creatorViolet.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 8) {
                Text("No recordings yet")
                    .font(.appTitle)

                Text("Videos you record with Teleprompter will appear here automatically.")
                    .font(.appSecondary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 36)
    }
}

private struct RecordingCard: View {
    let recording: RecordedVideo
    let url: URL
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var showsShare = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 16) {
                    VideoThumbnailView(url: url)
                        .frame(width: 112, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(recording.title)
                            .font(.appHeadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Label(recording.durationText, systemImage: "clock")
                            Text(recording.fileSizeText)
                            if !recording.hasAudio {
                                Image(systemName: "speaker.slash.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    showsShare = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.appSubheadline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(ToolSecondaryButtonStyle(height: 36, horizontalPadding: 0))
            .foregroundStyle(.primary)
        }
        .padding(12)
        .contentCard()
        .sheet(isPresented: $showsShare) {
            SystemShareSheet(items: [url])
        }
    }
}

private struct VideoThumbnailView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "video.fill")
                    .font(.appHeadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Circle()
                .fill(.black.opacity(0.46))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.appCaptionEmphasis)
                        .foregroundStyle(.white)
                        .offset(x: 1)
                }
        }
        .clipped()
        .task(id: url) {
            image = await createThumbnail(url: url)
        }
    }

    private func createThumbnail(url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 480, height: 480)
            let time = CMTime(seconds: 0.15, preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }.value
    }
}

private struct RecordingPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var purchaseManager: PurchaseManager

    let recording: RecordedVideo
    let url: URL

    @State private var player: AVPlayer
    @State private var showsShare = false
    @State private var showsPaywall = false
    @State private var showsDeleteConfirmation = false
    @State private var isSavingToPhotos = false
    @State private var savedToPhotos = false
    @State private var saveError: String?

    init(recording: RecordedVideo, url: URL) {
        self.recording = recording
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    ZStack(alignment: .bottomLeading) {
                        VideoPlayer(player: player)

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.65)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recording.title)
                                    .font(.appHeadline)
                                    .foregroundStyle(.white)
                                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.appCaption)
                                    .foregroundStyle(.white.opacity(0.72))
                            }

                            Spacer()

                            Text(recording.durationText)
                                .font(.appCaptionEmphasis.monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .padding(16)
                        .allowsHitTesting(false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if let saveError {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .font(.appCaption)
                            .foregroundStyle(.orange)
                    }

                    HStack(spacing: 12) {
                        RecordingActionButton(
                            title: "Remove Watermark",
                            systemImage: purchaseManager.isPro ? "checkmark.seal.fill" : "seal",
                            badge: purchaseManager.isPro ? nil : "PRO"
                        ) {
                            showsPaywall = true
                        }
                        .disabled(purchaseManager.isPro)

                        RecordingActionButton(title: "Share", systemImage: "square.and.arrow.up") {
                            showsShare = true
                        }

                        RecordingActionButton(title: "Delete", systemImage: "trash", tint: .red) {
                            showsDeleteConfirmation = true
                        }
                    }

                    Button {
                        saveToPhotos()
                    } label: {
                        VioletGlassButtonLabel(
                            title: savedToPhotos ? "Saved to Photos" : "Save to Photos",
                            systemImage: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.creatorViolet)
                    .disabled(isSavingToPhotos || savedToPhotos)
                }
                .padding(16)
            }
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsShare) {
            SystemShareSheet(items: [url])
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(source: .inApp)
                .environmentObject(purchaseManager)
        }
        .alert("Delete recording?", isPresented: $showsDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                recordingStore.delete(recording)
                dismiss()
            }
        } message: {
            Text("This video will be permanently deleted.")
        }
        .onDisappear {
            player.pause()
        }
    }

    private func saveToPhotos() {
        isSavingToPhotos = true
        saveError = nil
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    isSavingToPhotos = false
                    saveError = "Allow photo access in Settings to save this video."
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    isSavingToPhotos = false
                    if success {
                        savedToPhotos = true
                    } else {
                        saveError = error?.localizedDescription ?? "Couldn't save this video."
                    }
                }
            }
        }
    }
}

private struct RecordingActionButton: View {
    let title: String
    let systemImage: String
    var badge: String?
    var tint: Color = .creatorViolet
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.appHeadline)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.creatorViolet, in: Capsule())
                            .foregroundStyle(.white)
                            .offset(x: 14, y: -10)
                    }
                }
                .frame(height: 20)

                Text(title)
                    .font(.appCaption)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        }
        .buttonStyle(.glass)
        .tint(tint)
    }
}
