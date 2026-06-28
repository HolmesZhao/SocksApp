import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        SocksAppModel.shared.appendLog("[SOCKS] Application launched")
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        SocksAppModel.shared.appendLog("[SOCKS] Application will resign active state")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        SocksAppModel.shared.appendLog("[SOCKS] Application entered background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        SocksAppModel.shared.appendLog("[SOCKS] Application will enter foreground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        SocksAppModel.shared.appendLog("[SOCKS] Application became active")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        SocksAppModel.shared.appendLog("[SOCKS] Application will terminate")
    }
}
