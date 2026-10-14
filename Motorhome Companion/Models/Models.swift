import Foundation
import SwiftData

@Model final class SeedState {
    var version: Int = 0
    init(version: Int = 1) { self.version = version }
}

@Model final class ChecklistItem {
    var title: String = ""
    var kind: String = ""
    var order: Int = 0
    var isComplete: Bool = false
    init(_ title: String, kind: String, order: Int) {
        self.title = title; self.kind = kind; self.order = order; isComplete = false
    }
}

@Model final class VehicleDetail {
    var label: String = ""
    var value: String = ""
    var order: Int = 0
    init(_ label: String, _ value: String, order: Int) {
        self.label = label; self.value = value; self.order = order
    }
}

@Model final class Odometer {
    var miles: Int = 0
    var date: Date = Date(timeIntervalSince1970: 0)
    init(miles: Int, date: Date) { self.miles = miles; self.date = date }
}

@Model final class MaintenanceRecord {
    var date: Date = Date(timeIntervalSince1970: 0)
    var mileage: Int = 0
    var provider: String = ""
    var work: String = ""
    var costPence: Int?
    var notes: String = ""
    var nextDate: Date?
    var nextMileage: Int?
    @Attribute(.externalStorage) var motPhoto: Data?
    var motRegistration: String = ""
    var motCertificate: String = ""
    var motResult: String = ""
    var motExtractedText: String = ""
    var isInsurance: Bool = false
    @Attribute(.externalStorage) var insurancePDF: Data?
    var insuranceFilename: String = ""
    var insurancePolicy: String = ""
    var insuranceRegistration: String = ""
    var insurancePolicyholder: String = ""
    init(date: Date = .now, mileage: Int = 0, provider: String = "", work: String = "", costPence: Int? = nil, notes: String = "") {
        self.date = date; self.mileage = mileage; self.provider = provider
        self.work = work; self.costPence = costPence; self.notes = notes
    }
}

@Model final class Trip {
    var name: String = ""
    var start: Date = Date(timeIntervalSince1970: 0)
    var end: Date = Date(timeIntervalSince1970: 0)
    var isSample: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \TripEntry.trip) var entries: [TripEntry]? = []
    var dailyEntries: [TripEntry] { entries ?? [] }
    init(name: String, start: Date, end: Date, isSample: Bool = false) {
        self.name = name; self.start = start; self.end = end; self.isSample = isSample
    }
}

@Model final class TripEntry {
    var date: Date = Date(timeIntervalSince1970: 0)
    var location: String = ""
    var notes: String = ""
    var rating: Int?
    var angusMoment: String = ""
    var trip: Trip?
    init(date: Date, location: String = "", notes: String = "", rating: Int? = nil, angusMoment: String = "") {
        self.date = date; self.location = location; self.notes = notes
        self.rating = rating; self.angusMoment = angusMoment
    }
}

enum AppData {
    static let schema = Schema([SeedState.self, ChecklistItem.self, VehicleDetail.self, Odometer.self, MaintenanceRecord.self, Trip.self, TripEntry.self])
    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    static func seed(_ context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<SeedState>()) == 0 else { return }
        let arrival = ["Position the motorhome between the pitch pegs, front-on.", "Level using the VB Air Suspension remote.", "Check the levelling indicator light is off.", "Connect electric hookup using the short cable where suitable.", "Turn on gas, using the left bottle first.", "Fit external thermal screens if required."]
        let departure = ["Secure loose items, cupboards and fridge.", "Close rooflights and windows.", "Retract and secure the awning.", "Disconnect and store electric hookup.", "Turn off gas.", "Remove and store thermal screens.", "Check the levelling system is ready for travel.", "Walk around the vehicle and check the pitch."]
        for (kind, titles) in [("Arrival", arrival), ("Departure", departure)] {
            for (index, title) in titles.enumerated() { context.insert(ChecklistItem(title, kind: kind, order: index)) }
        }
        let details = [("Model", "Carthago c-tourer T 148 H"), ("Year", "2019"), ("Length", "7.5 metres"), ("Habitation door", "Right-hand side"), ("Tyres", "Michelin Agilis 225/75 R16 C"), ("Tyre load index", "116/114"), ("Suspension", "VB Air Suspension with remote levelling"), ("Awning", "Thule Omnistor 9200"), ("Roof solar", "100 W"), ("Leisure battery", "80 Ah gel"), ("Internet", "Starlink Mini"), ("Router", "GL.iNet X3000"), ("Portable power", "Anker Solix 1000"), ("Height (metres)", ""), ("Weight limits (kg)", ""), ("Tyre pressures (include units)", "")]
        for (index, detail) in details.enumerated() { context.insert(VehicleDetail(detail.0, detail.1, order: index)) }
        context.insert(Odometer(miles: 18500, date: day(2026, 9, 30)))
        context.insert(MaintenanceRecord(date: day(2026, 4, 1), mileage: 14768, provider: "Camper UK Service Centre", work: "MOT, habitation/leak inspection, standard mechanical service, replacement airbag control unit, new wiper blades and new engine battery.", costPence: 159920, notes: "Battery: Exide 0170 95 Ah."))
        let sample = Trip(name: "A weekend away", start: day(2026, 9, 12), end: day(2026, 9, 13), isSample: true)
        context.insert(sample)
        let entry = TripEntry(date: sample.start, location: "Example countryside campsite", notes: "An example entry: a quiet pitch and a cup of tea after setting up.", rating: 8, angusMoment: "Angus found the perfect spot for an afternoon snooze.")
        context.insert(entry); entry.trip = sample
        context.insert(SeedState())
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

enum Input {
    static func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func miles(_ text: String) -> Int? {
        let value = trimmed(text)
        guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(value), number <= 9_999_999 else { return nil }
        return number
    }
    static func pence(_ text: String) -> Int? {
        let value = trimmed(text)
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, let pounds = miles(String(parts[0])), parts.count == 1 || (parts[1].count <= 2 && !parts[1].isEmpty && parts[1].allSatisfy({ $0.isASCII && $0.isNumber })) else { return nil }
        let fraction = parts.count == 2 ? Int(parts[1])! * (parts[1].count == 1 ? 10 : 1) : 0
        return pounds * 100 + fraction
    }
    static func costText(_ pence: Int?) -> String {
        guard let pence else { return "" }
        return String(format: "%d.%02d", pence / 100, pence % 100)
    }
}

extension Date {
    var ukDate: String { formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "en_GB"))) }
}
