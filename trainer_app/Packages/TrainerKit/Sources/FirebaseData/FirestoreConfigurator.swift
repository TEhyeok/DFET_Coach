import FirebaseFirestore
import Foundation

/// Firestore settings in code, never SDK defaults (NFR-04, ASM-P1a-31). `FirebaseBootstrap.configure` applies them
/// before the first Firestore use.
public enum FirestoreConfigurator {
  /// Persistent cache size: 100 MB.
  public static let cacheSizeBytes: Int64 = 104_857_600

  /// Settings for production or, with `emulatorHost`, the Firestore emulator (port 18080, no TLS).
  public static func settings(emulatorHost: String?) -> FirestoreSettings {
    let settings = FirestoreSettings()
    settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: cacheSizeBytes))
    if let emulatorHost {
      settings.host = "\(emulatorHost):\(FirebaseBootstrap.EmulatorPort.firestore)"
      settings.isSSLEnabled = false
    }
    return settings
  }
}
