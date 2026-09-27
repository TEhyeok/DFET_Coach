import FirebaseFirestore
import Foundation
import TrainerDomain

/// `JSONValue` to and from Firestore values (DF-104; DF-009 left the mapping out). `.serverTimestamp` becomes
/// `FieldValue.serverTimestamp()`, `.timestamp` a `Timestamp`, `.int` an `Int64`, `.bytes` `Data`.
enum JSONValueFirestoreMapper {
  static func firestore(_ value: JSONValue) -> Any {
    switch value {
    case .null: return NSNull()
    case let .bool(b): return b
    case let .number(d): return d
    case let .int(i): return i
    case let .string(s): return s
    case let .array(items): return items.map(firestore)
    case let .object(fields): return fields.mapValues(firestore)
    case let .timestamp(date): return Timestamp(date: date)
    case .serverTimestamp: return FieldValue.serverTimestamp()
    case let .bytes(data): return data
    }
  }

  /// Top-level document fields; the payload must be an object.
  static func fields(_ value: JSONValue) throws -> [String: Any] {
    guard case let .object(fields) = value else { throw RemoteError.invalidArgument }
    return fields.mapValues(firestore)
  }

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
