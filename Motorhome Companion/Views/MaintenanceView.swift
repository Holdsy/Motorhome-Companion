import SwiftUI
import SwiftData
import PhotosUI

struct MaintenanceView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var records: [MaintenanceRecord]
    @State private var adding = false
    @State private var addingInsurance = false
    @State private var addingMOT = false
    @State private var editing: MaintenanceRecord?
    @State private var deleting: MaintenanceRecord?
    @State private var error: String?
    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView("A place for your service history", systemImage: "wrench.and.screwdriver", description: Text("Add a service, repair or inspection using the plus button."))
            }
            ForEach(records) { record in
                Button { editing = record } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(record.date.ukDate).font(.headline)
                        Text(record.provider).font(.subheadline.bold())
                        if !record.isInsurance { Text("\(record.mileage.formatted()) miles").foregroundStyle(.secondary) }
                        if record.isInsurance { Label("Insurance certificate", systemImage: "doc.text") }
                        Text(record.work)
                        if record.motPhoto != nil { Label("MOT digital record", systemImage: "doc.viewfinder") }
                        if let cost = record.costPence { Text((Double(cost) / 100).formatted(.currency(code: "GBP"))).font(.headline).foregroundStyle(Color.accentColor) }
                        if !record.notes.isEmpty { Text(record.notes).foregroundStyle(.secondary) }
                        if let next = record.nextDate { Label("Next due: \(next.ukDate)", systemImage: "calendar") }
                        Text("Tap to edit").font(.caption).foregroundStyle(Color.accentColor)
                    }.foregroundStyle(.primary).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                    .swipeActions { Button("Delete", role: .destructive) { deleting = record } }
                    .contextMenu { Button("Delete", role: .destructive) { deleting = record } }
            }
        }.navigationTitle("Maintenance")
            .toolbar {
                Menu {
                    Button("Upload MOT") { addingMOT = true }
                    Button("Upload Insurance certificate") { addingInsurance = true }
                    Button("Add Maintenance record") { adding = true }
                } label: { Label("Add record", systemImage: "plus") }
            }
            .sheet(isPresented: $adding) { MaintenanceEditor() }
            .sheet(isPresented: $addingMOT) { MaintenanceEditor(uploadMOT: true) }
            .sheet(isPresented: $addingInsurance) { InsuranceEditor(uploadOnOpen: true) }
            .sheet(item: $editing) { record in
                if record.isInsurance { InsuranceEditor(record: record) }
                else { MaintenanceEditor(record: record) }
            }
            .confirmationDialog("Delete this maintenance record?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete record", role: .destructive) { if let deleting { context.delete(deleting); _ = persist(context, error: $error) }; deleting = nil }
            }.saveError($error)
    }
}

struct MaintenanceEditor: View {
    var record: MaintenanceRecord?
    var uploadMOT: Bool
    @State private var showingPhotoPicker = false
    @State private var date: Date
    @State private var mileage: String
    @State private var provider: String
    @State private var work: String
    @State private var cost: String
    @State private var notes: String
    @State private var hasNextDate: Bool
    @State private var nextDate: Date
    @State private var photo: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var scanning = false
    @State private var scanMessage: String?
    @State private var registration: String
    @State private var certificate: String
    @State private var result: String
    @State private var extractedText: String
    @State private var viewingPhoto = false
    @State private var error: String?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    init(record: MaintenanceRecord? = nil, uploadMOT: Bool = false) {
        self.uploadMOT = uploadMOT
        self.record = record
        _photo = State(initialValue: record?.motPhoto)
        _registration = State(initialValue: record?.motRegistration ?? "")
        _certificate = State(initialValue: record?.motCertificate ?? "")
        _result = State(initialValue: record?.motResult ?? "")
        _extractedText = State(initialValue: record?.motExtractedText ?? "")
        _date = State(initialValue: record?.date ?? .now)
        _mileage = State(initialValue: record.map { String($0.mileage) } ?? "")
        _provider = State(initialValue: record?.provider ?? "")
        _work = State(initialValue: record?.work ?? "")
        _cost = State(initialValue: Input.costText(record?.costPence))
        _notes = State(initialValue: record?.notes ?? "")
        _hasNextDate = State(initialValue: record?.nextDate != nil)
        _nextDate = State(initialValue: record?.nextDate ?? .now)
    }
    private var validation: String? {
        guard Input.miles(mileage) != nil else { return "Enter mileage as whole miles from 0 to 9,999,999, without commas." }
        if Input.trimmed(provider).isEmpty || Input.trimmed(work).isEmpty { return "Enter a provider and the work completed." }
        if !Input.trimmed(cost).isEmpty && Input.pence(cost) == nil { return "Enter a positive or zero cost with up to two decimal places, such as 1599.20, without £ or commas." }
        if hasNextDate && Calendar.current.startOfDay(for: nextDate) < Calendar.current.startOfDay(for: date) { return "Next due date must be on or after the work date." }
        return nil
    }
    private var visibleValidation: String? {
        if !Input.trimmed(mileage).isEmpty, Input.miles(mileage) == nil {
            return "Enter mileage as whole miles from 0 to 9,999,999, without commas."
        }
        if !Input.trimmed(cost).isEmpty, Input.pence(cost) == nil {
            return "Enter a positive or zero cost with up to two decimal places, without £ or commas."
        }
        if hasNextDate && Calendar.current.startOfDay(for: nextDate) < Calendar.current.startOfDay(for: date) {
            return "Next due date must be on or after the work date."
        }
        return nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                    Field(title: "Mileage (whole miles)", text: $mileage, keyboard: .numberPad)
                    Field(title: "Provider", text: $provider)
                    Field(title: "Work completed", text: $work, lineLimit: 2...5)
                    Field(title: "Cost (£, optional)", text: $cost, keyboard: .decimalPad)
                    Field(title: "Notes (optional)", text: $notes, lineLimit: 3...6)
                } header: {
                    Text("Maintenance details")
                } footer: {
                    if let visibleValidation {
                        Text(visibleValidation).foregroundStyle(.red)
                    }
                }
                Section {
                    Toggle("Record next due date", isOn: $hasNextDate)
                    if hasNextDate { DatePicker(photo == nil ? "Next due date" : "MOT renewal / next due", selection: $nextDate, displayedComponents: .date) }
                } header: { Text("Next due") } footer: { Text("Only record dates you have been given. No service interval is assumed; this does not schedule a notification.") }
                if uploadMOT || photo != nil {
                    Section {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(photo == nil ? "Choose MOT photo" : "Replace MOT photo", systemImage: "photo.on.rectangle")
                        }
                        .disabled(scanning)
                        if scanning { ProgressView("Reading MOT certificate…") }
                        if let scanMessage { Text(scanMessage).foregroundStyle(.secondary) }
                        if let photo {
                            Button { viewingPhoto = true } label: {
                                MOTPhoto(data: photo).frame(maxHeight: 180)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("View full MOT certificate")
                            Field(title: "Vehicle registration", text: $registration)
                            Field(title: "MOT test number", text: $certificate)
                            Field(title: "Test result", text: $result)
                            if !extractedText.isEmpty {
                                DisclosureGroup("Text read from certificate") {
                                    Text(extractedText).textSelection(.enabled)
                                }
                            }
                            Button("Remove MOT attachment", role: .destructive) {
                                self.photo = nil
                                registration = ""
                                certificate = ""
                                result = ""
                                extractedText = ""
                                selectedPhoto = nil
                            }
                        }
                    } header: {
                        Text("MOT certificate")
                    } footer: {
                        Text("Check the scanned details against the certificate before saving.")
                    }
                }
            }.navigationTitle(record == nil ? "Add record" : "Edit record")
                .inlineNavigationTitle()
                .toolbar {
                    EditorToolbar(
                        valid: validation == nil && !scanning,
                        cancel: { dismiss() },
                        save: save
                    )
                }
                .saveError($error)
        }.editorSize(minWidth: 620, idealWidth: 680, minHeight: 600, idealHeight: 720)
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
            .task { if uploadMOT { showingPhotoPicker = true } }
            .task(id: selectedPhoto) { await importPhoto() }
            .sheet(isPresented: $viewingPhoto) {
                NavigationStack {
                    ScrollView { if let photo { MOTPhoto(data: photo).padding() } }
                        .navigationTitle("MOT certificate")
                        .toolbar { Button("Done") { viewingPhoto = false } }
                }.editorSize()
            }
    }
    @MainActor private func importPhoto() async {
        guard let selection = selectedPhoto else { return }
        scanning = true
        defer { scanning = false }
        do {
            guard let data = try await selection.loadTransferable(type: Data.self) else {
                scanMessage = "Could not load this photo. Please choose another image."; return
            }
            guard !Task.isCancelled else { return }
            photo = data
            registration = ""; certificate = ""; result = ""; extractedText = ""
            do {
                let details = try await MOTScanner.scan(data)
                guard !Task.isCancelled else { return }
                extractedText = details.text
                registration = details.registration; certificate = details.certificate; result = details.result
                if !details.provider.isEmpty { provider = details.provider }
                if let testDate = details.testDate, testDate <= .now { date = testDate }
                if let miles = details.mileage { mileage = miles }
                if let expiry = details.expiryDate { nextDate = expiry; hasNextDate = true }
                if Input.trimmed(work).isEmpty { work = "MOT" }
                scanMessage = details.expiryDate == nil
                    ? "Photo attached. No expiry date could be read. Enter the renewal date from your certificate and check the other details."
                    : "Photo attached. Review the extracted details and MOT renewal date below, then save."
            } catch {
                scanMessage = "Photo attached, but text could not be read. Enter the certificate details and renewal date manually."
            }
        } catch {
            scanMessage = "Could not load the photo. If it is in iCloud Photos, check your connection and try again."
        }
    }
    private func save() {
        guard validation == nil, let miles = Input.miles(mileage) else { return }
        let target = record ?? MaintenanceRecord()
        if record == nil { context.insert(target) }
        target.date = date; target.mileage = miles; target.provider = Input.trimmed(provider)
        target.work = Input.trimmed(work); target.costPence = Input.pence(cost); target.notes = Input.trimmed(notes)
        target.motPhoto = photo; target.motRegistration = Input.trimmed(registration)
        target.motCertificate = Input.trimmed(certificate); target.motResult = Input.trimmed(result)
        target.motExtractedText = extractedText
        target.nextDate = hasNextDate ? nextDate : nil
        if persist(context, error: $error) { dismiss() }
    }
}
