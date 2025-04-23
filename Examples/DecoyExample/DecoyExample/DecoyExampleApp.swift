import Decoy
import SwiftUI

@main
struct DecoyExampleApp: App {
  @UIApplicationDelegateAdaptor var appDelegate: AppDelegate

  var body: some Scene {
    WindowGroup {
      ContentView(api: api)
    }
  }

  /// If we're in an XCUI environment and Decoy has been set up with a session, use it in our `APIClient` so that calls
  /// to it will be intercepted. If we're not XCUI or there's no Decoy setup (i.e. in your app when not attached to XCUI),
  /// use your normal `URLSession`, in this instance the default `.shared` instance.
  var api: APIClient {
    Decoy.isXCUI ? APIClient(session: .decoy) : APIClient(session: .shared)
  }
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
  ) -> Bool {
    /// As early as possible in your app launch process, instantiate Decoy and call `setUp()`.
    /// This will set up Decoy to begin intercepting traffic.
    Decoy.setUp()
    return true
  }
}
