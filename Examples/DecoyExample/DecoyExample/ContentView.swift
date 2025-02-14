import Decoy
import SwiftUI

struct ContentView: View {
  let api: APIClient

  @State var fruit: Fruit?

  var body: some View {
    VStack(spacing: 16) {
      Text(fruit?.name ?? "...")
      Button("Fetch Apple") { api.fetchApple { fruit = $0 } }
      Button("Fetch Banana") { api.fetchBanana { fruit = $0 } }
    }
  }
}

#Preview {
  ContentView(api: APIClient(session: Session()))
}
