import Foundation

/// Looks up a V1-12 copy key. Components default to the app's string catalog (`bundle: .main`, V1-12 §4.4); tests
/// pass a lookup built from the catalog file, because a package test bundle has no catalog.
public struct Localizer: Sendable {
  private let lookup: @Sendable (String) -> String

  public init(_ lookup: @escaping @Sendable (String) -> String) {
    self.lookup = lookup
  }

  public static let main = Localizer { String(localized: String.LocalizationValue($0), bundle: .main) }

  public func callAsFunction(_ key: String) -> String {
    lookup(key)
  }

  /// A format key filled with `arguments` in order (`%@`, or `%1$@`… for two or more, V1-12 §4.3).
  public func format(_ key: String, _ arguments: String...) -> String {
    String(format: lookup(key), arguments: arguments)
  }
}
