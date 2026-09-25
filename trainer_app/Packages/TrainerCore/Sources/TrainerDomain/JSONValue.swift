import Foundation

/// A Firestore-shaped JSON value (DF-009, P0 DF-005 fixture contract rule 2).
///
/// Plain JSON has no timestamp, server-time placeholder, bytes or integer type, but Firestore does.
/// The cross-client fixture notation adds four tags for them, and this enum has one case for each:
///
/// | fixture notation              | case               |
/// |-------------------------------|--------------------|
/// | `{"$ts": "<ISO 8601>"}`       | `.timestamp(Date)` |
/// | `{"$serverTimestamp": true}`  | `.serverTimestamp` |
/// | `{"$bytes": "<base64>"}`      | `.bytes(Data)`     |
/// | `{"$int": n}`                 | `.int(Int64)`      |
/// | bare number                   | `.number(Double)`  |
///
/// Equality is structural: objects compare without key order, a missing key and a `null` value are
/// different, `number` compares by value (45 == 45.0) and `int` never equals `number`.
/// Mapping Firestore SDK types to and from this enum belongs to FirebaseData (DF-104).
public enum JSONValue: Equatable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case int(Int64)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])
  case timestamp(Date)
  case serverTimestamp
  case bytes(Data)

  public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null), (.serverTimestamp, .serverTimestamp): return true
    case let (.bool(a), .bool(b)): return a == b
    case let (.number(a), .number(b)): return a == b
    case let (.int(a), .int(b)): return a == b
    case let (.string(a), .string(b)): return a == b
    case let (.array(a), .array(b)): return a == b
    case let (.object(a), .object(b)): return a == b
    case let (.timestamp(a), .timestamp(b)): return a == b
    case let (.bytes(a), .bytes(b)): return a == b
    default: return false
    }
  }

  // MARK: Accessors

  public var objectValue: [String: JSONValue]? {
    if case let .object(value) = self { return value }
    return nil
  }

  public var arrayValue: [JSONValue]? {
    if case let .array(value) = self { return value }
    return nil
  }

  public var stringValue: String? {
    if case let .string(value) = self { return value }
    return nil
  }

  public var boolValue: Bool? {
    if case let .bool(value) = self { return value }
    return nil
  }

  /// `.int`, or a `.number` with an integral value that fits in Int64.
  public var integerValue: Int64? {
    switch self {
    case let .int(value): return value
    case let .number(value):
      guard value.isFinite, value == value.rounded(), abs(value) < 9_223_372_036_854_775_808 else { return nil }
      return Int64(value)
    default: return nil
    }
  }

  /// `.number`, or an `.int` as a Double. Non-finite numbers are nil.
  public var doubleValue: Double? {
    switch self {
    case let .number(value): return value.isFinite ? value : nil
    case let .int(value): return Double(value)
    default: return nil
    }
  }

  public subscript(key: String) -> JSONValue? {
    objectValue?[key]
  }
}

// MARK: - Fixture envelope

/// `_fixture` of a contract fixture envelope (contracts/fixtures/README.md §1, §5).
public struct FixtureMeta: Equatable, Sendable {
  public var id: String
  public var description: String
  /// `synthetic` (hand-written), `dart` (DF-007 record mode) or `swift` (DF-009 record mode).
  public var writer: String
  public var prdRefs: [String]
  public var expect: FixtureExpect

  public init(id: String, description: String, writer: String, prdRefs: [String], expect: FixtureExpect) {
    self.id = id
    self.description = description
    self.writer = writer
    self.prdRefs = prdRefs
    self.expect = expect
  }
}

/// `_fixture.expect`. Only the keys that apply to a file are present.
public struct FixtureExpect: Equatable, Sendable {
  public var roundTrip: String?
  public var metricCount: Int?
  public var uninterpretable: Int?
  public var legacyMetricCount: Int?

  public init(roundTrip: String? = nil, metricCount: Int? = nil, uninterpretable: Int? = nil, legacyMetricCount: Int? = nil) {
    self.roundTrip = roundTrip
    self.metricCount = metricCount
    self.uninterpretable = uninterpretable
    self.legacyMetricCount = legacyMetricCount
  }
}

/// A fixture file that breaks the envelope or tag rules.
public struct FixtureFormatError: Error, Equatable, CustomStringConvertible, Sendable {
  public let location: String
  public let message: String

  public init(_ location: String, _ message: String) {
    self.location = location
    self.message = message
  }

  public var description: String { "\(location): \(message)" }
}

extension JSONValue {
  /// The four tag keys of fixture rule 2. Any other `$` key is an error (V1-10 §6.1).
  public static let fixtureTags: Set<String> = ["$ts", "$serverTimestamp", "$bytes", "$int"]

  /// Splits a fixture file into `_fixture`, `path` and `data`, turning the tags in `data` into cases.
  ///
  /// Fails when the top level does not have exactly the keys `_fixture`, `path` and `data`, when
  /// `_fixture` does not have exactly `id`, `description`, `writer`, `prdRefs` and `expect`, when a
  /// `$` key appears outside `data`, or when `data` holds an unknown or malformed tag.
  public static func decodeFixture(_ data: Data) throws -> (meta: FixtureMeta, path: String, data: JSONValue) {
    let top: Any
    do {
      top = try JSONSerialization.jsonObject(with: data, options: [])
    } catch {
      throw FixtureFormatError("fixture", "not JSON: \(error.localizedDescription)")
    }
    guard let envelope = top as? [String: Any] else {
      throw FixtureFormatError("fixture", "top level is not an object")
    }
    guard Set(envelope.keys) == ["_fixture", "path", "data"] else {
      throw FixtureFormatError("fixture", "envelope keys \(envelope.keys.sorted()), expected [_fixture, path, data]")
    }
    let fixture = try plain(envelope["_fixture"]!, at: "_fixture")
    let path = try plain(envelope["path"]!, at: "path")
    guard case let .string(pathString) = path else {
      throw FixtureFormatError("path", "not a string")
    }
    let meta = try FixtureMeta(fixture)
    let value = try fromFixtureNotation(envelope["data"]!, at: "data")
    return (meta, pathString, value)
  }

  /// The envelope in the fixture file format: `JSON.stringify(doc, null, 2) + "\n"` (UTF-8, LF,
  /// two-space indent). Object keys follow `keyOrder` (lower rank first; keys without a rank come
  /// after, by name), because Swift dictionaries have no order and record-mode output must be stable.
  public static func encodeFixture(
    meta: FixtureMeta, path: String, data: JSONValue, keyOrder: [String] = []
  ) -> Data {
    var expect: [String: JSONValue] = [:]
    if let v = meta.expect.roundTrip { expect["roundTrip"] = .string(v) }
    if let v = meta.expect.metricCount { expect["metricCount"] = .number(Double(v)) }
    if let v = meta.expect.uninterpretable { expect["uninterpretable"] = .number(Double(v)) }
    if let v = meta.expect.legacyMetricCount { expect["legacyMetricCount"] = .number(Double(v)) }
    let envelope: JSONValue = .object([
      "_fixture": .object([
        "id": .string(meta.id),
        "description": .string(meta.description),
        "writer": .string(meta.writer),
        "prdRefs": .array(meta.prdRefs.map(JSONValue.string)),
        "expect": .object(expect),
      ]),
      "path": .string(path),
      "data": data,
    ])
    let ranks = Dictionary(
      (envelopeKeyOrder + keyOrder).enumerated().map { ($0.element, $0.offset) },
      uniquingKeysWith: { first, _ in first })
    var out = ""
    CanonicalJSONWriter(ranks: ranks).write(envelope, indent: 0, into: &out)
    out += "\n"
    return Data(out.utf8)
  }

  /// Fixed order of the envelope and `_fixture` keys (contracts/fixtures/README.md §1).
  static let envelopeKeyOrder = [
    "_fixture", "id", "description", "writer", "prdRefs", "expect",
    "roundTrip", "metricCount", "uninterpretable", "legacyMetricCount", "path", "data",
  ]

  /// Fixture notation (a `JSONSerialization` tree) to `JSONValue`.
  static func fromFixtureNotation(_ json: Any, at location: String) throws -> JSONValue {
    switch json {
    case is NSNull:
      return .null
    case let string as String:
      return .string(string)
    case let number as NSNumber:
      if number.isJSONBool { return .bool(number.boolValue) }
      return .number(number.doubleValue)
    case let array as [Any]:
      return .array(try array.enumerated().map { try fromFixtureNotation($0.element, at: "\(location)/\($0.offset)") })
    case let object as [String: Any]:
      if object.keys.contains(where: { $0.hasPrefix("$") }) {
        return try decodeTag(object, at: location)
      }
      var out: [String: JSONValue] = [:]
      for (key, value) in object {
        out[key] = try fromFixtureNotation(value, at: "\(location)/\(key)")
      }
      return .object(out)
    default:
      throw FixtureFormatError(location, "unsupported JSON value \(type(of: json))")
    }
  }

  private static func decodeTag(_ object: [String: Any], at location: String) throws -> JSONValue {
    guard object.count == 1, let entry = object.first else {
      throw FixtureFormatError(location, "tag object must have exactly one key: \(object.keys.sorted())")
    }
    let (key, value) = (entry.key, entry.value)
    switch key {
    case "$ts":
      if let text = value as? String {
        guard let date = FixtureTimestamp.parse(text) else {
          throw FixtureFormatError(location, "$ts is not ISO 8601 with Z or an offset: \(text)")
        }
        return .timestamp(date)
      }
    case "$serverTimestamp":
      if let flag = value as? NSNumber, flag.isJSONBool, flag.boolValue { return .serverTimestamp }
    case "$bytes":
      if let text = value as? String, let bytes = Data(base64Encoded: text) { return .bytes(bytes) }
    case "$int":
      if let number = value as? NSNumber, !number.isJSONBool, !CFNumberIsFloatType(number) {
        return .int(number.int64Value)
      }
    default:
      throw FixtureFormatError(location, "unknown tag \(key) (allowed: \(fixtureTags.sorted()))")
    }
    throw FixtureFormatError(location, "bad \(key) value \(value)")
  }

  /// `_fixture` and `path`: plain JSON, no `$` key anywhere (contracts/fixtures/README.md §5).
  private static func plain(_ json: Any, at location: String) throws -> JSONValue {
    if let object = json as? [String: Any] {
      var out: [String: JSONValue] = [:]
      for (key, value) in object {
        if key.hasPrefix("$") {
          throw FixtureFormatError("\(location)/\(key)", "$ keys are allowed only inside data")
        }
        out[key] = try plain(value, at: "\(location)/\(key)")
      }
      return .object(out)
    }
    if let array = json as? [Any] {
      return .array(try array.enumerated().map { try plain($0.element, at: "\(location)/\($0.offset)") })
    }
    return try fromFixtureNotation(json, at: location)
  }
}

extension FixtureMeta {
  fileprivate init(_ value: JSONValue) throws {
    guard case let .object(object) = value else { throw FixtureFormatError("_fixture", "not an object") }
    guard Set(object.keys) == ["id", "description", "writer", "prdRefs", "expect"] else {
      throw FixtureFormatError("_fixture", "keys \(object.keys.sorted()), expected [description, expect, id, prdRefs, writer]")
    }
    guard let id = object["id"]?.stringValue, let description = object["description"]?.stringValue,
      let writer = object["writer"]?.stringValue,
      let refs = object["prdRefs"]?.arrayValue, case let prdRefs = refs.compactMap(\.stringValue),
      prdRefs.count == refs.count,
      case let .object(expect)? = object["expect"]
    else {
      throw FixtureFormatError("_fixture", "id, description, writer must be strings, prdRefs strings, expect an object")
    }
    let known: Set<String> = ["roundTrip", "metricCount", "uninterpretable", "legacyMetricCount"]
    if let unknown = expect.keys.first(where: { !known.contains($0) }) {
      throw FixtureFormatError("_fixture/expect", "unknown key \(unknown)")
    }
    func count(_ key: String) throws -> Int? {
      guard let value = expect[key] else { return nil }
      guard let n = value.integerValue else { throw FixtureFormatError("_fixture/expect/\(key)", "not an integer") }
      return Int(n)
    }
    self.init(
      id: id, description: description, writer: writer, prdRefs: prdRefs,
      expect: FixtureExpect(
        roundTrip: expect["roundTrip"]?.stringValue,
        metricCount: try count("metricCount"),
        uninterpretable: try count("uninterpretable"),
        legacyMetricCount: try count("legacyMetricCount")))
  }
}

extension NSNumber {
  /// JSONSerialization returns JSON booleans as the CFBoolean singletons.
  fileprivate var isJSONBool: Bool { CFGetTypeID(self) == CFBooleanGetTypeID() }
}

// MARK: - `$ts`

/// `$ts` text: `yyyy-MM-ddTHH:mm:ss[.fraction](Z|±HH:MM)`. The offset only locates the instant.
public enum FixtureTimestamp {
  public static func parse(_ text: String) -> Date? {
    let chars = Array(text.utf8)
    func digits(_ start: Int, _ count: Int) -> Int? {
      guard start + count <= chars.count else { return nil }
      var value = 0
      for c in chars[start..<start + count] {
        guard c >= 0x30, c <= 0x39 else { return nil }
        value = value * 10 + Int(c - 0x30)
      }
      return value
    }
    func char(_ i: Int, _ c: Character) -> Bool { i < chars.count && chars[i] == c.asciiValue! }
    guard let year = digits(0, 4), char(4, "-"), let month = digits(5, 2), char(7, "-"), let day = digits(8, 2),
      char(10, "T"), let hour = digits(11, 2), char(13, ":"), let minute = digits(14, 2), char(16, ":"),
      let second = digits(17, 2)
    else { return nil }
    var i = 19
    var fraction = 0.0
    if char(i, ".") {
      i += 1
      var scale = 0.1
      let start = i
      while i < chars.count, chars[i] >= 0x30, chars[i] <= 0x39 {
        fraction += Double(chars[i] - 0x30) * scale
        scale /= 10
        i += 1
      }
      guard i > start, i - start <= 9 else { return nil }
    }
    var offset = 0
    if char(i, "Z") {
      i += 1
    } else if char(i, "+") || char(i, "-") {
      let sign = chars[i] == UInt8(ascii: "-") ? -1 : 1
      guard let oh = digits(i + 1, 2), char(i + 3, ":"), let om = digits(i + 4, 2), oh < 24, om < 60 else { return nil }
      offset = sign * (oh * 3600 + om * 60)
      i += 6
    } else {
      return nil
    }
    guard i == chars.count, (1...12).contains(month), hour < 24, minute < 60, second < 60 else { return nil }
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    guard let base = utcCalendar.date(from: components),
      utcCalendar.component(.day, from: base) == day
    else { return nil }
    return base.addingTimeInterval(fraction - Double(offset))
  }

  /// UTC, whole seconds, a fraction (up to microseconds, trailing zeros removed) only when non-zero, `Z`.
  /// The same notation the Dart codec writes (`formatFixtureTimestamp`).
  public static func format(_ date: Date) -> String {
    let micros = (date.timeIntervalSince1970 * 1_000_000).rounded()
    let seconds = (micros / 1_000_000).rounded(.down)
    let fraction = Int(micros - seconds * 1_000_000)
    let whole = Date(timeIntervalSince1970: seconds)
    let c = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: whole)
    func pad(_ n: Int?, _ width: Int) -> String {
      let s = String(n ?? 0)
      return String(repeating: "0", count: max(0, width - s.count)) + s
    }
    var text = "\(pad(c.year, 4))-\(pad(c.month, 2))-\(pad(c.day, 2))T\(pad(c.hour, 2)):\(pad(c.minute, 2)):\(pad(c.second, 2))"
    if fraction != 0 {
      var digits = pad(fraction, 6)
      while digits.hasSuffix("0") { digits.removeLast() }
      text += ".\(digits)"
    }
    return text + "Z"
  }

  private static let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()
}

// MARK: - Canonical writer

/// Writes `JSON.stringify(value, null, 2)` text with tags for the Firestore-only cases.
private struct CanonicalJSONWriter {
  let ranks: [String: Int]

  func write(_ value: JSONValue, indent: Int, into out: inout String) {
    switch value {
    case .null: out += "null"
    case let .bool(b): out += b ? "true" : "false"
    case let .number(n): out += Self.number(n)
    case let .int(n): writeTag("$int", String(n), indent: indent, into: &out)
    case let .string(s): out += Self.quote(s)
    case let .timestamp(date): writeTag("$ts", Self.quote(FixtureTimestamp.format(date)), indent: indent, into: &out)
    case .serverTimestamp: writeTag("$serverTimestamp", "true", indent: indent, into: &out)
    case let .bytes(data): writeTag("$bytes", Self.quote(data.base64EncodedString()), indent: indent, into: &out)
    case let .array(items):
      if items.isEmpty {
        out += "[]"
        return
      }
      out += "[\n"
      for (i, item) in items.enumerated() {
        out += Self.pad(indent + 1)
        write(item, indent: indent + 1, into: &out)
        out += i == items.count - 1 ? "\n" : ",\n"
      }
      out += Self.pad(indent) + "]"
    case let .object(object):
      if object.isEmpty {
        out += "{}"
        return
      }
      let keys = object.keys.sorted { a, b in
        switch (ranks[a], ranks[b]) {
        case let (ra?, rb?): return ra < rb
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return a < b
        }
      }
      out += "{\n"
      for (i, key) in keys.enumerated() {
        out += Self.pad(indent + 1) + Self.quote(key) + ": "
        write(object[key]!, indent: indent + 1, into: &out)
        out += i == keys.count - 1 ? "\n" : ",\n"
      }
      out += Self.pad(indent) + "}"
    }
  }

  private func writeTag(_ tag: String, _ literal: String, indent: Int, into out: inout String) {
    out += "{\n" + Self.pad(indent + 1) + Self.quote(tag) + ": " + literal + "\n" + Self.pad(indent) + "}"
  }

  private static func pad(_ level: Int) -> String { String(repeating: "  ", count: level) }

  /// JavaScript number text: integral values below 1e21 without a fraction or exponent, others the
  /// shortest round-trip text.
  static func number(_ n: Double) -> String {
    guard n.isFinite else { return "null" }  // JSON.stringify writes NaN/Infinity as null
    if n == 0 { return "0" }  // JSON.stringify(-0) is "0"
    if n == n.rounded(), abs(n) < 1e21 { return String(format: "%.0f", n) }
    return "\(n)"
  }

  /// JSON.stringify string escaping: `"`, `\`, and control characters; everything else as is.
  static func quote(_ s: String) -> String {
    var out = "\""
    for scalar in s.unicodeScalars {
      switch scalar {
      case "\"": out += "\\\""
      case "\\": out += "\\\\"
      case "\n": out += "\\n"
      case "\r": out += "\\r"
      case "\t": out += "\\t"
      case "\u{08}": out += "\\b"
      case "\u{0C}": out += "\\f"
      default:
        if scalar.value < 0x20 {
          let hex = String(scalar.value, radix: 16)
          out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
        } else {
          out.unicodeScalars.append(scalar)
        }
      }
    }
    return out + "\""
  }
}
