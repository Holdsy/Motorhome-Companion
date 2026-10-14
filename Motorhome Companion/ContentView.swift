import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case checklists = "Checklists", vehicle = "My Motorhome", maintenance = "Maintenance", trips = "Trips"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .checklists: "checklist"
        case .vehicle: "bus"
        case .maintenance: "wrench.and.screwdriver"
        case .trips: "map"
        }
    }
    @ViewBuilder var screen: some View {
        switch self {
        case .checklists: ChecklistsView()
        case .vehicle: VehicleView()
        case .maintenance: MaintenanceView()
        case .trips: TripsView()
        }
    }
}

struct ContentView: View {
    @State private var selection: AppSection? = .checklists
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    private var useSidebar: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }
    var body: some View {
        Group {
            if useSidebar {
                NavigationSplitView {
                    List(AppSection.allCases, selection: $selection) { section in
                        Label(section.rawValue, systemImage: section.symbol).tag(section)
                    }
                    .navigationTitle("Motorhome Companion")
                    .navigationSplitViewColumnWidth(min: 200, ideal: 230)
                } detail: {
                    NavigationStack { (selection ?? .checklists).screen }
                        .id(selection)
                }
            } else {
                TabView {
                    ForEach(AppSection.allCases) { section in
                        NavigationStack { section.screen }
                            .tabItem { Label(section.rawValue, systemImage: section.symbol) }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 560)
        #endif
    }
}
