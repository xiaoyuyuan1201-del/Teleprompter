import AVFoundation
import AVKit
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

                if recordingStore.recordings.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
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
            .navigationTitle("Videos")
            .navigationBarTitleDisplayMode(.large)
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
        HStack(spacing: 14) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 50, height: 50)
                .background(Color.creatorViolet.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Your recordings")
                    .font(.headline)
                Text("\(recordingStore.recordings.count) saved in Teleprompter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .contentCard()
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 76, height: 76)
                .background(Color.creatorViolet.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(spacing: 7) {
                Text("No recordings yet")
                    .font(.title3.bold())

                Text("Videos you record with Teleprompter will appear here automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
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
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    VideoThumbnailView(url: url)
                        .frame(width: 112, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(recording.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Label(recording.durationText, systemImage: "clock")
                            Text(recording.fileSizeText)
                            if !recording.hasAudio {
                                Image(systemName: "speaker.slash.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption2)
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
                    .font(.system(size: 16, weight: .semibold))
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
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Circle()
                .fill(.black.opacity(0.46))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
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

    let recording: RecordedVideo
    let url: URL

    @State private var player: AVPlayer
    @State private var showsShare = false

    init(recording: RecordedVideo, url: URL) {
        self.recording = recording
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 18) {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recording.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }

                        Spacer()

                        Text(recording.durationText)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(16)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button {
                        showsShare = true
                    } label: {
                        VioletGlassButtonLabel(title: "Share video", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.creatorViolet)
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
        .onDisappear {
            player.pause()
        }
    }
}
