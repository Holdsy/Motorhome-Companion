import SwiftUI
import SwiftData

// Every mutation is saved explicitly; failures are visible and roll back the change.
func persist(_ context: ModelContext, error: Binding<String?>) -> Bool {
    do { try context.save(); return true }
    catch let failure { context.rollback(); error.wrappedValue = errorMessage(failure); return false }
}
private func errorMessage(_ error: Error) -> String { "Your change could not be saved. Please try again.\n\n\(error.localizedDescription)" }

struct SaveError: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        content.alert("Couldn’t save", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}
extension View {
    func saveError(_ message: Binding<String?>) -> some View { modifier(SaveError(message: message)) }
}

struct EditorToolbar: ToolbarContent {
    var valid: Bool = true
    var cancel: (() -> Void)?
    var save: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { cancel?() ?? dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!valid) }
    }
}

struct Field: View {
    let title: String
    @Binding var text: String
    var keyboard: FieldKeyboard = .default
    var lineLimit: ClosedRange<Int> = 1...1
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            TextField("", text: $text, axis: .vertical)
                .lineLimit(lineLimit)
                .fieldKeyboard(keyboard)
                .accessibilityLabel(title)
        }.padding(.vertical, 4)
    }
}

// Keep the forms shared while using the keyboard appropriate to each platform.
enum FieldKeyboard { case `default`, numberPad, decimalPad }
extension View {
    @ViewBuilder func fieldKeyboard(_ keyboard: FieldKeyboard) -> some View {
        #if os(iOS)
        self.keyboardType(keyboard == .numberPad ? .numberPad : keyboard == .decimalPad ? .decimalPad : .default)
        #else
        self
        #endif
    }
    @ViewBuilder func editorSize(
        minWidth: CGFloat = 500,
        idealWidth: CGFloat = 560,
        minHeight: CGFloat = 420,
        idealHeight: CGFloat = 650
    ) -> some View {
        #if os(macOS)
        self.frame(
            minWidth: minWidth,
            idealWidth: idealWidth,
            minHeight: minHeight,
            idealHeight: idealHeight
        )
        #else
        self
        #endif
    }
    @ViewBuilder func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
