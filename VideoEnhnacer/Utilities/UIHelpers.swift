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

    /// Dismisses all presented view controllers from the key window root, iteratively, for legacy stacks (e.g., iOS 15)
    static func dismissAllPresented(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let root = keyWindow()?.rootViewController else {
            completion?(); return
        }
        dismissChain(from: root, animated: animated, completion: completion)
    }

    private static func dismissChain(from base: UIViewController, animated: Bool, completion: (() -> Void)?) {
        // Find the topmost presented VC
        var top = base
        while let presented = top.presentedViewController { top = presented }
        guard top !== base else { completion?(); return }

        // Dismiss chain from top to root
        top.dismiss(animated: animated) {
            if let newRoot = keyWindow()?.rootViewController, newRoot.presentedViewController != nil {
                dismissChain(from: newRoot, animated: animated, completion: completion)
            } else {
                completion?()
            }
        }
    }
}
