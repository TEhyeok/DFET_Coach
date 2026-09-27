import FirebaseFunctions
import Foundation
import os
import TrainerDomain

/// Callable Functions in the Seoul region only (AC-DF-104.7, NFR-16, ADR-017).
public final class FunctionsCallableClient: CallableClient, Sendable {
  private static let logger = Logger(subsystem: "kr.co.dfet.trainer", category: "remote")
  public static let region = FirebaseBootstrap.functionsRegion

  public init() {}

  public func call<T: Decodable & Sendable>(_ name: String, _ payload: JSONValue) async throws -> T {
    do {
      guard case .object = payload else { throw RemoteError.invalidArgument }
      let data = try Self.plain(payload)
      let result = try await Functions.functions(region: Self.region).httpsCallable(name).call(data)
      let json = try JSONSerialization.data(
        withJSONObject: result.data is NSNull ? [String: Any]() : result.data, options: [.fragmentsAllowed])
      return try JSONDecoder().decode(T.self, from: json)
    } catch {
      let remote = RemoteErrorMapper.map(error)
      Self.logger.error("callable \(name, privacy: .public) failed: \(remote.code, privacy: .public)")
      throw remote
    }
  }

  /// Callables take plain JSON: timestamps become ISO 8601 strings, bytes base64; a server-time placeholder has no
  /// meaning in a callable request.
  static func plain(_ value: JSONValue) throws -> Any {
    switch value {
    case .null: return NSNull()
    case let .bool(b): return b
    case let .number(d): return d
    case let .int(i): return i
    case let .string(s): return s
    case let .array(items): return try items.map(plain)
    case let .object(fields): return try fields.mapValues(plain)
    case let .timestamp(date): return isoMilliseconds(date)  // V1-06 §3: `2026-11-02T01:23:45.000Z`
    case .serverTimestamp: throw RemoteError.invalidArgument
    case let .bytes(data): return data.base64EncodedString()
    }
  }

  static func isoMilliseconds(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}
