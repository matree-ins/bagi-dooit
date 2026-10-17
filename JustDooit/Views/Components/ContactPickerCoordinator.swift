import ContactsUI

@MainActor
final class ContactPickerCoordinator: NSObject, CNContactPickerDelegate {
    private let onSelectContact: (String, String) -> Void
    private let onDismiss: (() -> Void)?

    init(onSelectContact: @escaping (String, String) -> Void, onDismiss: (() -> Void)? = nil) {
        self.onSelectContact = onSelectContact
        self.onDismiss = onDismiss
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        var components = PersonNameComponents()
        components.givenName = contact.givenName
        components.familyName = contact.familyName
        let fullName = components.formatted().trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
        onSelectContact(fullName.isEmpty ? "Teman" : fullName, phone)
        // iOS CNContactPickerViewController automatically dismisses itself on selection.
        // Do NOT call onDismiss() here to avoid propagating dismiss up to parent SwiftUI containers.
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        onDismiss?()
    }
}
