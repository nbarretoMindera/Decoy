import Foundation

public class MockFileManager: FileManager {
  public var didCallCreateDirectory = false

  public override func createDirectory(
    at url: URL,
    withIntermediateDirectories createIntermediates: Bool,
    attributes: [FileAttributeKey: Any]? = nil
  ) throws {
    didCallCreateDirectory = true
  }
}
