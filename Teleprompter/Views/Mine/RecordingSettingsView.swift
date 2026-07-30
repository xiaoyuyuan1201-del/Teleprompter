import SwiftUI

struct RecordingSettingsView: View {
    @AppStorage("defaultCameraPosition") private var defaultCameraPosition = "front"
    @AppStorage("defaultRecordingQuality") private var defaultRecordingQuality = "high"

    var body: some View {
        Form {
            Section {
                Picker("Default Camera", selection: $defaultCameraPosition) {
                    Text("Front").tag("front")
                    Text("Back").tag("back")
                }
            } header: {
                Text("Camera")
            } footer: {
                Text("Which camera opens when you start a new recording. You can still switch cameras from the record screen.")
            }

            Section {
                Picker("Recording Quality", selection: $defaultRecordingQuality) {
                    Text("1080p (Full HD)").tag("high")
                    Text("720p (HD, smaller files)").tag("standard")
                }
            } header: {
                Text("Quality")
            } footer: {
                Text("Higher quality looks sharper but creates larger video files.")
            }
        }
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
