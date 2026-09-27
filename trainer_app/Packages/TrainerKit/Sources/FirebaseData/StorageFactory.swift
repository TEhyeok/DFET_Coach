import FirebaseStorage
import Foundation

/// The Storage bucket of the trainer app (DEC-19): the Seoul bucket in production. The same value lives in
/// functions/src/shared/storage.js, lib/config/storage_bucket.dart and admin_web/lib/firebase-admin.ts (DF-043).
/// The bucket name is not a secret.
public enum StorageBucket {
  public static let seoul = "dfetmanage-seoul"
  public static var seoulURL: String { "gs://\(seoul)" }
}

/// The one place that picks a Storage instance (AC-DF-104.9, static-guards G10): the default bucket when the emulator
/// is configured (the emulator has one bucket), otherwise the Seoul bucket.
public enum StorageFactory {
  /// Set by `FirebaseBootstrap.configure(.emulator)`.
  nonisolated(unsafe) static var useEmulator = false

  public static func make() -> Storage {
    make(emulator: useEmulator)
  }

  static func make(emulator: Bool) -> Storage {
    guard let url = bucketURL(emulator: emulator) else { return Storage.storage() }
    return Storage.storage(url: url)
  }

  /// nil means the default bucket.
  static func bucketURL(emulator: Bool) -> String? {
    emulator ? nil : StorageBucket.seoulURL
  }
}
