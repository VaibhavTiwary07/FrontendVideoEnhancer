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

@main
struct VideoEnhnacerApp: App {
    @StateObject private var videoPlayerManager = VideoPlayerManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(videoPlayerManager)
        }
    }
}
