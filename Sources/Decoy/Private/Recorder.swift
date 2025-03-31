import Foundation

public protocol RecorderInterface {
  /// Indicates whether API calls should be recorded.
  var shouldRecord: Bool { get }

  /// Records a network request and its associated response.
  func record(url: URL, data: Data?, response: URLResponse?, error: Error?)
}

public class Recorder: RecorderInterface {
  private let processInfo: ProcessInfo
  private let writer: WriterInterface
  // Each Recorder instance can have its own serial queue for local work,
  // but the actual file writing will be synchronized on the global writer queue.
  private let localQueue = DispatchQueue(label: "com.decoy.recorder")

  init(processInfo: ProcessInfo = .processInfo, writer: WriterInterface = Writer()) {
    self.processInfo = processInfo
    self.writer = writer
  }

  public var shouldRecord: Bool {
    processInfo.environment[Decoy.Constants.mode] == Decoy.Mode.record.rawValue
  }

  public func record(url: URL, data: Data?, response: URLResponse?, error: Error?) {
    localQueue.async {
      let stub = Stub(
        url: url,
        response: Stub.Response(
          data: data,
          urlResponse: response as? HTTPURLResponse,
          error: nil // Extend error handling as needed.
        )
      )
      // Immediately append the new recording to the file using the shared writer.
      try? self.writer.append(recording: stub.asJSON)
    }
  }
}
