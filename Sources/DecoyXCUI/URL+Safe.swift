import Foundation

extension URL {
  /// Initializes a `URL` safely by selecting the appropriate API based on iOS version.
  ///
  /// - Parameter path: The file path to convert into a `URL`.
  ///
  /// This method:
  /// - Uses `filePath:` on iOS 16+ for modern file handling.
  /// - Falls back to `fileURLWithPath:` on earlier versions.
  init(safePath path: String) {
    if #available(iOS 16, *) {
      self.init(filePath: path)
    } else {
      self.init(fileURLWithPath: path)
    }
  }

  /// Appends a path component safely by selecting the appropriate API based on iOS version.
  ///
  /// - Parameter path: The path component to append.
  ///
  /// This method:
  /// - Uses `append(path:)` on iOS 16+ for modern file path handling.
  /// - Falls back to `appendPathComponent(_:)` on earlier versions.
  mutating func safeAppend(path: String) {
    if #available(iOS 16, *) {
      append(path: path)
    } else {
      appendPathComponent(path)
    }
  }
}
