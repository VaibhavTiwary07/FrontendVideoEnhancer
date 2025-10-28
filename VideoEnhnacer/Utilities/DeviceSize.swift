import SwiftUI
import UIKit

enum DeviceSize {
    /// Treat very small screens (e.g., iPod touch, iPhone SE/8) as small phones
    static var isSmallPhone: Bool {
        let size = UIScreen.main.bounds.size
        let minSide = min(size.width, size.height)
        let maxSide = max(size.width, size.height)
        return minSide <= 320 || maxSide <= 736
    }

    /// Check if device supports 4K video processing
    static var supports4K: Bool {
        // iPod touch does not support 4K processing
        let model = UIDevice.current.model
        if model.contains("iPod") {
            return false
        }

        // Check screen size - small devices typically lack 4K capability
        let maxSide = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        if maxSide <= 736 { // iPhone 8 Plus and smaller
            return false
        }

        return true
    }
}

