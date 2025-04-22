import Foundation

/// Extension to `URL` providing safe, cross-version helpers for path management.
extension URL {
  /**
   Creates a file URL from a given path string, using the modern `filePath:` initializer on iOS 16 and later,
   and falling back to the legacy `fileURLWithPath:` initializer on earlier versions.
   
   This initializer ensures compatibility across different iOS versions by conditionally using the appropriate API.
   
   - Parameters:
     - path: The file system path string.
     - useNewAPI: An optional Boolean to override the automatic platform version check.
       If `true`, forces use of the new API (available on iOS 16+).
       If `false`, forces use of the legacy API.
       If `nil` (default), the API choice is determined based on the current platform version.
   
   - Note: This is a safe cross-version helper for creating file URLs from paths.
   */
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

  /**
   Appends a path component to the URL using the appropriate API for the platform version.
   
   This method uses the modern `append(path:)` method on iOS 16 and later,
   and falls back to the legacy `appendPathComponent(_:)` method on earlier versions.
   
   - Parameters:
     - path: The path component to append.
     - useNewAPI: An optional Boolean to override the automatic platform version check.
       If `true`, forces use of the new API (available on iOS 16+).
       If `false`, forces use of the legacy API.
       If `nil` (default), the API choice is determined based on the current platform version.
   
   - Note: This is a safe cross-version helper for appending path components to URLs.
   */
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
