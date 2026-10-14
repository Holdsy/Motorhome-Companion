import Foundation
import SwiftData
@main struct MigrationChecks {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        try StoreBackup.beforeCloudMigration(at: url)
        let backup = url.deletingLastPathComponent().appendingPathComponent("Backups/Before-iCloud-v1.sqlite")
        precondition(FileManager.default.fileExists(atPath: backup.path))
        let originalBackup = try Data(contentsOf: backup)
        let store = try ModelContainer(for: AppData.schema, configurations: [ModelConfiguration(schema: AppData.schema, url: url, cloudKitDatabase: .none)])
        let context = ModelContext(store)
        let items = try context.fetch(FetchDescriptor<ChecklistItem>())
        precondition(items.count == 14)
        precondition(items.contains { $0.title == "Legacy edited reminder" && $0.isComplete })
        let record = try context.fetch(FetchDescriptor<MaintenanceRecord>()).first!
        precondition(record.notes == "Legacy service notes" && record.costPence == 12345)
        let trip = try context.fetch(FetchDescriptor<Trip>()).first!
        precondition(trip.dailyEntries.count == 1)
        precondition(trip.dailyEntries.first!.angusMoment == "Legacy Angus moment")
        precondition(trip.dailyEntries.first!.trip == trip)
        try AppData.seed(context)
        let count = try context.fetchCount(FetchDescriptor<ChecklistItem>())
        precondition(count == 14)
        try StoreBackup.beforeCloudMigration(at: url)
        let secondBackup = try Data(contentsOf: backup)
        precondition(secondBackup == originalBackup)
        print("PASS: original schema migrated without data loss; relationships and edits preserved; backup exists and is not overwritten")
    }
}
