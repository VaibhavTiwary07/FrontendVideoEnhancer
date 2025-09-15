//
//  VideoEnhnacerApp.swift
//  VideoEnhnacer
//
//  Created by Vaibhav Tiwary on 13/08/25.
//
//  DEPLOYMENT TARGET: iOS 15.0
//  This app is fully compatible with iOS 15+ through conditional API usage.
//  Update project settings to set minimum deployment target to iOS 15.0.
//

import SwiftUI
import GoogleMobileAds
import FirebaseCore
import FirebaseCrashlytics
import FirebaseAnalytics
@main
struct VideoEnhnacerApp: App {
    
    // Custom UIApplicationDelegate adapter
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var videoPlayerManager = VideoPlayerManager()
    
    init() {
            // ✅ Initialize Firebase (Analytics + Crashlytics)
            FirebaseApp.configure()

            // Optional: verify Firebase modules are working
            Analytics.logEvent("app_launch", parameters: nil)
            // Crashlytics.crashlytics().log("VideoEnhancerApp launched")
            
            // Initialize Google Mobile Ads SDK
            MobileAds.shared.start(completionHandler: nil)
            
            // Check subscription expiry on app launch
            SubscriptionManager.shared.checkSubscriptionExpiry()
            
            // Preload ads
            AdsManager.shared.preloadAllAds()
        }
    
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(videoPlayerManager)
        }
    }
}
