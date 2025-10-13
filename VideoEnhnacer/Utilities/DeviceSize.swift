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
}

