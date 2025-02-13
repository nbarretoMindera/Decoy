import Foundation

protocol RecorderInterface {
  var recordings: [[String: Any]] { get set }
  var shouldRecord: Bool { get }

  func record(url: URL, data: Data?, response: URLResponse?, error: Error?)
}

/// Used to record all API calls which come through the Decoy' `session`.
class Recorder: RecorderInterface {
  /// An array of each recorded response in the current app session.
  var recordings = [[String: Any]]()

  private let processInfo: ProcessInfo
  private let writer: WriterInterface

  init(processInfo: ProcessInfo = .processInfo, writer: WriterInterface = Writer()) {
    self.processInfo = processInfo
    self.writer = writer
  }

  /// Whether or not the app is running in the context of recording tests, as determined by
  /// the provided `ProcessInfo` object's launch environment..
  var shouldRecord: Bool {
    processInfo.environment[Decoy.Constants.isRecording] == String(true)
  }

  /// Makes a recording of the provided data, response, and error to the specifed URL.
  ///
  /// - Parameters:
  ///   - url: The URL to which the call being mocked was made.
  ///   - data: Optionally, the data returned from the call.
  ///   - response: Optionally, the URL response returned from the call.
  ///   - error: Optionally, the error returned from the call.
  func record(url: URL, data: Data?, response: URLResponse?, error: Error?) {
    let Stub = Stub(
      url: url,
      response: Stub.Response(
        data: data,
        urlResponse: response as? HTTPURLResponse,
        error: nil
      )
    )

    recordings.insert(Stub.asJSON, at: 0)

    try? writer.write(recordings: recordings)
  }
}
