import SwiftUI
import UIKit
import AVFoundation
import MobileCoreServices

struct NativeVideoTrimmerView: UIViewControllerRepresentable {
    let videoURL: URL
    let onComplete: (URL?) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIVideoEditorController {
        let videoEditor = UIVideoEditorController()
        videoEditor.videoPath = videoURL.path
        videoEditor.delegate = context.coordinator
        videoEditor.videoMaximumDuration = 300 // 5 minutes max
        videoEditor.videoQuality = .typeHigh
        return videoEditor
    }
    
    func updateUIViewController(_ uiViewController: UIVideoEditorController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIVideoEditorControllerDelegate, UINavigationControllerDelegate {
        let parent: NativeVideoTrimmerView
        
        init(parent: NativeVideoTrimmerView) {
            self.parent = parent
        }
        
        func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
            let editedURL = URL(fileURLWithPath: editedVideoPath)
            parent.onComplete(editedURL)
        }
        
        func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
            print("Video editing failed: \(error.localizedDescription)")
            parent.onComplete(nil)
        }
        
        func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
            parent.onCancel()
        }
    }
    
    static func isVideoEditingSupported() -> Bool {
        return UIVideoEditorController.canEditVideo(atPath: "")
    }
}

#Preview {
    Text("Native Video Trimmer Preview")
        .onAppear {
            print("Video editing supported: \(NativeVideoTrimmerView.isVideoEditingSupported())")
        }
}