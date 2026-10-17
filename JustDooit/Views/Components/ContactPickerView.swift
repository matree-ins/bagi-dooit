import SwiftUI
import ContactsUI

struct ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onSelectContact: (String, String) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            if uiViewController.presentedViewController == nil {
                let picker = CNContactPickerViewController()
                picker.delegate = context.coordinator
                picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
                uiViewController.present(picker, animated: true)
            }
        } else {
            // Strictly check that the presented controller is CNContactPickerViewController
            // so we never dismiss any other SwiftUI modal sheet (such as manual friend sheet).
            if let picker = uiViewController.presentedViewController as? CNContactPickerViewController,
               !picker.isBeingDismissed {
                picker.dismiss(animated: true)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerPresenter

        init(_ parent: ContactPickerPresenter) {
            self.parent = parent
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Teman" : fullName
            DispatchQueue.main.async {
                self.parent.isPresented = false
                self.parent.onSelectContact(name, phone)
            }
        }
    }
}
