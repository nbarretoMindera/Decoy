import Decoy
import SwiftUI

@main
struct DecoyExampleApp: App {
  var body: some Scene {
    WindowGroup {
      /// Here, the APIClient expects a `URLSession`.
      /// Decoy can tell us if we're UI testing or not.
      /// If we are, we inject a Decoy `Session` mocking the `.shared` singleton instance.
      /// If not, we pass in the standard singleton, meaning in production code, Decoy is not used.
      if Decoy.isXCUI() {
        ContentView(api: APIClient(session: Session(mocking: .shared)))
      } else {
        ContentView(api: APIClient(session: .shared))
      }
    }
  }
}
