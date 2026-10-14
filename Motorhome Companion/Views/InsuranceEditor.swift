import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

struct InsuranceEditor: View {
    var record: MaintenanceRecord?
    var uploadOnOpen: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var pdf: Data?
    @State private var filename: String
    @State private var provider: String
    @State private var policy: String
    @State private var registration: String
    @State private var policyholder: String
    @State private var start: Date
    @State private var expiry: Date
    @State private var hasExpiry: Bool
    @State private var notes: String
    @State private var importing = false
    @State private var previewing = false
    @State private var message: String?
    @State private var error: String?

    init(record: MaintenanceRecord? = nil, uploadOnOpen: Bool = false) {
        self.uploadOnOpen = uploadOnOpen
        self.record = record
        _pdf = State(initialValue: record?.insurancePDF)
        _filename = State(initialValue: record?.insuranceFilename ?? "")
        _provider = State(initialValue: record?.provider ?? "")
        _policy = State(initialValue: record?.insurancePolicy ?? "")
        _registration = State(initialValue: record?.insuranceRegistration ?? "")
        _policyholder = State(initialValue: record?.insurancePolicyholder ?? "")
        _start = State(initialValue: record?.date ?? .now)
        _expiry = State(initialValue: record?.nextDate ?? .now)
        _hasExpiry = State(initialValue: record?.nextDate != nil)
        _notes = State(initialValue: record?.notes ?? "")
    }
    private var valid: Bool {
        pdf != nil && !Input.trimmed(provider).isEmpty && !Input.trimmed(policy).isEmpty && (!hasExpiry || expiry >= start)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(pdf == nil ? "Upload insurance PDF" : "Replace insurance PDF") { importing = true }
                    if pdf != nil { Button("View certificate: \(filename)") { previewing = true } }
                    if let message { Text(message).foregroundStyle(.secondary) }
                } header: { Text("Digital certificate") } footer: {
                    Text("The PDF is kept with your record. Review the extracted details before saving. If text cannot be read, enter the details manually.")
                }
                Section("Insurance details") {
                    Field(title: "Provider / broker", text: $provider)
                    Field(title: "Policy number(s)", text: $policy)
                    Field(title: "Vehicle registration", text: $registration)
                    Field(title: "Policyholder", text: $policyholder)
                    DatePicker("Cover starts", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    Toggle("Record expiry / renewal date", isOn: $hasExpiry)
                    if hasExpiry { DatePicker("Cover expires / renewal due", selection: $expiry, displayedComponents: [.date, .hourAndMinute]) }
                    Field(title: "Notes", text: $notes)
                }
                if !valid { Text("Attach a PDF and enter the provider and policy number. Expiry must be on or after the cover starts.").foregroundStyle(.secondary) }
            }.navigationTitle(record == nil ? "Add insurance" : "Edit insurance")
                .toolbar { EditorToolbar(valid: valid, save: save) }.saveError($error)
        }.editorSize()
            .task { if uploadOnOpen { importing = true } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    guard let document = PDFDocument(data: data), !document.isLocked else {
                        message = "This PDF cannot be opened. Choose an unlocked certificate."; return
                    }
                    pdf = data; filename = url.lastPathComponent
                    let details = InsuranceDetails(text: document.string ?? "")
                    provider = details.provider; policy = details.policy
                    registration = details.registration; policyholder = details.policyholder
                    start = details.start ?? .now
                    hasExpiry = details.expiry != nil; expiry = details.expiry ?? .now
                    message = "Certificate attached. Check the details below, complete anything missing, then save to create your entry."
                } catch { self.error = "Could not load the certificate: \(error.localizedDescription)" }
            }
            .sheet(isPresented: $previewing) {
                NavigationStack {
                    if let pdf { InsurancePDFPreview(data: pdf).navigationTitle("Insurance certificate").toolbar { Button("Done") { previewing = false } } }
                }.editorSize()
            }
    }
    private func save() {
        guard valid else { return }
        let target = record ?? MaintenanceRecord()
        if record == nil { context.insert(target) }
        target.isInsurance = true; target.insurancePDF = pdf; target.insuranceFilename = filename
        target.provider = Input.trimmed(provider); target.insurancePolicy = Input.trimmed(policy)
        target.insuranceRegistration = Input.trimmed(registration); target.insurancePolicyholder = Input.trimmed(policyholder)
        target.work = "Motorhome insurance"; target.date = start; target.nextDate = hasExpiry ? expiry : nil
        target.notes = Input.trimmed(notes)
        if persist(context, error: $error) { dismiss() }
    }
}

#if os(iOS)
struct InsurancePDFPreview: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.document = PDFDocument(data: data); return view }
    func updateUIView(_ view: PDFView, context: Context) {}
}
#else
struct InsurancePDFPreview: NSViewRepresentable {
    let data: Data
    func makeNSView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.document = PDFDocument(data: data); return view }
    func updateNSView(_ view: PDFView, context: Context) {}
}
#endif
