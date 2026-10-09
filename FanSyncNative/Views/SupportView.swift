import SwiftUI

struct SupportView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(FanSyncTheme.secondaryLabel)
                Text("Support")
                    .font(.title2.weight(.medium))
                Text("This is an unofficial client. For device support, contact Fanimation directly.")
                    .font(.subheadline)
                    .foregroundStyle(FanSyncTheme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FanSyncTheme.eggplant, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
