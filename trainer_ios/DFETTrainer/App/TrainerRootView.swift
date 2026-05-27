import SwiftUI

struct TrainerRootView: View {
  @EnvironmentObject private var store: TrainerStore
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      sidebar
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
        .trainerLabel("TR-NAV-00")
    } detail: {
      detail
        .background(StudioBackdrop().ignoresSafeArea())
        .navigationTitle(store.selectedRoute.title)
        .trainerLabel("TR-DETAIL-00")
    }
    .navigationSplitViewStyle(.balanced)
    .preferredColorScheme(.light)
  }

  private var sidebar: some View {
    List {
      Section {
        ForEach(TrainerRoute.allCases.filter { $0 != .settings }) { route in
          routeButton(route)
        }
      }
      .trainerLabel("TR-NAV-ROUTES")

      Section("오늘") {
        ForEach(Array(store.members.enumerated()), id: \.element.id) { index, member in
          Button {
            store.selectMember(member)
            store.selectedRoute = .members
          } label: {
            HStack(spacing: 10) {
              TrainerAvatar(member: member, size: 34)
              VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                  .font(TrainerFont.label(14, weight: .semibold))
                  .foregroundStyle(TrainerColor.primaryText)
                Text(member.signal)
                  .font(TrainerFont.body(12))
                  .foregroundStyle(TrainerColor.secondaryText)
              }
              Spacer()
              Text("\(member.pain)/10")
                .font(TrainerFont.label(11, weight: .bold))
                .foregroundStyle(member.risk.color)
            }
            .padding(.vertical, 5)
          }
          .buttonStyle(.plain)
          .trainerLabel("TR-NAV-TODAY-\(index + 1)")
        }
      }

      Section("도구") {
        routeButton(.settings)
          .trainerLabel("TR-NAV-TOOLS")
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("D-FET")
    .scrollContentBackground(.hidden)
    .background(StudioBackdrop().ignoresSafeArea())
  }

  private func routeButton(_ route: TrainerRoute) -> some View {
    Button {
      store.selectedRoute = route
    } label: {
      Label(route.title, systemImage: route.symbol)
        .font(TrainerFont.label(15, weight: store.selectedRoute == route ? .semibold : .regular))
        .foregroundStyle(store.selectedRoute == route ? TrainerColor.blue : TrainerColor.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
          store.selectedRoute == route ? TrainerColor.blue.opacity(0.13) : Color.clear,
          in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
    .buttonStyle(.plain)
    .trainerLabel("TR-NAV-\(route.rawValue)")
  }

  @ViewBuilder
  private var detail: some View {
    switch store.selectedRoute {
    case .summary:
      SummaryView()
    case .members:
      MembersView()
    case .soap:
      SOAPWorkspaceView()
    case .reports:
      ReportsView()
    case .productivityExample:
      ProductivityTrainerExampleView()
    case .settings:
      SettingsView()
    }
  }
}
