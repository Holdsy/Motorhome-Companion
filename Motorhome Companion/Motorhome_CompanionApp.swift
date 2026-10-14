import SwiftUI
import SwiftData

@main
struct Motorhome_CompanionApp: App {
    private let container: ModelContainer?
    private let startupError: String?
    @StateObject private var sync: SyncMonitor
    init() {
        // Unsigned local test builds may opt out explicitly; shipped builds always use iCloud.
        #if DEBUG
        let cloudEnabled = !ProcessInfo.processInfo.arguments.contains("-local-testing")
        #else
        let cloudEnabled = true
        #endif
        _sync = StateObject(wrappedValue: SyncMonitor(enabled: cloudEnabled))
        do {
            // Keep the original default store URL so existing iPhone records migrate in place.
            let config = ModelConfiguration(schema: AppData.schema, cloudKitDatabase: cloudEnabled ? .private(SyncMonitor.containerIdentifier) : .none)
            try StoreBackup.beforeCloudMigration(at: config.url)
            let store = try ModelContainer(for: AppData.schema, configurations: [config])
            store.mainContext.autosaveEnabled = false
            // Never automatically seed an empty cloud store: it may still be downloading.
            container = store; startupError = nil
        } catch {
            container = nil; startupError = error.localizedDescription
        }
    }
    var body: some Scene {
        WindowGroup {
            if let container {
                StartupView().modelContainer(container)
                    .environmentObject(sync)
                    .tint(Color("AccentColor"))
                    .environment(\.locale, Locale(identifier: "en_GB"))
            } else {
                ContentUnavailableView("Couldn’t open your data", systemImage: "externaldrive.badge.exclamationmark", description: Text("Please close and reopen the app. Your stored data has not been reset. If this is a new build, check its iCloud signing setup in Xcode.\n\n\(startupError ?? "Unknown error")"))
            }
        }
        .defaultSize(width: 1000, height: 760)
    }
}
