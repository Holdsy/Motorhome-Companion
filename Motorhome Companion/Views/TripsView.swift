import SwiftUI
import SwiftData

struct TripsView: View {
    @Query(sort: \Trip.start, order: .reverse) private var trips: [Trip]
    @Environment(\.modelContext) private var context
    @State private var adding = false
    @State private var deleting: Trip?
    @State private var error: String?
    var body: some View {
        List {
            if trips.isEmpty {
                ContentUnavailableView("Your next adventure starts here", systemImage: "map", description: Text("Add a trip to keep campsite notes and Angus’s daily highlights together."))
            }
            ForEach(trips) { trip in
                NavigationLink { TripDetailView(trip: trip) } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        if trip.isSample { Label("Sample trip · fictional example", systemImage: "sparkles").font(.caption).foregroundStyle(Color.accentColor) }
                        Text(trip.name).font(.headline)
                        Text("\(trip.start.ukDate) – \(trip.end.ukDate)").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(trip.dailyEntries.count) daily entries").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 7)
                }.swipeActions { Button("Delete", role: .destructive) { deleting = trip } }
                    .contextMenu { Button("Delete", role: .destructive) { deleting = trip } }
            }
        }.navigationTitle("Trips")
            .toolbar { Button { adding = true } label: { Label("Add trip", systemImage: "plus") } }
            .sheet(isPresented: $adding) { TripEditor() }
            .confirmationDialog("Delete this trip and all its entries?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete trip", role: .destructive) { if let deleting { context.delete(deleting); _ = persist(context, error: $error) }; deleting = nil }
            }.saveError($error)
    }
}

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.modelContext) private var context
    @State private var editTrip = false
    @State private var adding = false
    @State private var editing: TripEntry?
    @State private var deleting: TripEntry?
    @State private var error: String?
    var body: some View {
        List {
            Section {
                if trip.isSample { Label("Sample trip · fictional example", systemImage: "sparkles").foregroundStyle(Color.accentColor) }
                Text("\(trip.start.ukDate) – \(trip.end.ukDate)")
                Button("Edit trip details") { editTrip = true }
            }
            if trip.dailyEntries.isEmpty {
                ContentUnavailableView("Remember the little things", systemImage: "pawprint", description: Text("Add a daily entry for your pitch, your day and Angus’s best moment."))
            }
            ForEach(trip.dailyEntries.sorted { $0.date < $1.date }) { entry in
                Button { editing = entry } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(entry.date.ukDate).font(.headline)
                        if !entry.location.isEmpty { Label(entry.location, systemImage: "mappin.and.ellipse") }
                        if let rating = entry.rating { Label("Campsite rating: \(rating)/10", systemImage: "star") }
                        if !entry.notes.isEmpty { Text(entry.notes) }
                        if !entry.angusMoment.isEmpty {
                            Label("Angus Moment of the Day", systemImage: "pawprint.fill").font(.subheadline.bold()).foregroundStyle(Color.accentColor)
                            Text(entry.angusMoment)
                        }
                        Text("Tap to edit").font(.caption).foregroundStyle(Color.accentColor)
                    }.foregroundStyle(.primary).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                    .swipeActions { Button("Delete", role: .destructive) { deleting = entry } }
                    .contextMenu { Button("Delete", role: .destructive) { deleting = entry } }
            }
        }.navigationTitle(trip.name).inlineNavigationTitle()
            .toolbar { Button { adding = true } label: { Label("Add daily entry", systemImage: "plus") } }
            .sheet(isPresented: $editTrip) { TripEditor(trip: trip) }
            .sheet(isPresented: $adding) { EntryEditor(trip: trip) }
            .sheet(item: $editing) { EntryEditor(trip: trip, entry: $0) }
            .confirmationDialog("Delete this daily entry?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete entry", role: .destructive) { if let deleting { context.delete(deleting); _ = persist(context, error: $error) }; deleting = nil }
            }.saveError($error)
    }
}

struct TripEditor: View {
    var trip: Trip?
    @State private var name: String
    @State private var start: Date
    @State private var end: Date
    @State private var error: String?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    init(trip: Trip? = nil) {
        self.trip = trip
        _name = State(initialValue: trip?.name ?? "")
        _start = State(initialValue: trip?.start ?? .now)
        _end = State(initialValue: trip?.end ?? .now)
    }
    private var validation: String? {
        if Input.trimmed(name).isEmpty { return "Give your trip a name." }
        let calendar = Calendar.current
        if calendar.startOfDay(for: end) < calendar.startOfDay(for: start) { return "End date must be on or after the start date." }
        if let trip, trip.dailyEntries.contains(where: { calendar.startOfDay(for: $0.date) < calendar.startOfDay(for: start) || calendar.startOfDay(for: $0.date) > calendar.startOfDay(for: end) }) { return "These dates exclude an existing daily entry. Edit that entry first or widen the trip dates." }
        return nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Field(title: "Trip name", text: $name)
                DatePicker("Start date", selection: $start, displayedComponents: .date)
                DatePicker("End date", selection: $end, displayedComponents: .date)
                if let validation { Text(validation).foregroundStyle(.red) }
            }.navigationTitle(trip == nil ? "Add trip" : "Edit trip")
                .toolbar { EditorToolbar(valid: validation == nil) {
                    let target = trip ?? Trip(name: "", start: start, end: end)
                    if trip == nil { context.insert(target) }
                    target.name = Input.trimmed(name); target.start = Calendar.current.startOfDay(for: start); target.end = Calendar.current.startOfDay(for: end)
                    if persist(context, error: $error) { dismiss() }
                } }.saveError($error)
        }.editorSize()
    }
}

struct EntryEditor: View {
    let trip: Trip
    var entry: TripEntry?
    @State private var date: Date
    @State private var location: String
    @State private var notes: String
    @State private var rating: Int
    @State private var angus: String
    @State private var error: String?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    init(trip: Trip, entry: TripEntry? = nil) {
        self.trip = trip; self.entry = entry
        _date = State(initialValue: entry?.date ?? trip.start)
        _location = State(initialValue: entry?.location ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _rating = State(initialValue: entry?.rating ?? -1)
        _angus = State(initialValue: entry?.angusMoment ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("The day") {
                    DatePicker("Date", selection: $date, in: Calendar.current.startOfDay(for: trip.start)...Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: trip.end)!, displayedComponents: .date)
                    Field(title: "Campsite / location", text: $location)
                    Field(title: "Notes", text: $notes)
                    Picker("Campsite rating", selection: $rating) {
                        Text("Not rated").tag(-1)
                        ForEach(0...10, id: \.self) { Text("\($0) / 10").tag($0) }
                    }
                }
                Section { Field(title: "Angus Moment of the Day", text: $angus) } header: { Label("Travels with Angus", systemImage: "pawprint.fill") }
            }.navigationTitle(entry == nil ? "Add daily entry" : "Edit daily entry")
                .toolbar { EditorToolbar {
                    let target = entry ?? TripEntry(date: date)
                    if entry == nil { context.insert(target); target.trip = trip }
                    target.date = date; target.location = Input.trimmed(location); target.notes = Input.trimmed(notes)
                    target.rating = rating == -1 ? nil : rating; target.angusMoment = Input.trimmed(angus)
                    if persist(context, error: $error) { dismiss() }
                } }.saveError($error)
        }.editorSize()
    }
}
