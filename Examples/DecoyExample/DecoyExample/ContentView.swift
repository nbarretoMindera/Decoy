import SwiftUI

struct ContentView: View {
  let api: APIClient

  @State var fruit: Fruit?
  @State var catFact: String?

  var body: some View {
    VStack(spacing: 16) {
      Text(fruit?.name ?? "...")
      Button("Fetch Apple (Closure)") { api.fetchApple { fruit = $0 } }
      Button("Fetch Banana (Closure)") { api.fetchBanana { fruit = $0 } }
      Button("Fetch Cat Fact (Closure)") { api.fetchCatFact { catFact = $0 } }
      Button("Fetch Apple (Async)") { Task { fruit = try await api.fetchApple() } }
      Button("Fetch Banana (Async)") { Task { fruit = try await api.fetchBanana() } }
      Button("Fetch Cat Fact (Async)") { Task { catFact = try await api.fetchCatFact() } }
      Text(catFact ?? "...")
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}
