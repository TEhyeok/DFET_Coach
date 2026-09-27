import FirebaseStorage
import Foundation
import os

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
  private static let emulator = OSAllocatedUnfairLock(initialState: false)
  /// Upper bound for the SDK's own upload retries (its default is 600 s); an upload cannot be cancelled from outside.
  static let maxUploadRetrySeconds: TimeInterval = 120

  /// Called once by `FirebaseBootstrap.configure(.emulator)`, before any Storage use.
  static func useEmulator(host: String, port: Int) {
    Storage.storage().useEmulator(withHost: host, port: port)  // the emulator uses the default bucket
    emulator.withLock { $0 = true }
  }

  public static func make() -> Storage {
    make(emulator: emulator.withLock { $0 })
  }

  static func make(emulator: Bool) -> Storage {
    let storage = bucketURL(emulator: emulator).map { Storage.storage(url: $0) } ?? Storage.storage()
    storage.maxUploadRetryTime = maxUploadRetrySeconds
    return storage
  }

  /// nil means the default bucket.
  static func bucketURL(emulator: Bool) -> String? {
    emulator ? nil : StorageBucket.seoulURL
  }
}
