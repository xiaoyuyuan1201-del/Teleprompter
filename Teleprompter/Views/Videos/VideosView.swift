import AVFoundation
import AVKit
import Photos
import SwiftUI
import UIKit

struct VideosView: View {
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var purchaseManager: PurchaseManager

    var onGoToHome: () -> Void = {}

    @State private var selectedRecording: RecordedVideo?
    @State private var renameTarget: RecordedVideo?
    @State private var renameText = ""
    @State private var searchText = ""
    @State private var showsSearchField = false
    @State private var videoTab: VideoTab = .videos
    @State private var sortNewestFirst = true
    @State private var openedFolder: VideoFolder?
    @FocusState private var isSearchFieldFocused: Bool

    private enum VideoTab: String, CaseIterable, Identifiable {
        case videos
        case folders

        var id: String { rawValue }

        var title: String {
            switch self {
            case .videos: "Videos"
            case .folders: "Folders"
            }
        }
    }

    private var visibleFolders: [VideoFolder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return recordingStore.folders }
        return recordingStore.folders.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    private var filteredRecordings: [RecordedVideo] {
        var items = recordingStore.recordings(in: nil)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter { $0.title.localizedCaseInsensitiveContains(query) }
        }
        return sortNewestFirst ? items : items.reversed()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    videosTopBar

                    if recordingStore.recordings.isEmpty && recordingStore.folders.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                LazyVStack(alignment: .leading, spacing: 16) {
                                    videoTabsRow

                                    switch videoTab {
                                    case .videos:
                                        if filteredRecordings.isEmpty {
                                            noResultsState
                                        } else {
                                            ForEach(filteredRecordings) { recording in
                                                RecordingCard(
                                                    recording: recording,
                                                    folders: recordingStore.folders,
                                                    url: recordingStore.fileURL(for: recording),
                                                    onOpen: { selectedRecording = recording },
                                                    onRename: {
                                                        renameText = recording.title
                                                        renameTarget = recording
                                                    },
                                                    onFavorite: { recordingStore.toggleFavorite(recording) },
                                                    onMove: { folderID in
                                                        recordingStore.move(recording, toFolder: folderID)
                                                    },
                                                    onDelete: { recordingStore.delete(recording) }
                                                )
                                            }
                                        }
                                    case .folders:
                                        if visibleFolders.isEmpty {
                                            noResultsState
                                        } else {
                                            ForEach(visibleFolders) { folder in
                                                VideoFolderRow(
                                                    folder: folder,
                                                    count: recordingStore.recordings(in: folder.id).count,
                                                    onOpen: { openedFolder = folder }
                                                )
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                                .padding(.top, 8)
                                .padding(.bottom, 36)
                            }
                            .onChange(of: isSearchFieldFocused) { _, isFocused in
                                guard isFocused else { return }
                                withAnimation {
                                    proxy.scrollTo("videoSearchField", anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
            .hidesSystemNavigationBar()
            .navigationDestination(item: $openedFolder) { folder in
                VideoFolderDetailView(folder: folder)
                    .environmentObject(recordingStore)
                    .environmentObject(purchaseManager)
            }
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

    private var videosTopBar: some View {
        Group {
            if showsSearchField {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search videos", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isSearchFieldFocused)
                            .onAppear { isSearchFieldFocused = true }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .contentCard(cornerRadius: 16)
                    .id("videoSearchField")

                    Button("Cancel") {
                        withAnimation(.snappy) {
                            showsSearchField = false
                            searchText = ""
                            isSearchFieldFocused = false
                        }
                    }
                    .font(.appHeadline)
                    .foregroundStyle(Color.creatorViolet)
                }
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.vertical, 8)
            } else {
                AppHeaderRow(title: "Videos") {
                    HStack(spacing: 16) {
                        Button {
                            withAnimation(.snappy) {
                                showsSearchField = true
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.5))
                        }

                        Menu {
                            Button {
                                sortNewestFirst = true
                            } label: {
                                Label("Newest First", systemImage: "arrow.down")
                            }
                            Button {
                                sortNewestFirst = false
                            } label: {
                                Label("Oldest First", systemImage: "arrow.up")
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.5))
                        }
                        .accessibilityLabel("Sort")
                    }
                }
            }
        }
    }

    private var videoTabsRow: some View {
        HStack(spacing: 8) {
            ForEach(VideoTab.allCases) { tab in
                Button {
                    withAnimation(.snappy) {
                        videoTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.appSubheadline)
                        .foregroundStyle(videoTab == tab ? .white : .primary)
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(
                            videoTab == tab ? Color.creatorViolet : Color.appSurface,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noResultsState: some View {
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let itemName = videoTab == .videos ? "videos" : "folders"

        return VStack(spacing: 12) {
            Image(systemName: isSearching ? "eye.slash" : "tray")
                .font(.appTitle)
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background(Color.appSurface, in: Circle())

            Text(isSearching ? "No Results" : "Nothing here yet")
                .font(.appHeadline)

            Text(
                isSearching
                    ? "No \(itemName) match \"\(searchText)\""
                    : (videoTab == .videos
                        ? "Videos you record without a folder will appear here."
                        : "Tap the folder icon above to create your first video folder.")
            )
            .font(.appSecondary)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
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

            Button(action: onGoToHome) {
                Text("Go to Home")
                    .font(.appHeadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 46)
                    .background(Color.creatorViolet, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 36)
    }
}

private struct VideoFolderRow: View {
    let folder: VideoFolder
    let count: Int
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.creatorViolet)
                    .frame(width: 36, height: 36)
                    .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.displayName)
                        .font(.appHeadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(count) video\(count == 1 ? "" : "s")")
                        .font(.appSecondary)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.appCaptionEmphasis)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentCard()
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct VideoFolderDetailView: View {
    @EnvironmentObject private var recordingStore: RecordingStore
    @Environment(\.dismiss) private var dismiss

    let folder: VideoFolder

    @State private var selectedRecording: RecordedVideo?
    @State private var renameTarget: RecordedVideo?
    @State private var renameText = ""
    @State private var showsRenameFolderAlert = false
    @State private var folderRenameText = ""
    @State private var showsDeleteFolderAlert = false

    private var currentFolder: VideoFolder {
        recordingStore.folders.first { $0.id == folder.id } ?? folder
    }

    private var recordings: [RecordedVideo] {
        recordingStore.recordings(in: folder.id)
    }

    var body: some View {
        ZStack {
            AppBackground()

            if recordings.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(recordings) { recording in
                            RecordingCard(
                                recording: recording,
                                folders: recordingStore.folders,
                                url: recordingStore.fileURL(for: recording),
                                onOpen: { selectedRecording = recording },
                                onRename: {
                                    renameText = recording.title
                                    renameTarget = recording
                                },
                                onFavorite: { recordingStore.toggleFavorite(recording) },
                                onMove: { folderID in
                                    recordingStore.move(recording, toFolder: folderID)
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
        .navigationTitle(currentFolder.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        folderRenameText = currentFolder.displayName
                        showsRenameFolderAlert = true
                    } label: {
                        Label("Rename Folder", systemImage: "character.cursor.ibeam")
                    }
                    Button(role: .destructive) {
                        showsDeleteFolderAlert = true
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .tint(.primary)
            }
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
        .alert("Rename folder", isPresented: $showsRenameFolderAlert) {
            TextField("Folder name", text: $folderRenameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                recordingStore.renameFolder(currentFolder, to: folderRenameText)
            }
        }
        .alert("Delete folder?", isPresented: $showsDeleteFolderAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                recordingStore.deleteFolder(currentFolder)
                dismiss()
            }
        } message: {
            Text("Videos inside will move back to \"No Folder\". This can't be undone.")
        }
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "folder")
                .font(.appHeadline)
                .foregroundStyle(Color.creatorViolet)
                .frame(width: 38, height: 38)
                .background(Color.creatorViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text("No videos here yet")
                    .font(.appHeadline)
                Text("Move a video in from its menu on the Videos tab.")
                    .font(.appSecondary)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .contentCard()
        .padding(.horizontal, AppLayout.screenHorizontalPadding)
        .padding(.top, 20)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct RecordingCard: View {
    let recording: RecordedVideo
    let folders: [VideoFolder]
    let url: URL
    let onOpen: () -> Void
    let onRename: () -> Void
    let onFavorite: () -> Void
    let onMove: (UUID?) -> Void
    let onDelete: () -> Void

    @State private var showsShare = false
    @State private var showsDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 16) {
                    VideoThumbnailView(url: url)
                        .frame(width: 112, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(recording.title)
                                .font(.appHeadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            if recording.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.creatorViolet)
                            }
                        }

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
                Button(action: onFavorite) {
                    Label(
                        recording.isFavorite ? "Remove Favorite" : "Favorite",
                        systemImage: recording.isFavorite ? "star.slash" : "star"
                    )
                }
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    showsShare = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Menu {
                    if recording.folderID != nil {
                        Button {
                            onMove(nil)
                        } label: {
                            Label("No Folder", systemImage: "circle.slash")
                        }
                        Divider()
                    }
                    ForEach(folders) { folder in
                        Button {
                            onMove(folder.id)
                        } label: {
                            if recording.folderID == folder.id {
                                Label(folder.displayName, systemImage: "checkmark")
                            } else {
                                Text(folder.displayName)
                            }
                        }
                    }
                } label: {
                    Label("Move to Folder", systemImage: "folder")
                }
                Button(role: .destructive) {
                    showsDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.appSubheadline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(ToolSecondaryButtonStyle(height: 36, horizontalPadding: 0))
            .foregroundStyle(.primary)
            .tint(.primary)
        }
        .padding(12)
        .contentCard()
        .sheet(isPresented: $showsShare) {
            SystemShareSheet(items: [url])
        }
        .alert("Delete video?", isPresented: $showsDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This will permanently delete \"\(recording.title)\". This can't be undone.")
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
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recording.title)
                                .font(.appHeadline)
                                .foregroundStyle(.white)
                            Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.appCaption)
                                .foregroundStyle(.white.opacity(0.62))
                        }

                        Spacer()

                        Text(recording.durationText)
                            .font(.appCaptionEmphasis.monospacedDigit())
                            .foregroundStyle(.white)
                    }

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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
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
