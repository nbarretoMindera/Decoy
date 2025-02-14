import Foundation

struct APIClient {
  private let session: URLSession
  private let endpoint = "https://fruityvice.com/api/fruit/"

  func fetchApple(completion: @escaping (Fruit?) -> Void) {
    fetch("apple", completion: completion)
  }

  func fetchBanana(completion: @escaping (Fruit?) -> Void) {
    fetch("banana", completion: completion)
  }

  private func fetch(_ string: String, completion: @escaping (Fruit?) -> Void) {
    guard let url = URL(string: endpoint.appending(string)) else { return completion(nil) }

    session.dataTask(with: URLRequest(url: url)) { data, response, error in
      guard let data else { return completion(nil) }
      let decoder = JSONDecoder()
      let fruit = try? decoder.decode(Fruit.self, from: data)
      completion(fruit ?? nil)
    }.resume()
  }

  init(session: URLSession) {
    self.session = session
  }
}

struct Fruit: Decodable, Identifiable {
  let id: Int
  let name: String
}
