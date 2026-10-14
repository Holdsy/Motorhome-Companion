import SwiftUI
import SwiftData

struct VehicleView: View {
    @Query(sort: \VehicleDetail.order) private var details: [VehicleDetail]
    @Query private var odometers: [Odometer]
    @State private var editing: VehicleDetail?
    @State private var editMileage = false
    var body: some View {
        List {
            Section { NavigationLink { SyncStatusView() } label: { Label("iCloud Sync", systemImage: "icloud") } }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Our home on wheels", systemImage: "bus.fill").font(.title2.bold()).foregroundStyle(Color.accentColor)
                    Text("Mark, Jane & Angus").foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }
            if let mileage = odometers.first {
                Section("Last recorded mileage") {
                    Button { editMileage = true } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(mileage.miles.formatted()) miles").font(.headline).foregroundStyle(.primary)
                            Text("Recorded \(mileage.date.ukDate)").foregroundStyle(.secondary)
                            Text("Edit mileage").font(.subheadline)
                        }.padding(.vertical, 4)
                    }
                }
            }
            Section {
                ForEach(details) { detail in
                    Button { editing = detail } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(detail.label).font(.subheadline).foregroundStyle(.secondary)
                            Text(detail.value.isEmpty ? "Not recorded" : detail.value).foregroundStyle(.primary)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.accessibilityHint("Double tap to edit")
                }
            } header: { Text("Vehicle & equipment") } footer: { Text("Tap any detail to edit it. Record height, weight limits and tyre pressures from your own vehicle documentation, including units and relevant axle or load conditions.") }
        }.navigationTitle("My Motorhome")
            .sheet(item: $editing) { VehicleDetailEditor(detail: $0) }
            .sheet(isPresented: $editMileage) { if let mileage = odometers.first { OdometerEditor(odometer: mileage) } }
    }
}

struct VehicleDetailEditor: View {
    let detail: VehicleDetail
    @State private var value: String
    @State private var error: String?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    init(detail: VehicleDetail) { self.detail = detail; _value = State(initialValue: detail.value) }
    var body: some View {
        NavigationStack {
            Form {
                Section { Field(title: detail.label, text: $value) } footer: { Text("Leave blank to show ‘Not recorded’. Include units where needed.") }
            }.navigationTitle("Edit detail").toolbar { EditorToolbar {
                detail.value = Input.trimmed(value)
                if persist(context, error: $error) { dismiss() }
            } }.saveError($error)
        }.editorSize()
    }
}

struct OdometerEditor: View {
    let odometer: Odometer
    @State private var miles: String
    @State private var date: Date
    @State private var error: String?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    init(odometer: Odometer) {
        self.odometer = odometer
        _miles = State(initialValue: String(odometer.miles)); _date = State(initialValue: odometer.date)
    }
    var body: some View {
        NavigationStack {
            Form {
                Field(title: "Mileage (whole miles)", text: $miles, keyboard: .numberPad)
                DatePicker("Recorded on", selection: $date, in: ...Date.now, displayedComponents: .date)
                if Input.miles(miles) == nil { Text("Enter whole miles from 0 to 9,999,999, without commas.").foregroundStyle(.red) }
            }.navigationTitle("Recorded mileage").toolbar { EditorToolbar(valid: Input.miles(miles) != nil) {
                guard let number = Input.miles(miles) else { return }
                odometer.miles = number; odometer.date = date
                if persist(context, error: $error) { dismiss() }
            } }.saveError($error)
        }.editorSize()
    }
}
