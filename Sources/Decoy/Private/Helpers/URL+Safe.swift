import Foundation

/// An extension to URL providing safe initializers and methods for working with file paths.
/// This extension abstracts differences between older APIs and the new file path APIs introduced in iOS 16.
extension URL {

  /// Initializes a URL using a file path in a safe manner.
  ///
  /// This initializer checks whether the new file path API is available (iOS 16 and later) and uses it if possible.
  /// Otherwise, it falls back to using the older `init(fileURLWithPath:)` initializer.
  ///
  /// - Parameters:
  ///   - path: A string representing the file system path.
  ///   - useNewAPI: An optional Boolean flag to explicitly indicate whether to use the new API.
  ///                If `nil`, the decision is made automatically based on the operating system version.
  public init(safePath path: String, useNewAPI: Bool? = nil) {
    let shouldUseNewAPI = useNewAPI ?? {
      if #available(iOS 16, *) { return true }
      return false
    }()

    if shouldUseNewAPI, #available(iOS 16, *) {
      self.init(filePath: path)
    } else {
      self.init(fileURLWithPath: path)
    }
  }

  /// Appends a path component to the URL in a safe manner.
  ///
  /// This method checks whether the new API for appending path components is available (iOS 16 and later)
  /// and uses it if possible. Otherwise, it falls back to using the older `appendPathComponent(_:)` method.
  ///
  /// - Parameters:
  ///   - path: A string representing the path component to append.
  ///   - useNewAPI: An optional Boolean flag to explicitly indicate whether to use the new API.
  ///                If `nil`, the decision is made automatically based on the operating system version.
  public mutating func safeAppend(path: String, useNewAPI: Bool? = nil) {
    let shouldUseNewAPI = useNewAPI ?? {
      if #available(iOS 16, *) { return true }
      return false
    }()

    if shouldUseNewAPI, #available(iOS 16, *) {
      self.append(path: path)
    } else {
      self.appendPathComponent(path)
    }
  }
}
