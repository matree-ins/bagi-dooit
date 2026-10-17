import SwiftUI
import UIKit

struct CameraPickerView: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .camera
    var onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> CameraPickerCoordinator {
        CameraPickerCoordinator(onImagePicked: onImagePicked, onDismiss: { dismiss() })
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
