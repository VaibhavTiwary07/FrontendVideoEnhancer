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

    /// Check if device is an iPod touch (all models)
    static var isiPod: Bool {
        let modelIdentifier = getDeviceModelIdentifier()
        return modelIdentifier.contains("iPod")
    }

    /// Check if device supports 4K video processing based on hardware capability
    static var supports4K: Bool {
        let modelIdentifier = getDeviceModelIdentifier()

        // iPod touch - NO 4K support (all models)
        if modelIdentifier.contains("iPod") {
            return false
        }

        // iPhone SE models - NO 4K support
        if modelIdentifier.contains("iPhone8,4") { return false }   // SE 1st gen (2016)
        if modelIdentifier.contains("iPhone12,8") { return false }  // SE 2nd gen (2020)
        if modelIdentifier.contains("iPhone14,6") { return false }  // SE 3rd gen (2022)

        // Older iPhones - NO 4K support (iPhone 6S through iPhone 8)
        if modelIdentifier.contains("iPhone8,1") || modelIdentifier.contains("iPhone8,2") { return false } // 6S/6S+
        if modelIdentifier.contains("iPhone9,") { return false }  // iPhone 7/7+
        if modelIdentifier.contains("iPhone10,1") || modelIdentifier.contains("iPhone10,4") { return false } // iPhone 8
        if modelIdentifier.contains("iPhone10,2") || modelIdentifier.contains("iPhone10,5") { return false } // iPhone 8 Plus

        // Older iPads - NO 4K support
        if modelIdentifier.contains("iPad5,") { return false }  // iPad Air 2, iPad mini 4
        if modelIdentifier.contains("iPad6,3") || modelIdentifier.contains("iPad6,4") { return false } // iPad Pro 9.7"

        // Modern devices support 4K (iPhone X and later, iPad Pro 2017+, newer iPads)
        return true
    }

    /// Get device model identifier (e.g., "iPhone12,1", "iPad8,1")
    private static func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? ""
            }
        }
        return identifier
    }
}

