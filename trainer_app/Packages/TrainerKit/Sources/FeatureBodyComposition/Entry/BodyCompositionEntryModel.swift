import Foundation
import Observation
import TrainerContracts
import TrainerDomain

/// TR-11 form and live history. The store owns persistence and rechecks consent when saving.
@MainActor
@Observable
public final class BodyCompositionEntryModel {
  public var draft: BodyCompositionDraft
  public private(set) var consent = EffectiveConsent.none
  public private(set) var records: [BodyCompositionRecord] = []
  public private(set) var isLoadingRecords = true
  public private(set) var recordsFailed = false
  public private(set) var isSaving = false
  public private(set) var savedRecordID: String?
  public private(set) var saveErrorKey: String?
  private var recentDevices: [String] = []
  private var confirmedSaveState: SyncState?
  public let member: MemberKey

  @ObservationIgnored private let measurements: any MeasurementStore
  @ObservationIgnored private let consentSource: any EffectiveConsentSource
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let suppliedDeviceNames: [String]
  @ObservationIgnored private var deviceEdited = false
  @ObservationIgnored private var heightEdited = false
  @ObservationIgnored private var appliedRecordDefaults = false

  public init(
    member: MemberKey, measurements: any MeasurementStore, consentSource: any EffectiveConsentSource,
    initialHeightCm: Double? = nil, initialHeightMeasuredAt: Date? = nil,
    deviceNames: [String] = [], defaultDeviceModel: String? = nil, now: @escaping () -> Date = Date.init
  ) {
    self.member = member
    self.measurements = measurements
    self.consentSource = consentSource
    self.now = now
    suppliedDeviceNames = deviceNames
    draft = BodyCompositionDraft(deviceModel: defaultDeviceModel, measuredAt: now(),
                                 heightCmInput: initialHeightCm.map(NumberParser.displayText),
                                 heightMeasuredAt: initialHeightMeasuredAt)
  }

  /// Height collection needs server-confirmed ② (ASM-P1a-41); awaiting consent permits values-only local drafts.
  public var allowsHeightEntry: Bool { consent.healthData == .granted }

  private var saveDraft: BodyCompositionDraft {
    var value = draft
    if !allowsHeightEntry {
      value.heightCmInput = nil
      value.heightMeasuredAt = nil
    }
    return value
  }

  public var validation: BodyCompositionValidation { BodyCompositionValidator.validate(saveDraft, now: now()) }
  public var canSave: Bool {
    validation.canSave && consent.canSaveHealthRecord && !isSaving && savedRecordID == nil
  }
  public var savedState: SyncState {
    confirmedSaveState ?? (consent.healthData == .awaitingConsent ? .awaitingConsent : .localSaved)
  }
  public var currentDate: Date { now() }

  public var deviceNames: [String] {
    var seen: Set<String> = []
    return (records.filter(\.isActive).map(\.deviceModel) + recentDevices + suppliedDeviceNames)
      .map(DeviceModelName.normalize).filter { !$0.isEmpty && seen.insert($0).inserted }
  }

  public func setDevice(_ value: String) {
    deviceEdited = true
    draft.deviceModel = value
  }

  public func setHeight(_ value: String) {
    heightEdited = true
    draft.heightCmInput = value
    // A freshly entered height belongs to this measurement, not the previous record's height date.
    draft.heightMeasuredAt = nil
  }

  public func observeConsent() async {
    for await value in consentSource.observe(member: member) {
      guard !Task.isCancelled else { return }
      consent = value
    }
  }

  public func observeSavedState() async {
    guard let id = savedRecordID else { return }
    for await state in await measurements.observeBodyCompositionSyncState(recordID: id) {
      guard !Task.isCancelled, savedRecordID == id else { return }
      confirmedSaveState = state
    }
  }

  public func observeRecords() async {
    isLoadingRecords = true
    recordsFailed = false
    recentDevices = (try? await measurements.recentDeviceModels()) ?? []
    if !deviceEdited, draft.deviceModel == nil { draft.deviceModel = recentDevices.first }
    do {
      // Defaults come from the latest active record even when it is older than the mini trend's 12-month window.
      for try await value in measurements.observeBodyCompositionRecords(member: member, since: .distantPast) {
        guard !Task.isCancelled else { return }
        records = value.sorted { ($0.measuredAt, $0.id) > ($1.measuredAt, $1.id) }
        isLoadingRecords = false
        applyRecordDefaults()
      }
    } catch {
      guard !Task.isCancelled else { return }
      isLoadingRecords = false
      recordsFailed = true
    }
  }

  private func applyRecordDefaults() {
    guard !appliedRecordDefaults, let latest = BodyCompositionSeries.latestActive(records) else { return }
    appliedRecordDefaults = true
    if !deviceEdited { draft.deviceModel = latest.deviceModel }
    if !heightEdited, draft.heightCmInput == nil, let height = latest.derived {
      draft.heightCmInput = NumberParser.displayText(height.heightCmUsed)
      draft.heightMeasuredAt = height.heightMeasuredAt
    }
  }

  /// Local save only. No view infers a server acknowledgement from this return value.
  public func save() async -> String? {
    guard canSave else { return nil }
    isSaving = true
    saveErrorKey = nil
    let input = saveDraft
    defer { isSaving = false }
    do {
      let id = try await measurements.saveBodyComposition(member: member, draft: input)
      savedRecordID = id
      return id
    } catch MeasurementStoreError.consentRequired {
      saveErrorKey = "tr11.consentNeeded"
      return nil
    } catch {
      saveErrorKey = "tr11.saveFailed"
      return nil
    }
  }

  public func beginNewEntry() {
    guard !isSaving else { return }
    let heightDate = draft.heightMeasuredAt ?? draft.measuredAt
    draft = BodyCompositionDraft(deviceModel: draft.deviceModel, measuredAt: now(),
                                 heightCmInput: draft.heightCmInput, heightMeasuredAt: heightDate)
    savedRecordID = nil
    confirmedSaveState = nil
    saveErrorKey = nil
  }
}
