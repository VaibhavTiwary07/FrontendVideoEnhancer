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
import FirebaseRemoteConfig

@main
struct VideoEnhnacerApp: App {
    
    // Custom UIApplicationDelegate adapter
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var videoPlayerManager = VideoPlayerManager()
    @StateObject private var resumeController = ForegroundResumeController()
    
    @StateObject private var configState = ConfigState()
    
    init() {
            // Check and set the new UserDefaults key for launch ad control
            let isFirstLaunch = !UserDefaults.standard.bool(forKey: "HasShownFirstLaunchAd")
            if isFirstLaunch {
                print("🚀 App init: First launch detected, setting HasShownFirstLaunchAd to skip launch ad")
                UserDefaults.standard.set(true, forKey: "HasShownFirstLaunchAd")
            }
        
            // ✅ Initialize Firebase (Analytics + Crashlytics)
            FirebaseApp.configure()

            fetchRemoteConfig() // Start fetching remote config
        
            // Optional: verify Firebase modules are working
            Analytics.logEvent("app_launch", parameters: nil)
            // Crashlytics.crashlytics().log("VideoEnhancerApp launched")
            
            // Initialize Google Mobile Ads SDK
            MobileAds.shared.start(completionHandler: nil)
            
        
            // Pre-fetch products when the app launches
            SubscriptionManager.shared.fetchProducts { products, error in
                if let error = error {
                    print("Failed to pre-fetch products: \(error.localizedDescription)")
                } else if let products = products {
                    print("Pre-fetched \(products.count) products")
                }
            }
        
            // Check subscription expiry on app launch
            SubscriptionManager.shared.checkSubscriptionExpiry()
            
            // Preload ads
            AdsManager.shared.preloadAllAds()
        }
    
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(videoPlayerManager)
                .environmentObject(resumeController)
                .statusBar(hidden: true)
        }
    }
    
    private func fetchRemoteConfig() {
            print("Initiating config fetch in App...")
            ConfigManager.shared.initialize { error in
                if let error = error {
                    print("Failed to fetch remote config: \(error.localizedDescription)")
                } else {
                    print("Remote config fetched successfully")
                    ConfigManager.shared.printConfigValues()
                }
                configState.isConfigLoaded = true
            }
        }
}

class ConfigState: ObservableObject {
    @Published var isConfigLoaded: Bool = false
}
