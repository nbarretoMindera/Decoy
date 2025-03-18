import Foundation

extension URL {
  init(safePath path: String, useNewAPI: Bool? = nil) {
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

  mutating func safeAppend(path: String, useNewAPI: Bool? = nil) {
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
