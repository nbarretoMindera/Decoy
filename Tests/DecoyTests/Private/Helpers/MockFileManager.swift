import Foundation

class MockFileManager: FileManager {
  var didCallCreateDirectory = false

  override func createDirectory(
    at url: URL,
    withIntermediateDirectories createIntermediates: Bool,
    attributes: [FileAttributeKey: Any]? = nil
  ) throws {
    didCallCreateDirectory = true
  }
}
