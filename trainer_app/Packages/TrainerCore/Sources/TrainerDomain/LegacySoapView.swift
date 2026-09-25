import Foundation
import TrainerContracts

// Read-only view of a v1 (legacy) SOAP document (DF-009, AC-SOAP-06.2, V1-05 §5.6, PRD §11.4).
// Same rules as the Dart `LegacySoapView` (lib/models/legacy_soap_view.dart, DF-007).
//
// v1 documents have no `schemaVersion`. The view keeps every `structured.metrics` row and shows each one
// as 'uninterpretable' (해석 불가): no legacy row carries the condition fields a v2 metric needs
// (joint·motion·activeOrPassive, muscleGroup), so even a parsable number is not a catalog metric
// (V1-05 §5.6). Legacy notations (`ROM`, `통증`, `좌`, `도`, `작성 중`, ...) are kept as text and never
// mapped onto the contract enums, and values are never filled with 0 or with demo text.
//
// The view does not expose `diagnosis` (MIG-04) and has no write path: the stored document is private,
// and no public property returns `diagnosis` or an object that contains it.

/// One `structured.metrics[]` row of a v1 document, kept as stored.
public struct LegacyMetricView: Equatable, Sendable {
  /// The stored element. Normally an object with `type, label, side, value, unit, score, note`.
  public let source: JSONValue

  public init(_ source: JSONValue) {
    self.source = source
  }

  /// The stored row, or an empty object when the element is not an object.
  public var raw: [String: JSONValue] { source.objectValue ?? [:] }

  /// The legacy type as written: `rom`, `ROM`, `통증`, `test`, `general`, ...
  public var type: String? { raw["type"]?.stringValue }
  public var label: String? { raw["label"]?.stringValue }
  public var side: String? { raw["side"]?.stringValue }
  public var unit: String? { raw["unit"]?.stringValue }
  public var note: String? { raw["note"]?.stringValue }

  /// The value as stored (a string in every legacy writer), shown as text. Empty when absent or null.
  public var valueText: String {
    switch raw["value"] {
    case nil, .null?: return ""
    case let .string(text)?: return text
    case let .number(n)?: return n == n.rounded() && abs(n) < 1e15 ? String(Int64(n)) : String(n)
    case let .int(n)?: return String(n)
    case let .bool(b)?: return b ? "true" : "false"
    case let value?: return "\(value)"
    }
  }

  /// Always false: a legacy row is shown as '해석 불가' next to its original text (F-SOAP-06.2).
  public var isInterpretable: Bool { false }

  /// The label shown next to the original text.
  public var displayLabel: String { LegacySoapView.uninterpretableLabel }
}

/// Read-only view of a v1 SOAP document.
public struct LegacySoapView: Equatable, Sendable {
  /// Display label for legacy rows and unknown v2 metric codes.
  public static let uninterpretableLabel = "해석 불가"

  /// The document as read. Private: it holds `diagnosis`, which is never exposed (MIG-04).
  private let stored: [String: JSONValue]

  /// Every `structured.metrics` row, in stored order. Never shorter than the stored list.
  public let metrics: [LegacyMetricView]

  /// `structured.workflow.status` as written (`complete`, `완료`, `작성 중`, `공유됨`, ...).
  public let legacyStatus: String?

  /// `structured.workflow.completedCategories` as written (`S` or `subjective` style).
  public let completedCategories: [String]

  /// Reads a v1 document's `data` (the fixture tags already turned into `JSONValue` cases).
  public init(json: JSONValue) {
    stored = json.objectValue ?? [:]
    let structured = stored["structured"]
    let workflow = structured?["workflow"]
    metrics = (structured?["metrics"]?.arrayValue ?? []).map(LegacyMetricView.init)
    legacyStatus = workflow?["status"]?.stringValue
    completedCategories = (workflow?["completedCategories"]?.arrayValue ?? []).compactMap(\.stringValue)
  }

  public var trainerId: String? { stored["trainerId"]?.stringValue }
  public var memberId: String? { stored["memberId"]?.stringValue }

  /// Legacy `date` (epoch milliseconds, or a timestamp).
  public var sessionDate: Date? {
    switch stored["date"] {
    case let .int(millis)?: return Date(timeIntervalSince1970: Double(millis) / 1000)
    case let .timestamp(date)?: return date
    default: return nil
    }
  }

  /// v2 status for `legacyStatus` (V1-05 §5.6). Nil for a value outside the mapping.
  public var mappedStatus: SoapStatus? {
    switch legacyStatus {
    case nil, "draft"?, "작성 중"?: return .draft
    case "complete"?, "완료"?, "shared"?, "공유됨"?: return .finalized
    default: return nil
    }
  }

  /// The note was shared under v1 (status or flag). v2 does not share it again (MIG-05).
  public var wasShared: Bool {
    stored["isSharedWithMember"] == .bool(true) || legacyStatus == "shared" || legacyStatus == "공유됨"
  }

  /// `completedCategories` with `S·O·A·P` written as `subjective·objective·assessment·plan`.
  public var normalizedCompletedCategories: [String] {
    let names = ["S": "subjective", "O": "objective", "A": "assessment", "P": "plan"]
    return completedCategories.map { names[$0] ?? $0 }
  }

  /// False for an empty memberId or a local `member-` seed (MIG-07, '회원 연결 없음').
  public var hasLinkedMember: Bool {
    guard let id = memberId else { return false }
    return !id.isEmpty && !id.hasPrefix("member-")
  }

  /// Inline ink (`drawingData` bytes or `structured.subjective.nativeInkDataBase64`). Read only; v2 keeps
  /// ink in Storage (MIG-06).
  public var hasInlineInk: Bool {
    if case .bytes? = stored["drawingData"] { return true }
    let ink = stored["structured"]?["subjective"]?["nativeInkDataBase64"]?.stringValue
    return !(ink ?? "").isEmpty
  }
}
