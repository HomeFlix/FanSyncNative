import SwiftUI

@main
struct FanSyncNativeApp: App {
    @StateObject private var store = FanSyncStore()
    @StateObject private var groupStore = DeviceGroupStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(groupStore)
        }
    }
}
