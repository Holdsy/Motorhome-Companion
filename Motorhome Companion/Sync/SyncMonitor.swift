import SwiftUI
import Combine
import CloudKit
import CoreData

@MainActor final class SyncMonitor: ObservableObject {
    static let containerIdentifier = "iCloud.com.MarkHoldsworth.Motorhome-Companion"
    @Published private(set) var accountMessage = "Checking iCloud account…"
    @Published private(set) var activity = "Waiting for iCloud activity"
    @Published private(set) var lastUpload: Date?
    @Published private(set) var lastDownload: Date?
    @Published private(set) var syncError: String?
    let enabled: Bool
    private var subscription: AnyCancellable?
    private var activeEvents: Set<UUID> = []

    init(enabled: Bool) {
        self.enabled = enabled
        guard enabled else {
            accountMessage = "Local test mode"
            activity = "iCloud is disabled for this test launch."
            return
        }
        subscription = NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
                self?.record(event)
            }
    }

    func checkAccount() async {
        guard enabled else { return }
        do {
            switch try await CKContainer(identifier: Self.containerIdentifier).accountStatus() {
            case .available: accountMessage = "Signed in to iCloud"
            case .noAccount: accountMessage = "Sign in to iCloud in device Settings to sync."
            case .restricted: accountMessage = "iCloud access is restricted on this device."
            case .temporarilyUnavailable: accountMessage = "iCloud is temporarily unavailable. Local changes remain saved."
            case .couldNotDetermine: accountMessage = "Couldn’t check iCloud. Check your connection and try again."
            @unknown default: accountMessage = "iCloud account status is unavailable."
            }
        } catch {
            accountMessage = "Couldn’t check iCloud: \(error.localizedDescription)"
        }
    }

    private func record(_ event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            activeEvents.insert(event.identifier)
            activity = "iCloud is working…"
            return
        }
        activeEvents.remove(event.identifier)
        if let error = event.error {
            syncError = error.localizedDescription
        } else if event.succeeded {
            if event.type == .export { lastUpload = event.endDate }
            if event.type == .import { lastDownload = event.endDate }
            // A setup event alone does not prove that uploads/downloads have recovered.
            if event.type != .setup { syncError = nil }
        }
        activity = activeEvents.isEmpty ? "Waiting for the next iCloud update" : "iCloud is working…"
    }
}

struct SyncStatusView: View {
    @EnvironmentObject private var sync: SyncMonitor
    var body: some View {
        Form {
            Section("iCloud") {
                Label(sync.accountMessage, systemImage: "icloud")
                Text(sync.activity)
                if let error = sync.syncError {
                    Label(error, systemImage: "exclamationmark.icloud").foregroundStyle(.orange)
                    Text("Your local records remain available. Check your connection, iCloud storage and account settings.")
                }
                LabeledContent("Last successful upload", value: timestamp(sync.lastUpload))
                LabeledContent("Last successful download", value: timestamp(sync.lastDownload))
                Button("Check iCloud account") { Task { await sync.checkAccount() } }.disabled(!sync.enabled)
            }
            Section("Your devices") {
                Text("Use the same Apple Account on your iPhone, iPad and Mac. Your motorhome records sync through that account’s private iCloud database.")
                Text("Changes save on this device first. iCloud transfers them when a connection is available; updates may take time. The times above describe this app session, not a guarantee that every device is up to date.")
                Text("Avoid editing the same record on two devices at once. iCloud resolves overlapping changes automatically; there is no version history or manual conflict editor.")
                Text("Separate Apple Accounts do not share this database. Invitation-based sharing with another person is not included.")
            }
            Section("Adding another device") {
                Text("Open the updated app on the device with your existing records first and wait for a successful upload. On each additional device, leave the connection screen open while iCloud downloads your data. Do not create another starter motorhome.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("iCloud Sync")
        .task { await sync.checkAccount() }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
    }
    private func timestamp(_ date: Date?) -> String {
        date?.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "en_GB"))) ?? "Not observed this session"
    }
}
