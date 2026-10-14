import Foundation
import SwiftData

@main struct CloudSchemaChecks {
    @MainActor static func main() throws {
        for entity in AppData.schema.entities {
            for attribute in entity.attributes {
                precondition(attribute.isOptional || attribute.defaultValue != nil, "\(entity.name).\(attribute.name) must be optional or have a schema default")
                precondition(!attribute.options.contains(.unique), "CloudKit does not support unique constraints")
            }
            for relationship in entity.relationships {
                precondition(relationship.isOptional, "\(entity.name).\(relationship.name) must be optional")
                precondition(relationship.deleteRule != .deny, "CloudKit does not support deny deletion rules")
            }
        }
        // Explicit inverse is declared on Trip.entries; verify it resolves at runtime.
        let store = try ModelContainer(for: AppData.schema, configurations: [ModelConfiguration(schema: AppData.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = ModelContext(store)
        let trip = Trip(name: "Inverse test", start: .now, end: .now)
        let entry = TripEntry(date: .now)
        context.insert(trip); context.insert(entry); entry.trip = trip
        try context.save()
        precondition(trip.dailyEntries.contains(entry))
        print("PASS: all CloudKit attributes have defaults or are optional; relationships are optional and the inverse works; no unique or deny constraints")
    }
}
