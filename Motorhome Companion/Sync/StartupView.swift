import SwiftUI
import SwiftData

struct StartupView: View {
    @Query private var seeds: [SeedState]
    @Query private var items: [ChecklistItem]
    @Query private var details: [VehicleDetail]
    @Query private var odometers: [Odometer]
    @Query private var maintenance: [MaintenanceRecord]
    @Query private var trips: [Trip]
    @Query private var entries: [TripEntry]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var sync: SyncMonitor
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingStart = false
    @State private var error: String?
    private var hasData: Bool {
        !seeds.isEmpty || !items.isEmpty || !details.isEmpty || !odometers.isEmpty || !maintenance.isEmpty || !trips.isEmpty || !entries.isEmpty
    }
    var body: some View {
        Group {
            if hasData {
                ContentView()
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Image(systemName: "icloud.and.arrow.down").font(.system(size: 48)).foregroundStyle(Color.accentColor)
                            Text("Connect your motorhome").font(.largeTitle.bold())
                            Text("Already using Motorhome Companion? Keep this screen open while iCloud downloads your records. Use the same Apple Account as your other device.")
                            Text(sync.accountMessage).font(.headline)
                            if let syncError = sync.syncError { Text(syncError).foregroundStyle(.orange) }
                            NavigationLink("View iCloud status") { SyncStatusView() }
                            Divider()
                            Text("Starting for the first time?").font(.title2.bold())
                            Text("Create the starter checklists and vehicle details on just one device. On your other devices, wait for those records to arrive from iCloud.")
                            Button("Create my first motorhome") { confirmingStart = true }.buttonStyle(.borderedProminent)
                        }.padding(28).frame(maxWidth: 600, alignment: .leading)
                    }.navigationTitle("Welcome")
                }
                #if os(macOS)
                .frame(minWidth: 760, minHeight: 560)
                #endif
            }
        }
        .task { await sync.checkAccount() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await sync.checkAccount() } }
        }
        .confirmationDialog("Create starter data on this device?", isPresented: $confirmingStart, titleVisibility: .visible) {
            Button("Create starter motorhome") {
                // Recheck after the confirmation: cloud records may have arrived meanwhile.
                guard !hasData else { return }
                do { try AppData.seed(context) } catch { self.error = error.localizedDescription }
            }
        } message: {
            Text("Only do this if you have not already set up the app on another device. Creating starter data independently on multiple devices can create duplicates when they sync.")
        }
        .saveError($error)
    }
}
