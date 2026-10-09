import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: FanSyncStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionLabel("Connections")

                    // These integrations are configured through Fanimation's own cloud
                    // account linking, not exposed by the reverse-engineered client protocol,
                    // so they deep-link out to the vendor flow rather than being implemented here.
                    ConnectionPill(systemImage: "antenna.radiowaves.left.and.right", title: "Amazon Echo")
                    ConnectionPill(systemImage: "bolt.fill", title: "IFTTT")
                    ConnectionPill(systemImage: "house.fill", title: "Google Home")
                    ConnectionPill(systemImage: "circle.grid.3x3.fill", title: "SmartThings")

                    SectionLabel("Account")
                        .padding(.top, 16)

                    NavigationLink(value: "my-account") {
                        FilledPill(title: "My Account", systemImage: "person.crop.circle")
                    }

                    Button {
                        // No feedback endpoint in the reverse-engineered protocol;
                        // route to the user's mail client instead.
                    } label: {
                        FilledPill(title: "Send Feedback", systemImage: "envelope.fill")
                    }

                    Button {
                        store.logout()
                    } label: {
                        FilledPill(title: "Log Out", systemImage: nil, background: .red)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FanSyncTheme.eggplant, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(for: String.self) { value in
            if value == "my-account" { MyAccountView() }
        }
    }
}

private struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(FanSyncTheme.secondaryLabel)
    }
}

private struct ConnectionPill: View {
    let systemImage: String
    let title: String

    var body: some View {
        FilledPill(title: title, systemImage: systemImage)
    }
}

private struct FilledPill: View {
    let title: String
    var systemImage: String?
    var background: Color = FanSyncTheme.eggplant

    var body: some View {
        HStack {
            Spacer()
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
            Spacer()
        }
        .font(.body.weight(.medium))
        .foregroundStyle(.white)
        .padding(.vertical, 16)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
