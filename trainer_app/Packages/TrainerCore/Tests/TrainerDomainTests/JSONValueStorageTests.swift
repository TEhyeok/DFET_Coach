import Foundation
import XCTest
@testable import TrainerDomain

/// The LocalStore payload form (DF-108): every case round-trips, and plain object keys that look like tags stay data.
final class JSONValueStorageTests: XCTestCase {
  func testEveryCaseRoundTrips() throws {
    let value: JSONValue = .object([
      "int": .int(-42), "double": .number(1.5), "bool": .bool(true), "null": .null, "text": .string("가상"),
      "time": .timestamp(Date(timeIntervalSince1970: 1_780_282_800.123456)), "server": .serverTimestamp,
      "bytes": .bytes(Data([0, 1, 255])), "list": .array([.int(1), .object(["k": .string("v")])]),
    ])
    XCTAssertEqual(try JSONValue(storageData: value.storageData()), value)
  }

  /// Review M3: `{"$note": …}` in a payload was read back as an unknown tag and the row was dropped.
  func testKeysThatLookLikeTagsAreKeptAsData() throws {
    let value: JSONValue = .object([
      "meta": .object(["$note": .string("x"), "$int": .string("not a tag"), "~tilde": .int(1), "~~two": .bool(false)]),
      "list": .array([.object(["$ts": .number(3)])]),
      "plain": .string("$value stays"),
    ])
    XCTAssertEqual(try JSONValue(storageData: value.storageData()), value)
  }
}
