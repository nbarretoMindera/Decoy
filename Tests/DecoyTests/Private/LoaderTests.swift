import Foundation
import XCTest
@testable import Decoy

final class LoaderTests: XCTestCase {

  private var loader: Loader!

  override func setUp() {
    super.setUp()

    loader = Loader()
  }

  override func tearDown() {
    loader = nil

    super.tearDown()
  }

  func test_loadJSON_shouldReturnNil_whenFileNotFoundInBundle() {
    XCTAssertNil(loader.loadJSON(from: URL(string: "file:///Nope")!))
  }

  func test_loadJSON_shouldReturnNil_whenURLContainsNonJSONData() {
    guard let url = Bundle.module.url(forResource: "BadJSONTests", withExtension: "json") else {
      return XCTFail(#function)
    }

    XCTAssertNil(loader.loadJSON(from: url))
  }

  func test_loadJSON_shouldReturnParsedData() {
    guard let url = Bundle.module.url(forResource: "LoaderTests", withExtension: "json") else {
      return XCTFail(#function)
    }

    let result = loader.loadJSON(from: url)
    XCTAssertEqual(result![0].url.absoluteString, "https://testing-some-json")

    guard let expectedResult = try? JSONSerialization.data(withJSONObject: ["MOCKED OR WHATEVER"]) else {
      return XCTFail(#function)
    }

    XCTAssertEqual(result![0].response.data!, expectedResult)
  }

  func test_loadJSON_shouldNotParse_whenDictionaryHasNoURL() {
    guard let url = Bundle.module.url(forResource: "NoURLTest", withExtension: "json") else {
      return XCTFail(#function)
    }

    guard let result = loader.loadJSON(from: url) else {
      return XCTFail(#function)
    }

    XCTAssert(result.isEmpty)
  }

  func test_loadJSON_shouldNotParse_whenDictionaryHasURLWhichDoesNotParseIntoNSURL() {
    guard let url = Bundle.module.url(forResource: "BadURLTest", withExtension: "json") else {
      return XCTFail(#function)
    }

    guard let result = loader.loadJSON(from: url) else {
      return XCTFail(#function)
    }

    XCTAssert(result.isEmpty)
  }

  func test_loadJSON_shouldNotParse_whenDictionaryHasNoMock() {
    guard let url = Bundle.module.url(forResource: "NoMockTest", withExtension: "json") else {
      return XCTFail(#function)
    }

    guard let result = loader.loadJSON(from: url) else {
      return XCTFail(#function)
    }

    XCTAssert(result.isEmpty)
  }
}
