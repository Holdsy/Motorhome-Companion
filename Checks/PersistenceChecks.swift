import Foundation
import SwiftData

@main struct PersistenceChecks {
    @MainActor static func main() throws {
        func check(_ condition: Bool) { precondition(condition) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MotorhomeChecks-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("checks.store")
        func open() throws -> ModelContainer {
            try ModelContainer(for: AppData.schema, configurations: [ModelConfiguration(schema: AppData.schema, url: url, cloudKitDatabase: .none)])
        }
        do {
            let container = try open()
            let context = ModelContext(container)
            context.autosaveEnabled = false
            try AppData.seed(context)
            try AppData.seed(context)
            check(try context.fetchCount(FetchDescriptor<ChecklistItem>()) == 14)
            check(try context.fetchCount(FetchDescriptor<Trip>()) == 1)
            let items = try context.fetch(FetchDescriptor<ChecklistItem>())
            let first = items.first { $0.kind == "Arrival" && $0.order == 0 }!
            first.isComplete = true; first.title = "Edited arrival reminder"
            let record = try context.fetch(FetchDescriptor<MaintenanceRecord>()).first { !$0.isInsurance }!
            assert(record.costPence == 159920 && record.mileage == 14768)
            let insurance = MaintenanceRecord(provider: "Insurance provider", work: "Motorhome insurance")
            insurance.isInsurance = true
            insurance.insurancePDF = Data(repeating: 43, count: 200_000)
            insurance.insuranceFilename = "certificate.pdf"
            insurance.insurancePolicy = "POL123"
            insurance.insuranceRegistration = "AB12 CDE"
            insurance.insurancePolicyholder = "Policyholder"
            context.insert(insurance)
            record.motPhoto = Data(repeating: 42, count: 200_000)
            record.motRegistration = "AB12 CDE"
            record.motCertificate = "1234 5678 9012"
            record.motResult = "PASSED"
            record.motExtractedText = "Expiry date: 31.03.2027"
            record.nextDate = AppData.day(2027, 3, 31)
            record.notes = "Edited maintenance notes"; record.nextMileage = 20000
            let vehicle = try context.fetch(FetchDescriptor<VehicleDetail>()).first { $0.label == "Height (metres)" }!
            assert(vehicle.value.isEmpty); vehicle.value = "3.1 metres (test)"
            let mileage = try context.fetch(FetchDescriptor<Odometer>()).first!
            assert(mileage.miles == 18500); mileage.miles = 19000
            let entry = try context.fetch(FetchDescriptor<TripEntry>()).first!
            entry.angusMoment = "Edited Angus moment"; entry.rating = 10
            let deleted = items.first { $0.kind == "Departure" }!
            context.delete(deleted)
            try context.save()
        }
        do {
            let container = try open()
            let context = ModelContext(container)
            try AppData.seed(context)
            let items = try context.fetch(FetchDescriptor<ChecklistItem>())
            assert(items.count == 13)
            assert(items.contains { $0.title == "Edited arrival reminder" && $0.isComplete })
            assert(items.filter { $0.kind == "Departure" }.allSatisfy { !$0.isComplete })
            check(try context.fetch(FetchDescriptor<MaintenanceRecord>()).first { !$0.isInsurance }!.notes == "Edited maintenance notes")
            check(try context.fetch(FetchDescriptor<MaintenanceRecord>()).first { !$0.isInsurance }!.nextMileage == 20000)
            let insurance = try context.fetch(FetchDescriptor<MaintenanceRecord>()).first { $0.isInsurance }!
            check(insurance.insurancePDF == Data(repeating: 43, count: 200_000))
            check(insurance.insurancePolicy == "POL123" && insurance.insuranceFilename == "certificate.pdf")
            check(insurance.insuranceRegistration == "AB12 CDE" && insurance.insurancePolicyholder == "Policyholder")
            let mot = try context.fetch(FetchDescriptor<MaintenanceRecord>()).first { !$0.isInsurance }!
            check(mot.motPhoto == Data(repeating: 42, count: 200_000))
            check(mot.motRegistration == "AB12 CDE" && mot.motCertificate == "1234 5678 9012")
            check(mot.motResult == "PASSED" && mot.motExtractedText == "Expiry date: 31.03.2027")
            check(mot.nextDate == AppData.day(2027, 3, 31))
            check(try context.fetch(FetchDescriptor<VehicleDetail>()).contains { $0.value == "3.1 metres (test)" })
            check(try context.fetch(FetchDescriptor<Odometer>()).first!.miles == 19000)
            check(try context.fetch(FetchDescriptor<TripEntry>()).first!.angusMoment == "Edited Angus moment")
            let trip = try context.fetch(FetchDescriptor<Trip>()).first!
            context.delete(trip); try context.save()
        }
        do {
            let container = try open()
            let context = ModelContext(container)
            try AppData.seed(context)
            check(try context.fetchCount(FetchDescriptor<Trip>()) == 0)
            check(try context.fetchCount(FetchDescriptor<TripEntry>()) == 0)
            check(try context.fetchCount(FetchDescriptor<SeedState>()) == 1)
        }
        assert(Input.pence("") == nil)
        assert(Input.pence("1599.20") == 159920)
        assert(Input.pence("0") == 0)
        assert(Input.pence("12.3") == 1230)
        for invalid in ["-1", "nan", "1.234", "1,000", "£4", ".", "1."] { assert(Input.pence(invalid) == nil) }
        for invalid in ["", "-1", "1.5", "18,500", "10000000"] { assert(Input.miles(invalid) == nil) }
        assert(Input.miles("18500") == 18500)
        print("PASS: persistence after reopening, independent checklists, edits, deletions, cascade deletion, seed idempotency and numeric validation")
    }
}
