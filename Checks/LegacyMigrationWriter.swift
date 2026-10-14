import Foundation
import SwiftData
@main struct LegacyMigrationWriter {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let store = try ModelContainer(for: AppData.schema, configurations: [ModelConfiguration(schema: AppData.schema, url: url, cloudKitDatabase: .none)])
        let context = ModelContext(store)
        try AppData.seed(context)
        let checklist = try context.fetch(FetchDescriptor<ChecklistItem>()).first!
        checklist.title = "Legacy edited reminder"; checklist.isComplete = true
        let record = try context.fetch(FetchDescriptor<MaintenanceRecord>()).first!
        record.notes = "Legacy service notes"; record.costPence = 12345
        let entry = try context.fetch(FetchDescriptor<TripEntry>()).first!
        entry.angusMoment = "Legacy Angus moment"
        try context.save()
        print("Legacy database written")
    }
}
