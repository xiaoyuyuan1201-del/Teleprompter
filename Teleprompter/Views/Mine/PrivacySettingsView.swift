import AVFoundation
import Photos
import SwiftUI

struct PrivacySettingsView: View {
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var photosStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)

    var body: some View {
        Form {
            Section {
                permissionRow(title: "Camera", systemImage: "camera.fill", status: cameraStatus.statusDescription)
                permissionRow(title: "Microphone", systemImage: "mic.fill", status: microphoneStatus.statusDescription)
                permissionRow(title: "Photos", systemImage: "photo.fill", status: photosStatus.statusDescription)
            } header: {
                Text("App Permissions")
            } footer: {
                Text("Teleprompter uses these to record video, capture audio, and save your videos to Photos.")
            }

            Section {
                Button("Open System Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            } footer: {
                Text("Manage or revoke camera, microphone, and photo access anytime from the Settings app.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: refreshStatuses)
    }

    private func refreshStatuses() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        photosStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }

    private func permissionRow(title: String, systemImage: String, status: String) -> some View {
        LabeledContent {
            Text(status)
                .foregroundStyle(.secondary)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

private extension AVAuthorizationStatus {
    var statusDescription: String {
        switch self {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not Requested"
        @unknown default: "Unknown"
        }
    }
}

private extension PHAuthorizationStatus {
    var statusDescription: String {
        switch self {
        case .authorized, .limited: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not Requested"
        @unknown default: "Unknown"
        }
    }
}
