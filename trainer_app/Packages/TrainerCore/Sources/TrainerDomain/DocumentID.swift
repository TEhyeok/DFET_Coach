import Foundation

/// Firestore-style automatic document IDs made on the device (V1-04 §9.1): 20 characters of `[A-Za-z0-9]`, the shape
/// the rules require for `pendingMembers/{id}` (R-05). Made locally so an offline record already has its final path.
public enum DocumentID {
  static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
  public static let length = 20

  public static func make() -> String {
    var generator = SystemRandomNumberGenerator()
    return make(using: &generator)
  }

  public static func make<G: RandomNumberGenerator>(using generator: inout G) -> String {
    String((0..<length).map { _ in alphabet[Int(generator.next(upperBound: UInt64(alphabet.count)))] })
  }

  public static func isValid(_ id: String) -> Bool {
    id.count == length && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
  }
}
