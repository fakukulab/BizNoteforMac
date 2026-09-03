import SwiftUI
import AppKit
import Contacts
import ContactsUI

/// A small toolbar-style button that opens the macOS Contacts popover picker
/// and reports the chosen contact back to the caller. Renders as a plain
/// icon by default, or as a titled button when `title` is provided.
struct ContactPickerButton: NSViewRepresentable {
    var onSelect: (CNContact) -> Void
    var title: String? = nil

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeNSView(context: Context) -> NSButton {
        let button: NSButton
        if let title {
            button = NSButton(title: title, target: context.coordinator,
                               action: #selector(Coordinator.showPicker(_:)))
            button.bezelStyle = .rounded
        } else {
            let image = NSImage(systemSymbolName: "person.crop.circle.badge.magnifyingglass",
                                 accessibilityDescription: String(localized: "contacts.import", defaultValue: "주소록에서 불러오기"))
                ?? NSImage()
            button = NSButton(image: image, target: context.coordinator,
                               action: #selector(Coordinator.showPicker(_:)))
            button.isBordered = false
            button.bezelStyle = .regularSquare
        }
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.onSelect = onSelect
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var onSelect: (CNContact) -> Void
        weak var button: NSButton?
        private let picker = CNContactPicker()

        init(onSelect: @escaping (CNContact) -> Void) {
            self.onSelect = onSelect
            super.init()
            picker.delegate = self
        }

        @objc func showPicker(_ sender: NSButton) {
            Task { @MainActor in
                let granted = await ContactsService.requestAccess()
                guard granted, let button else { return }
                picker.showRelative(to: button.bounds, of: button, preferredEdge: .maxY)
            }
        }

        func contactPicker(_ picker: CNContactPicker, didSelect contact: CNContact) {
            onSelect(contact)
        }
    }
}

/// Pairs the two contact actions (import / add) for embedding next to a
/// person's fields in the meeting or exhibition templates. "Add" saves the
/// contact directly to the user's address book — CNContactViewController's
/// editor sheet isn't available on plain AppKit macOS (Catalyst/iOS only),
/// so this uses CNSaveRequest instead of an interactive editor.
///
/// By default renders as two small icon buttons; pass `showsLabels: true`
/// to render them as titled text buttons instead (used where the row layout
/// calls for text actions rather than icons).
struct ContactActionButtons: View {
    var onImport: (CNContact) -> Void
    var makeNewContact: () -> CNMutableContact
    var showsLabels: Bool = false
    var axis: Axis = .horizontal

    @State private var showSuccess = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if axis == .horizontal {
                HStack(spacing: 4) { buttons }
            } else {
                VStack(alignment: .leading, spacing: 4) { buttons }
            }
        }
        .alert(String(localized: "contacts.add.success", defaultValue: "주소록에 추가되었습니다"),
               isPresented: $showSuccess) {
            Button(String(localized: "action.ok", defaultValue: "확인"), role: .cancel) {}
        }
        .alert(String(localized: "contacts.add.error", defaultValue: "주소록에 추가하지 못했습니다"),
               isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(String(localized: "action.ok", defaultValue: "확인"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if showsLabels {
            ContactPickerButton(onSelect: onImport,
                                 title: String(localized: "contacts.import.short", defaultValue: "주소록"))
            Button(String(localized: "contacts.add.short", defaultValue: "연락처 추가")) {
                addToContacts()
            }
            .buttonStyle(.bordered)
            .help(String(localized: "contacts.add", defaultValue: "주소록에 추가"))
        } else {
            ContactPickerButton(onSelect: onImport)
                .frame(width: 20, height: 20)
                .help(String(localized: "contacts.import", defaultValue: "주소록에서 불러오기"))
            Button {
                addToContacts()
            } label: {
                Image(systemName: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.plain)
            .help(String(localized: "contacts.add", defaultValue: "주소록에 추가"))
        }
    }

    private func addToContacts() {
        Task {
            let granted = await ContactsService.requestAccess()
            guard granted else {
                errorMessage = String(localized: "contacts.access.denied", defaultValue: "주소록 접근 권한이 필요합니다.")
                return
            }
            let contact = makeNewContact()
            let request = CNSaveRequest()
            request.add(contact, toContainerWithIdentifier: nil)
            do {
                try CNContactStore().execute(request)
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
