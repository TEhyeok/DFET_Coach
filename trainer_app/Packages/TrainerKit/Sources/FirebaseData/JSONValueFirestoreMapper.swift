import FirebaseFirestore
import Foundation
import TrainerDomain

/// `JSONValue` to and from Firestore values (DF-104; DF-009 left the mapping out). `.serverTimestamp` becomes
/// `FieldValue.serverTimestamp()`, `.timestamp` a `Timestamp`, `.int` an `Int64`, `.bytes` `Data`.
///
/// The SDK raises Objective-C exceptions, which Swift cannot catch, for values Firestore does not accept, so they are
/// refused here with `.invalidArgument`: an array directly inside an array, a server timestamp anywhere under an
/// array, an empty or reserved (`__…__`) field name, and a date outside 0001-01-01...9999-12-31. An array inside a map
/// inside an array is fine (posture `views[].landmarks`, SDK `ParseContext::ChildContext`).
enum JSONValueFirestoreMapper {
  /// Where a value sits: `directlyInArray` is reset by a map (it gates nested arrays); `underArray` is kept through
  /// maps (it gates server timestamps, which the SDK accepts only on a field path).
  struct Position {
    var directlyInArray = false
    var underArray = false

    static let top = Position()
  }

  static func firestore(_ value: JSONValue, at position: Position = .top) throws -> Any {
    switch value {
    case .null: return NSNull()
    case let .bool(b): return b
    case let .number(d): return d
    case let .int(i): return i
    case let .string(s): return s
    case let .array(items):
      guard !position.directlyInArray else { throw RemoteError.invalidArgument }  // an array directly in an array
      let element = Position(directlyInArray: true, underArray: true)
      return try items.map { try firestore($0, at: element) }
    case let .object(fields):
      return try map(fields, at: Position(directlyInArray: false, underArray: position.underArray))
    case let .timestamp(date):
      guard FirestorePayload.timestampRange.contains(date) else { throw RemoteError.invalidArgument }
      return Timestamp(date: date)
    case .serverTimestamp:
      guard !position.underArray else { throw RemoteError.invalidArgument }
      return FieldValue.serverTimestamp()
    case let .bytes(data): return data
    }
  }

  /// Top-level document fields; the payload must be an object.
  static func fields(_ value: JSONValue) throws -> [String: Any] {
    guard case let .object(fields) = value else { throw RemoteError.invalidArgument }
    return try map(fields, at: .top)
  }

  private static func map(_ fields: [String: JSONValue], at position: Position) throws -> [String: Any] {
    var out: [String: Any] = [:]
    for (key, value) in fields {
      guard FirestorePayload.isValidFieldName(key) else { throw RemoteError.invalidArgument }
      out[key] = try firestore(value, at: position)
    }
    return out
  }

  /// Firestore to `JSONValue`. Types this app never stores (GeoPoint, DocumentReference, vectors) become `.null`.
  static func json(_ value: Any?) -> JSONValue {
    switch value {
    case nil, is NSNull: return .null
    case let timestamp as Timestamp: return .timestamp(timestamp.dateValue())
    case let data as Data: return .bytes(data)
    case let string as String: return .string(string)
    case let number as NSNumber: return jsonNumber(number)
    case let array as [Any]: return .array(array.map(json))
    case let dict as [String: Any]: return .object(dict.mapValues(json))
    default: return .null
    }
  }

  /// Firestore returns booleans as CFBoolean, integers as 64-bit and doubles as double NSNumbers.
  private static func jsonNumber(_ number: NSNumber) -> JSONValue {
    if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
    switch CFNumberGetType(number) {
    case .float32Type, .float64Type, .floatType, .doubleType, .cgFloatType: return .number(number.doubleValue)
    default: return .int(number.int64Value)
    }
  }
}

/// Checks that keep malformed paths and payloads away from the SDK, and the payload comparison of reconciliation.
enum FirestorePayload {
  /// Firestore `Timestamp` range.
  static let timestampRange: ClosedRange<Date> =
    Date(timeIntervalSince1970: -62_135_596_800)...Date(timeIntervalSince1970: 253_402_300_799)

  /// A document path: an even number (at least two) of non-empty segments, none `.`, `..` or `__name__`-shaped.
  static func validateDocumentPath(_ path: String) throws {
    let segments = path.split(separator: "/", omittingEmptySubsequences: false)
    guard segments.count >= 2, segments.count.isMultiple(of: 2),
          segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !isReserved($0) })
    else { throw RemoteError.invalidArgument }
  }

  /// `updateData` keys are dot-separated field paths: every part non-empty, not reserved, and free of `~*/[]`.
  static func validateUpdateKeys<Keys: Sequence>(_ keys: Keys) throws where Keys.Element == String {
    for key in keys {
      let parts = key.split(separator: ".", omittingEmptySubsequences: false)
      guard parts.allSatisfy({ !$0.isEmpty && !isReserved($0) }), key.rangeOfCharacter(from: forbiddenInPath) == nil
      else { throw RemoteError.invalidArgument }
    }
  }

  static func isValidFieldName(_ name: String) -> Bool {
    !name.isEmpty && !isReserved(Substring(name))
  }

  private static let forbiddenInPath = CharacterSet(charactersIn: "~*/[]")

  /// `__…__`, including `__` and `___` (SDK `user_data.cc`).
  private static func isReserved(_ segment: Substring) -> Bool {
    segment.hasPrefix("__") && segment.hasSuffix("__")
  }

  /// Whether the server document already holds every field of an update payload (V1-04 §10.5.3-4). Server-time
  /// fields are skipped (their value is the server's); numbers compare by value, so `1` equals `1.0`. A missing field
  /// is not `null` (V1-10 §6.1): only a stored null matches `.null`.
  static func serverHas(_ payload: [String: JSONValue], in server: [String: Any]) -> Bool {
    payload.allSatisfy { key, value in
      if case .serverTimestamp = value { return true }
      let path = key.split(separator: ".").map(String.init)
      guard let stored = lookup(path, in: server) else { return false }
      return equal(value, JSONValueFirestoreMapper.json(stored))
    }
  }

  /// The value at a dot path; nil when a segment is missing or not a map.
  private static func lookup(_ path: [String], in fields: [String: Any]) -> Any? {
    guard let first = path.first else { return nil }
    let value = fields[first]
    if path.count == 1 { return value }
    guard let nested = value as? [String: Any] else { return nil }
    return lookup(Array(path.dropFirst()), in: nested)
  }

  private static func equal(_ local: JSONValue, _ server: JSONValue) -> Bool {
    switch (local, server) {
    case let (.int(a), .number(b)), let (.number(b), .int(a)): return Double(a) == b
    case let (.timestamp(a), .timestamp(b)): return abs(a.timeIntervalSince(b)) < 0.000_001  // server keeps µs
    case let (.array(a), .array(b)): return a.count == b.count && zip(a, b).allSatisfy(equal)
    case let (.object(a), .object(b)):
      return a.count == b.count && a.allSatisfy { key, value in b[key].map { equal(value, $0) } ?? false }
    case (.serverTimestamp, _): return true
    default: return local == server
    }
  }
}
