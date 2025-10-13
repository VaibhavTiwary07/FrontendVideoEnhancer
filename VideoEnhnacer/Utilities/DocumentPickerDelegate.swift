import UIKit

class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    let onComplete: () -> Void
    let onError: (Error?) -> Void
    
    init(onComplete: @escaping () -> Void, onError: @escaping (Error?) -> Void) {
        self.onComplete = onComplete
        self.onError = onError
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onComplete()
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onError(nil)
    }
}

