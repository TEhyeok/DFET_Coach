/// Where the trainer is in the shell, independent of layout (NFR-12, V1-07 §3.3). The regular layout shows it
/// as sidebar `selection` + `detail`; the compact layout shows it as a NavigationStack path. `RootSplitView`
/// converts between the two whenever the horizontal size class changes, so a Split View, Slide Over or Stage
/// Manager resize keeps the screen the user was on. Pure so the mapping is table-tested (TC-DF017-06).
struct ShellNavigation: Equatable {
  /// Sidebar selection (TR-01, TR-02 or TR-15).
  var selection: TrainerRoute?
  /// Detail column content. Only `.memberDetail` (TR-03) today.
  var detail: TrainerRoute?

  /// A sidebar tap. Choosing another sidebar route closes the detail; re-selecting the same route keeps it.
  mutating func select(_ route: TrainerRoute?) {
    if route != selection {
      detail = nil
    }
    selection = route
  }

  /// Compact: the stack path that shows the same screen as `selection` + `detail`.
  var stackPath: [TrainerRoute] {
    guard let selection else { return [] }
    if case .memberDetail = selection {
      return [.members, selection]
    }
    if selection == .members, let detail, case .memberDetail = detail {
      return [.members, detail]
    }
    return [selection]
  }

  /// Regular: the selection + detail for a compact stack path. The root list (empty path) keeps the last sidebar
  /// selection so the split view never opens without content, and closes the detail.
  func restoring(stackPath: [TrainerRoute]) -> ShellNavigation {
    guard let first = stackPath.first else {
      return ShellNavigation(selection: selection, detail: nil)
    }
    let member = stackPath.last { if case .memberDetail = $0 { return true } else { return false } }
    if case .memberDetail = first {
      return ShellNavigation(selection: .members, detail: member)
    }
    return ShellNavigation(selection: first, detail: first == .members ? member : nil)
  }
}
