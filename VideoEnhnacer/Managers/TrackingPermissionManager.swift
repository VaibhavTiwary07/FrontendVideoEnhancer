//
//  TrackingPermissionManager.swift
//  VideoEnhnacer
//
//  Created by apple on 05/09/25.
//

import Foundation
import AppTrackingTransparency
import AdSupport

final class TrackingPermissionManager {
    static func requestPermission() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("Tracking authorized ✅")
                case .denied:
                    print("Tracking denied ❌")
                case .notDetermined:
                    print("Tracking not determined yet ⚠️")
                case .restricted:
                    print("Tracking restricted 🚫")
                @unknown default:
                    break
                }
            }
        } else {
            print("ATT not available on this iOS version")
        }
    }
}
