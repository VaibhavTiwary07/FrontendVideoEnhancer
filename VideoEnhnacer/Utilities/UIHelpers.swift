import UIKit

enum UIHelpers {
    static func topViewController(base: UIViewController? = UIHelpers.keyWindow()?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }

    static func keyWindow() -> UIWindow? {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return scene.windows.first { $0.isKeyWindow }
        }
        return UIApplication.shared.windows.first { $0.isKeyWindow }
    }
}

