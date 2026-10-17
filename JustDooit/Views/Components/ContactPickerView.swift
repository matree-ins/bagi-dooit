import SwiftUI
import ContactsUI

struct ContactPickerView: UIViewControllerRepresentable {
    var onSelectContact: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> ContactPickerCoordinator {
        ContactPickerCoordinator(onSelectContact: onSelectContact, onDismiss: { dismiss() })
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
}
