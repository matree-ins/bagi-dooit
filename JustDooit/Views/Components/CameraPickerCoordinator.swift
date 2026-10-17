import UIKit

@MainActor
final class CameraPickerCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    private let onImagePicked: (UIImage) -> Void
    private let onDismiss: () -> Void

    init(onImagePicked: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
        self.onImagePicked = onImagePicked
        self.onDismiss = onDismiss
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.originalImage] as? UIImage { onImagePicked(image) }
        onDismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onDismiss() }
}
