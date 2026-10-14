import SwiftUI
import SwiftData

struct ChecklistsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ChecklistItem.order) private var allItems: [ChecklistItem]
    @State private var kind = "Arrival"
    @State private var editing: ChecklistItem?
    @State private var adding = false
    @State private var reset = false
    @State private var deleting: ChecklistItem?
    @State private var error: String?
    private var items: [ChecklistItem] { allItems.filter { $0.kind == kind } }
    private var complete: Int { items.filter(\.isComplete).count }
    var body: some View {
        List {
            Section {
                Picker("Checklist", selection: $kind) {
                    Text("Arrival").tag("Arrival")
                    Text("Departure").tag("Departure")
                }.pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 10) {
                    Label(kind == "Arrival" ? "Make yourselves at home" : "Ready for the road", systemImage: kind == "Arrival" ? "leaf" : "road.lanes")
                        .font(.title2.bold())
                    Text("\(complete) of \(items.count) complete").font(.headline)
                    ProgressView(value: Double(complete), total: Double(max(items.count, 1)))
                        .accessibilityLabel("\(kind) progress")
                        .accessibilityValue("\(complete) of \(items.count) complete")
                }.padding(.vertical, 10)
            }
            Section {
                if items.isEmpty { Text("Add your first reminder using the plus button.").foregroundStyle(.secondary) }
                ForEach(items) { item in
                    HStack(alignment: .center, spacing: 8) {
                        Button {
                            item.isComplete.toggle()
                            _ = persist(context, error: $error)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                    .font(.title).foregroundStyle(Color.accentColor)
                                Text(item.title).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }.frame(minHeight: 52).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel(item.title)
                            .accessibilityValue(item.isComplete ? "Complete" : "Not complete")
                            .accessibilityHint("Double tap to change completion")
                        Button { editing = item } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                            .buttonStyle(.borderless).accessibilityLabel("Edit \(item.title)")
                    }
                    .swipeActions { Button("Delete", role: .destructive) { deleting = item } }
                    .contextMenu {
                        Button("Edit reminder") { editing = item }
                        Button("Move up") { move(item, by: -1) }.disabled(items.first == item)
                        Button("Move down") { move(item, by: 1) }.disabled(items.last == item)
                        Button("Delete reminder", role: .destructive) { deleting = item }
                    }
                }.onMove { indices, destination in
                    var ordered = items
                    ordered.move(fromOffsets: indices, toOffset: destination)
                    for (index, item) in ordered.enumerated() { item.order = index }
                    _ = persist(context, error: $error)
                }
            } footer: { Text("Personal reminders for Mark and Jane. Use your vehicle and equipment manuals for operating instructions.") }
            Section {
                Button("Reset \(kind.lowercased()) checklist", role: .destructive) { reset = true }.disabled(complete == 0)
            }
        }
        .navigationTitle("Checklists")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            #endif
            ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Label("Add reminder", systemImage: "plus") } }
        }
        .sheet(isPresented: $adding) { ChecklistEditor(kind: kind, order: (items.map(\.order).max() ?? -1) + 1) }
        .sheet(item: $editing) { ChecklistEditor(item: $0, kind: kind, order: $0.order) }
        .confirmationDialog("Reset \(kind.lowercased()) progress?", isPresented: $reset, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive) { for item in items { item.isComplete = false }; _ = persist(context, error: $error) }
        } message: { Text("Your reminders will stay; their checkmarks will be cleared.") }
        .confirmationDialog("Delete this reminder?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete reminder", role: .destructive) { if let deleting { context.delete(deleting); _ = persist(context, error: $error) }; deleting = nil }
        }
        .saveError($error)
    }
    private func move(_ item: ChecklistItem, by offset: Int) {
        var ordered = items
        guard let index = ordered.firstIndex(of: item), ordered.indices.contains(index + offset) else { return }
        ordered.swapAt(index, index + offset)
        for (index, item) in ordered.enumerated() { item.order = index }
        _ = persist(context, error: $error)
    }
}

struct ChecklistEditor: View {
    var item: ChecklistItem?
    let kind: String
    let order: Int
    @State private var title: String
    @State private var error: String?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    init(item: ChecklistItem? = nil, kind: String, order: Int) {
        self.item = item; self.kind = kind; self.order = order
        _title = State(initialValue: item?.title ?? "")
    }
    var body: some View {
        NavigationStack {
            Form { Field(title: "Reminder", text: $title) }
                .navigationTitle(item == nil ? "Add reminder" : "Edit reminder")
                .toolbar { EditorToolbar(valid: !Input.trimmed(title).isEmpty) {
                    if let item { item.title = Input.trimmed(title) }
                    else { context.insert(ChecklistItem(Input.trimmed(title), kind: kind, order: order)) }
                    if persist(context, error: $error) { dismiss() }
                } }.saveError($error)
        }.editorSize()
    }
}
