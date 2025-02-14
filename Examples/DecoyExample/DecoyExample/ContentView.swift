import Decoy
import SwiftUI

struct ContentView: View {
  let api: APIClient

  @State var fruit: Fruit?
  @State var catFact: String?

  var body: some View {
    VStack(spacing: 16) {
      Text(fruit?.name ?? "...")
      Button("Fetch Apple") { api.fetchApple { fruit = $0 } }
      Button("Fetch Banana") { api.fetchBanana { fruit = $0 } }
      Button("Fetch Cat Fact") { api.fetchCatFact { catFact = $0 } }
      Text(catFact ?? "...")
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}

#Preview {
  ContentView(api: APIClient(session: Session()))
}
