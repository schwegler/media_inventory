import UIKit
import HotwireNative

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Hotwire with path configuration
        let localPathConfigURL = Bundle.main.url(forResource: "path-configuration", withExtension: "json")!
        Hotwire.loadPathConfiguration(from: [
            .file(localPathConfigURL),
            .server(Server.pathConfigurationURL)
        ])

        // Register custom bridge components
        Hotwire.registerBridgeComponents([
            FlashMessageComponent.self
        ])

        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
