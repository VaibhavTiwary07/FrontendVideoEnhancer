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

@main
struct VideoEnhnacerApp: App {
    @StateObject private var videoPlayerManager = VideoPlayerManager()
    
    init() {
            // Initialize Google Mobile Ads SDK
            MobileAds.shared.start(completionHandler: nil)
            
            // Preload ads
            AdsManager.shared.preloadAllAds()
        }
    
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(videoPlayerManager)
        }
    }
}
