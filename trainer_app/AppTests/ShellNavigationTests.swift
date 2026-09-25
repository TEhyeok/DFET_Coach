import XCTest

/// TC-DF017-06 (NFR-12, V1-07 §3.3): a size-class change maps the regular split state to the compact stack path
/// and back without losing the TR screen.
final class ShellNavigationTests: XCTestCase {
  private let member = TrainerRoute.memberDetail(uid: "syn-0001")

  func testSplitToStackTable() {
    let cases: [(ShellNavigation, [TrainerRoute], String)] = [
      (ShellNavigation(selection: nil), [], "no selection -> root list"),
      (ShellNavigation(selection: .today), [.today], "TR-01"),
      (ShellNavigation(selection: .members), [.members], "TR-02"),
      (ShellNavigation(selection: .settings), [.settings], "TR-15"),
      (ShellNavigation(selection: .members, detail: member), [.members, member], "TR-03 under TR-02"),
      (ShellNavigation(selection: .settings, detail: member), [.settings], "stray detail outside TR-02 dropped"),
      (ShellNavigation(selection: member), [.members, member], "TR-03 as selection keeps TR-02 underneath"),
    ]
    for (navigation, path, name) in cases {
      XCTAssertEqual(navigation.stackPath, path, name)
    }
  }

  func testStackToSplitTable() {
    let previous = ShellNavigation(selection: .settings, detail: member)
    let cases: [([TrainerRoute], ShellNavigation, String)] = [
      ([], ShellNavigation(selection: .settings), "root list keeps the sidebar selection, closes the detail"),
      ([.today], ShellNavigation(selection: .today), "TR-01"),
      ([.settings], ShellNavigation(selection: .settings), "TR-15"),
      ([.members], ShellNavigation(selection: .members), "TR-02"),
      ([.members, member], ShellNavigation(selection: .members, detail: member), "TR-03"),
      ([member], ShellNavigation(selection: .members, detail: member), "TR-03 without TR-02"),
    ]
    for (path, expected, name) in cases {
      XCTAssertEqual(previous.restoring(stackPath: path), expected, name)
    }
  }

  func testRoundTripKeepsEveryScreen() {
    let states = [
      ShellNavigation(selection: .today), ShellNavigation(selection: .members),
      ShellNavigation(selection: .settings), ShellNavigation(selection: .members, detail: member),
    ]
    for state in states {
      XCTAssertEqual(state.restoring(stackPath: state.stackPath), state, "\(state)")
    }
  }

  func testSelectClosesDetailOnlyWhenTheRouteChanges() {
    var navigation = ShellNavigation(selection: .members, detail: member)
    navigation.select(.members)
    XCTAssertEqual(navigation.detail, member)
    navigation.select(.settings)
    XCTAssertEqual(navigation, ShellNavigation(selection: .settings))
  }
}
