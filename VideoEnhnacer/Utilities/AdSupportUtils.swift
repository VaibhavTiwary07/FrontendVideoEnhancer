import Foundation
import StoreKit

enum AdSupportUtils {
    /// Detect SKAdNetwork version based on iOS availability
    static func getSkAdNetworkVersion() -> String {
        if #available(iOS 16.1, *) {
            return "SKAdNetwork v4.0+"
        } else if #available(iOS 15.4, *) {
            return "SKAdNetwork v3.0"
        } else if #available(iOS 14.6, *) {
            return "SKAdNetwork v2.2"
        } else if #available(iOS 14.0, *) {
            return "SKAdNetwork v2.0"
        } else {
            return "Not Supported"
        }
    }
}

