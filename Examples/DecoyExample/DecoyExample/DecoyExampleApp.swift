import Decoy
import SwiftUI

@main
struct DecoyExampleApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView(session: session)
    }
  }

  var session: URLSession {
    Session()
  }
}
