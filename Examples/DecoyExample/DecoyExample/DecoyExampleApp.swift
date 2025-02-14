import Decoy
import SwiftUI

@main
struct DecoyExampleApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView(api: APIClient(session: Session(mocking: .shared)))
    }
  }
}
