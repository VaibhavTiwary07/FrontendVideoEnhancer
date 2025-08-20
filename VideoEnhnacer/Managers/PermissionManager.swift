import SwiftUI
import Photos

@MainActor
class PermissionManager: ObservableObject {
    @Published var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @Published var isCheckingPermissions = false
    
    init() {
        checkCurrentStatus()
    }
    
    func checkCurrentStatus() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestPhotoLibraryPermission() async {
        isCheckingPermissions = true
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        await MainActor.run {
            self.photoLibraryStatus = status
            self.isCheckingPermissions = false
        }
    }
    
    var canAccessPhotoLibrary: Bool {
        switch photoLibraryStatus {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }
    
    var needsPermissionRequest: Bool {
        photoLibraryStatus == .notDetermined
    }
    
    var isPermissionDenied: Bool {
        photoLibraryStatus == .denied
    }
    
    var isPermissionRestricted: Bool {
        photoLibraryStatus == .restricted
    }
    
    var hasLimitedAccess: Bool {
        photoLibraryStatus == .limited
    }
    
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    var permissionStatusMessage: String {
        switch photoLibraryStatus {
        case .notDetermined:
            return "Permission not requested"
        case .restricted:
            return "Photo library access is restricted on this device"
        case .denied:
            return "Photo library access was denied. Please enable it in Settings to select videos for enhancement."
        case .authorized:
            return "Full photo library access granted"
        case .limited:
            return "Limited photo library access granted"
        @unknown default:
            return "Unknown permission status"
        }
    }
}

// Permission request result for handling UI updates
enum PermissionResult {
    case granted
    case denied
    case restricted
    case limited
    
    var canProceed: Bool {
        switch self {
        case .granted, .limited:
            return true
        case .denied, .restricted:
            return false
        }
    }
}