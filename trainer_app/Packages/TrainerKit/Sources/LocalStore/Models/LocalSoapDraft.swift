import Foundation
import SwiftData
import TrainerContracts
import TrainerDomain

extension LocalStoreSchemaV1 {
  /// SOAP Live/Review editing source (V1-05 §12.2). Projected to `soap_notes/{noteId}` by the SyncEngine (DF-015).
  /// Replaces, without porting, the Runner UserDefaults draft `NativeSoapDailyDraft` (dfet:ios/Runner/AppDelegate.swift:3368-3528).
  @Model
  final class LocalSoapDraft {
    @Attribute(.unique) var noteId: String
    var trainerUid: String
    /// `MemberKey.storageValue`.
    var memberKey: String
    var sessionDate: Date
    /// `LocalSoapLockState` raw value.
    var lockState: String
    var quickNote: String?
    var inkBinaryId: UUID?
    var inkRevision: Int = 0
    /// nil = not entered, 0 = a 0 score.
    var painNrs: Int?
    /// vocab `regionCode` raw values.
    var painRegions: [String]
    var chiefComplaint: String?
    var objectiveJSON: Data?
    var exerciseAssessmentJSON: Data?
    var planNextSession: String?
    var planHomeExercise: String?
    var memberNote: String?
    var serverCreated: Bool
    /// When the trainer tapped 'record complete' (end of M-01).
    var liveCompletedAt: Date?
    /// `SyncState` raw value; a cache computed by the SyncEngine (V1-05 §12.3).
    var syncState: String
    var lastErrorCode: String?
    var createdLocallyAt: Date
    var updatedLocallyAt: Date

    init(
      noteId: String,
      trainerUid: String,
      memberKey: MemberKey,
      sessionDate: Date,
      lockState: LocalSoapLockState = .editable,
      quickNote: String? = nil,
      inkBinaryId: UUID? = nil,
      inkRevision: Int = 0,
      painNrs: Int? = nil,
      painRegions: [RegionCode] = [],
      chiefComplaint: String? = nil,
      objectiveJSON: Data? = nil,
      exerciseAssessmentJSON: Data? = nil,
      planNextSession: String? = nil,
      planHomeExercise: String? = nil,
      memberNote: String? = nil,
      serverCreated: Bool = false,
      liveCompletedAt: Date? = nil,
      syncState: SyncState = .localSaved,
      lastErrorCode: String? = nil,
      createdLocallyAt: Date,
      updatedLocallyAt: Date? = nil
    ) {
      self.noteId = noteId
      self.trainerUid = trainerUid
      self.memberKey = memberKey.storageValue
      self.sessionDate = sessionDate
      self.lockState = lockState.rawValue
      self.quickNote = quickNote
      self.inkBinaryId = inkBinaryId
      self.inkRevision = inkRevision
      self.painNrs = painNrs
      self.painRegions = painRegions.map(\.rawValue)
      self.chiefComplaint = chiefComplaint
      self.objectiveJSON = objectiveJSON
      self.exerciseAssessmentJSON = exerciseAssessmentJSON
      self.planNextSession = planNextSession
      self.planHomeExercise = planHomeExercise
      self.memberNote = memberNote
      self.serverCreated = serverCreated
      self.liveCompletedAt = liveCompletedAt
      self.syncState = syncState.rawValue
      self.lastErrorCode = lastErrorCode
      self.createdLocallyAt = createdLocallyAt
      self.updatedLocallyAt = updatedLocallyAt ?? createdLocallyAt
    }

    var entityRef: String { LocalEntityRef.soap(noteId: noteId) }
  }
}

extension LocalSoapDraft: TrainerScopedModel {
  static func ownedBy(_ trainerUid: String) -> Predicate<LocalSoapDraft> {
    #Predicate<LocalSoapDraft> { $0.trainerUid == trainerUid }
  }
}
