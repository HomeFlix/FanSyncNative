import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: FanSyncStore

    var body: some View {
        Group {
            switch store.state {
            case .loggedOut, .loggingIn, .error:
                LoginView()
            case .connecting:
                ProgressView("Connecting…")
            case .ready:
                DeviceListView()
            }
        }
        .task {
            await store.restoreSession()
        }
    }
}
