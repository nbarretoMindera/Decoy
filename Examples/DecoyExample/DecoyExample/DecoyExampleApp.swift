import Decoy
import SwiftUI

@main
struct DecoyExampleApp: App {
  @UIApplicationDelegateAdaptor var appDelegate: AppDelegate

  var body: some Scene {
    WindowGroup {
      if Decoy.isXCUI(), let urlSession = Decoy.urlSession {
        ContentView(api: APIClient(session: urlSession))
      } else {
        ContentView(api: APIClient(session: .shared))
      }
    }
  }
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
  ) -> Bool {
    Decoy.setUp()
    return true
  }
}
