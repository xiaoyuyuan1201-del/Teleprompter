import SwiftUI

@main
struct TeleprompterApp: App {
    @StateObject private var scriptStore = ScriptStore()
    @StateObject private var recordingStore = RecordingStore()
    @StateObject private var purchaseManager = PurchaseManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .environmentObject(scriptStore)
            .environmentObject(recordingStore)
            .environmentObject(purchaseManager)
            .tint(.creatorViolet)
        }
    }
}
