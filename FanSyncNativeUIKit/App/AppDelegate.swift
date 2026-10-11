import UIKit

/// iOS 12 has no SceneDelegate (introduced iOS 13), so the window is created and its
/// root view controller assigned directly here.
@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    let groupStore = DeviceGroupStore()
    lazy var store = FanSyncStore(groupStore: groupStore)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // On iOS 13+ runtimes (e.g. this app built and run on a modern Simulator even
        // though it targets iOS 12), UIKit still creates a UIWindowScene behind the
        // scenes even with no scene manifest. A UIWindow built with a plain frame-based
        // initializer never attaches to that scene's actual display surface, so nothing
        // paints even though the window is "key and visible" and receives input. Joining
        // the window to the connected scene explicitly (when one exists) fixes this
        // without requiring a SceneDelegate, which iOS 12 doesn't have.
        let window: UIWindow
        if #available(iOS 13.0, *), let scene = application.connectedScenes.first as? UIWindowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window.rootViewController = RootViewController(store: store, groupStore: groupStore)
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
