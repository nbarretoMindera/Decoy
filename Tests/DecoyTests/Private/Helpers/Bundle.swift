import Foundation

extension Bundle {
  static func testing() -> URL? {
    Bundle(for: DecoyTests.self).resourceURL?.appendingPathComponent("Decoy_DecoyTests.bundle")
  }

  static func testing(_ fileName: String) -> URL? {
    Bundle(for: DecoyTests.self).resourceURL?.appendingPathComponent("Decoy_DecoyTests.bundle").appendingPathComponent(fileName)
  }
}
