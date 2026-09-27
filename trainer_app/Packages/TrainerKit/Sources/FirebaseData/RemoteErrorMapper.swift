import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import Foundation
import TrainerDomain

/// Firestore, Storage and Functions errors to `RemoteError` by code, never by message (AC-DF-104.5).
enum RemoteErrorMapper {
  static func map(_ error: Error) -> RemoteError {
    if let remote = error as? RemoteError { return remote }
    let ns = error as NSError
    switch ns.domain {
    case FirestoreErrorDomain:
      return firestore(FirestoreErrorCode.Code(rawValue: ns.code), raw: ns.code)
    case StorageErrorDomain:
      return storage(StorageErrorCode(rawValue: ns.code), raw: ns.code)
    case FunctionsErrorDomain:
      return functions(FunctionsErrorCode(rawValue: ns.code), raw: ns.code)
    case NSURLErrorDomain:
      return .unavailable
    case NSCocoaErrorDomain where ns.code == NSFileReadNoPermissionError:
      return .protectedDataUnavailable  // NSFileProtectionComplete while locked (ASM-P0-29)
    case NSCocoaErrorDomain where ns.code == NSFileReadNoSuchFileError || ns.code == NSFileNoSuchFileError:
      return .notFound  // the local file to upload is gone; retrying cannot bring it back
    default:
      return .unknown("\(ns.domain):\(ns.code)")
    }
  }

  private static func firestore(_ code: FirestoreErrorCode.Code?, raw: Int) -> RemoteError {
    switch code {
    case .permissionDenied?: return .permissionDenied
    case .failedPrecondition?: return .failedPrecondition
    case .invalidArgument?: return .invalidArgument
    case .notFound?: return .notFound
    case .alreadyExists?: return .alreadyExists
    case .unavailable?: return .unavailable
    case .deadlineExceeded?: return .deadlineExceeded
    default: return .unknown("firestore:\(raw)")
    }
  }

  private static func storage(_ code: StorageErrorCode?, raw: Int) -> RemoteError {
    switch code {
    case .unauthorized?, .unauthenticated?: return .permissionDenied
    case .objectNotFound?, .bucketNotFound?, .projectNotFound?: return .notFound
    case .retryLimitExceeded?: return .unavailable
    case .downloadSizeExceeded?, .invalidArgument?, .pathError?, .bucketMismatch?: return .invalidArgument
    case .quotaExceeded?: return .unavailable
    default: return .unknown("storage:\(raw)")
    }
  }

  private static func functions(_ code: FunctionsErrorCode?, raw: Int) -> RemoteError {
    switch code {
    case .permissionDenied?, .unauthenticated?: return .permissionDenied
    case .failedPrecondition?: return .failedPrecondition
    case .invalidArgument?: return .invalidArgument
    case .notFound?: return .notFound
    case .alreadyExists?: return .alreadyExists
    case .unavailable?: return .unavailable
    case .deadlineExceeded?: return .deadlineExceeded
    default: return .unknown("functions:\(raw)")
    }
  }
}
