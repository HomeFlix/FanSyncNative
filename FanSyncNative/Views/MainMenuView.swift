import SwiftUI

enum MainMenuDestination: Hashable {
    case home
    case myGroups
    case settings
    case support
}

/// Slide-out side menu matching the hamburger drawer in the reference app:
/// Home / My Groups / Settings / Support, with the logged-in account email
/// and app version pinned at the bottom.
struct MainMenuView: View {
    @EnvironmentObject var store: FanSyncStore
    let onSelect: (MainMenuDestination) -> Void

    private let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                FanSyncPinwheel(color: FanSyncTheme.eggplant, size: 26)
                    .padding(10)
                    .overlay(Circle().stroke(FanSyncTheme.eggplant, lineWidth: 1.5))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 20)

            MenuRow(title: "Home", showsChevron: true) { onSelect(.home) }
            MenuRow(title: "My Groups", showsChevron: true) { onSelect(.myGroups) }
            MenuRow(title: "Settings", showsChevron: true) { onSelect(.settings) }
            MenuRow(title: "Support", showsChevron: false) { onSelect(.support) }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(store.accountEmail ?? "")
                    .font(.subheadline)
                    .foregroundStyle(FanSyncTheme.onLabel)
                Text("v\(appVersion)")
                    .font(.caption)
                    .foregroundStyle(FanSyncTheme.secondaryLabel)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }
}

private struct MenuRow: View {
    let title: String
    var showsChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack {
                    Text(title.uppercased())
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(FanSyncTheme.onLabel)
                    Spacer()
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(FanSyncTheme.secondaryLabel)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                Divider()
            }
        }
        .buttonStyle(.plain)
    }
}

/// Generic container that hosts a primary screen plus a left-edge slide-out menu,
/// reused by every top-level destination so the hamburger button behaves the same everywhere.
struct WithSideMenu<Content: View>: View {
    @State private var menuOpen = false
    @State private var destination: MainMenuDestination?
    let content: (@escaping () -> Void) -> Content // pass the "open menu" action in

    init(@ViewBuilder content: @escaping (@escaping () -> Void) -> Content) {
        self.content = content
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                content { menuOpen = true }

                if menuOpen {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { menuOpen = false }
                        .transition(.opacity)

                    MainMenuView { dest in
                        menuOpen = false
                        if dest != .home { destination = dest } // Home is the root screen itself
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.78)
                    .ignoresSafeArea()
                    .transition(.move(edge: .leading))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: menuOpen)
            .navigationDestination(item: $destination) { dest in
                switch dest {
                case .home: EmptyView()
                case .myGroups: MyGroupsView()
                case .settings: SettingsView()
                case .support: SupportView()
                }
            }
        }
    }
}
