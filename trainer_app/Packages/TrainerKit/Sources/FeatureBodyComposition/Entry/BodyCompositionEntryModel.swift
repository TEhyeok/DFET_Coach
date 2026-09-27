import DesignSystem
import Foundation
import Observation
import TrainerContracts
import TrainerDomain

/// TR-11 신체조성 입력 state (DF-127). Validation is `BodyCompositionValidator` on every read, so what the form shows
/// and what the store would save are the same decision. The consent gate is the member's `EffectiveConsent`
/// (AC-DF-127.4, DF-111 MVP); the default device and height come from the member's latest active record, else the
/// device most recently used on this iPad (V1-09 §10.3). `users.height`/`users.weight` are never read (AC-DF-127.3).
@MainActor
@Observable
public final class BodyCompositionEntryModel {
  public var draft: BodyCompositionDraft
  /// The device picker's list, most recently used first, the draft's device included.
  public private(set) var deviceModels: [String] = []
  /// Whether `tr11.more` (visceral fat level, total body water) is open.
  public var showsMoreValues = false
  public private(set) var isSaving = false
  /// The record could not be saved on the device (the form stays filled in).
  public private(set) var saveFailed = false
  /// The saved record; the form then shows it read-only and cannot save again.
  public private(set) var savedRecordId: String?

  private let memberModel: BodyCompositionMemberModel
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let localize: Localizer
  @ObservationIgnored private var prepared = false

  init(memberModel: BodyCompositionMemberModel, now: @escaping () -> Date, localize: Localizer) {
    self.memberModel = memberModel
    self.now = now
    self.localize = localize
    draft = BodyCompositionDraft(measuredAt: now())
  }

  public var member: MemberKey { memberModel.member }

  // MARK: - Defaults

  /// Loads the device list and fills the defaults the trainer has not set: the latest active record's device, else
  /// the most recently used one, and that record's trainer-entered height with its date (ASM-P1a-41).
  public func prepare() async {
    let names = (try? await memberModel.services.devices.recentDeviceModels()) ?? []
    let latest = memberModel.latest
    deviceModels = Self.merged(names, with: [draft.deviceModel, latest?.deviceModel])
    guard !prepared else { return }
    prepared = true
    if (draft.deviceModel ?? "").isEmpty {
      draft.deviceModel = latest.map { DeviceModelName.normalize($0.deviceModel) }.flatMap { $0.isEmpty ? nil : $0 }
        ?? names.first
      deviceModels = Self.merged(deviceModels, with: [draft.deviceModel])
    }
    if draft.heightCmInput == nil, let derived = latest?.derived {
      draft.heightCmInput = NumberParser.displayText(derived.heightCmUsed)
      draft.heightMeasuredAt = derived.heightMeasuredAt
    }
  }

  private static func merged(_ names: [String], with extra: [String?]) -> [String] {
    var result = names
    for name in extra.compactMap({ $0.map(DeviceModelName.normalize) }) where !name.isEmpty && !result.contains(name) {
      result.append(name)
    }
    return result
  }

  /// '기기 추가': stores the name on this iPad and selects it. False when the name cannot be stored.
  @discardableResult
  public func addDevice(_ text: String) async -> Bool {
    guard let name = DeviceModelName.storable(text) else { return false }
    do {
      let stored = try await memberModel.services.devices.addDeviceModel(name)
      deviceModels = [stored] + deviceModels.filter { $0 != stored }
      draft.deviceModel = stored
      return true
    } catch {
      return false
    }
  }

  /// A height typed by the trainer is measured with this record (`heightMeasuredAt` nil = `measuredAt`).
  public func setHeight(_ text: String) {
    draft.heightCmInput = text
    draft.heightMeasuredAt = nil
  }

  // MARK: - Validation and gate

  public var validation: BodyCompositionValidation {
    BodyCompositionValidator.validate(draft, now: now())
  }

  /// nil until the member's consent is known.
  public var saveGate: HealthRecordSaveGate? { memberModel.consent?.healthRecordSave }

  /// AC-DF-127.1, .4: every required meta, a value, no error, and consent ② (granted, or waiting for the server).
  public var canSave: Bool {
    guard let gate = saveGate, gate != .blocked else { return false }
    return validation.canSave && !isSaving && savedRecordId == nil
  }

  /// '건강정보 동의 필요' next to the disabled save button (AC-DF-127.4).
  public var showsConsentNeeded: Bool { saveGate == .blocked }
  /// ② only in a local capture: the record stays on this iPad until the server confirms consent (DF-111).
  public var savesLocallyOnly: Bool { saveGate == .localOnly }
  /// The height row, only with consent ② (ASM-P1a-41).
  public var showsHeight: Bool { memberModel.consent?.canSaveHealthRecord == true }

  /// '기기가 바뀌어 이전 기록과 비교할 수 없습니다' (AC-DF-128.7): the chosen device differs from the latest active record
  /// measured before this one. It never blocks saving.
  public var showsDeviceChanged: Bool {
    BodyCompositionSeries.deviceChanged(memberModel.loadedRecords, deviceModel: draft.deviceModel,
                                        measuredAt: draft.measuredAt)
  }

  // MARK: - Words

  /// The message under a value or the height field: not a number, or out of range with `tr11.range.generic`.
  public func errorMessage(for field: BodyCompositionField) -> String? {
    validation.errors.first { $0.field == field }.map(message)
  }

  /// The messages under the date picker (a time after now + 5 minutes).
  public var measuredAtMessage: String? {
    validation.errors.contains(.measuredAtInFuture) ? localize(BodyCompositionIssue.measuredAtInFuture.copyKey) : nil
  }

  /// Why saving is off, for the form's own fields: device, fasting, no value (AC-DF-127.1).
  public var missingMessages: [String] {
    validation.errors.filter { $0.field == nil && $0 != .measuredAtInFuture }.map(message)
  }

  /// Cross-consistency warnings; saving stays on (AC-DF-127.8).
  public var warningMessages: [String] { validation.warnings.map(message) }

  public var hasWarnings: Bool { !validation.warnings.isEmpty }

  /// BMI as the read-only field shows it: the derived value with its unit, or '미측정' (AC-DF-127.5).
  public var bmiText: String {
    guard let bmi = validation.bmi else { return localize(BodyCompositionCopy.unmeasured) }
    return MetricRow.valueText(bmi, code: .bmi) + " " + localize("unit." + MetricUnit.kgPerM2.rawValue)
  }

  public var hasBMI: Bool { validation.bmi != nil }

  /// The read-only time of day, from `measuredAt` on the Seoul clock (AC-DF-127.9).
  public var timeOfDayText: String { localize(validation.timeOfDayBand.copyKey) }

  public func message(_ issue: BodyCompositionIssue) -> String {
    guard let range = issue.range else { return localize(issue.copyKey) }
    return localize.format(issue.copyKey, range.minText, range.maxText, localize(range.unitCopyKey))
  }

  // MARK: - Save

  /// The saved record's id, or nil when nothing was saved.
  public func save() async -> String? {
    guard canSave else { return nil }
    isSaving = true
    saveFailed = false
    defer { isSaving = false }
    do {
      let id = try await memberModel.services.store.saveBodyComposition(member: member, draft: draft)
      savedRecordId = id
      return id
    } catch {
      saveFailed = true
      return nil
    }
  }
}
