import SwiftUI

/// A placeholder legal document screen — swap `body` for the real Privacy
/// Policy / Terms of Use text (or route to a hosted URL) before shipping.
struct LegalDocumentView: View {
    let title: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.appTitle)

                Text("This is a placeholder. Replace this text with the final \(title) before release.")
                    .font(.appBody)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
