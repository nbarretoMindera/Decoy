import Foundation

extension URL {
  init(safePath path: String) {
    if #available(iOS 16, *) {
      self.init(filePath: path)
    } else {
      self.init(fileURLWithPath: path)
    }
  }

  /// Safely appends a path component to the URL, using the modern `append(path:)` API on iOS 16 and later, or falling back to `appendPathComponent(_:)` on earlier versions.
  ///
  /// This method is intended to ensure forward compatibility across platform versions when working with file paths.
  /// - Parameter path: The path component to append.
  mutating func safeAppend(path: String) {
    if #available(iOS 16, *) {
      append(path: path)
    } else {
      appendPathComponent(path)
    }
  }
}
