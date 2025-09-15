//
//  ContentView.swift
//  VideoEnhnacer
//
//  Created by Vaibhav Tiwary on 13/08/25.
//

import SwiftUI

struct ContentView: View, AdsManager.AdsManagerDelegate {
   
    
    @EnvironmentObject var videoPlayerManager: VideoPlayerManager
    @StateObject var historyManager = HistoryManager()
    @State private var selectedTab = 0
    @State private var isSidebarExpanded = false // Start collapsed by default
    @State private var isShowingPaywall = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var didShowLaunchAd = false
    @State private var homeCarouselSegment = 0
    
    var body: some View {
        ZStack {
            // Main Content - Full Width
            VStack(spacing: 0) {
                // Content Area (header overlaid for transparent look)
                Group {
                    switch selectedTab {
                    case 0:
                        HomeView(
                            selectedCarouselSegment: $homeCarouselSegment,
                            isSidebarExpanded: $isSidebarExpanded,
                            isShowingPaywall: $isShowingPaywall
                        )
                    case 1:
                        MyCreationsView()
                    default:
                        HomeView(
                            selectedCarouselSegment: $homeCarouselSegment,
                            isSidebarExpanded: $isSidebarExpanded,
                            isShowingPaywall: $isShowingPaywall
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
                
                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
            }
            .disabled(isSidebarExpanded) // Disable interaction when sidebar is open
            
            // Backdrop Overlay
            if isSidebarExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarExpanded = false
                        }
                    }
            }
            
            // Sidebar - Only show when hamburger is clicked
            if isSidebarExpanded {
                HStack {
                    SidebarView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    
                    Spacer()
                }
            }
        }
        .background(Color.appBackground)
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: isSidebarExpanded)
        .environmentObject(historyManager)
        .fullScreenCover(isPresented: $isShowingPaywall) {
            PaywallView(isPresented: $isShowingPaywall)
        }
        // Reinitialize Home's comparison players when switching back to Home tab
        .onChange(of: selectedTab) { newTab in
            if newTab == 0 {
                print("📣 ContentView: Home tab became active → notifying Home")
                NotificationCenter.default.post(name: .homeTabBecameActive, object: nil)
            } else {
                print("📣 ContentView: Switched to non-Home tab index=\(newTab)")
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                videoPlayerManager.pauseAllPlayers()
            case .active:
                videoPlayerManager.resumeActiveViewPlayers()
            default:
                break
            }
        }
        .onAppear {
            SubscriptionManager.shared.checkSubscriptionExpiry()
            AdsManager.shared.delegate = self
            TrackingPermissionManager.requestPermission()
        }
        // Ensure switching back to Home tab when a global home request is posted
        .onReceive(NotificationCenter.default.publisher(for: .goHomeRequested)) { _ in
            selectedTab = 0
        }
        // Fallback: if HomeView misses the ad request timing, present from root
        .onReceive(NotificationCenter.default.publisher(for: .homeAdRequested)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let presenter = UIHelpers.topViewController() {
                    AdsManager.shared.showInterstitialAd(for: .homeButtonClick, from: presenter)
                } else if let rootVC = UIApplication.shared.connectedScenes
                            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                            .first {
                    AdsManager.shared.showInterstitialAd(for: .homeButtonClick, from: rootVC)
                } else {
                    print("⚠️ ContentView: No presenter available for Home ad fallback")
                }
            }
        }
    }
    
    // MARK: - AdsManagerDelegate
    func adDidLoad(for adType: AdType) {
        if adType == .launch && !didShowLaunchAd {
            didShowLaunchAd = true
            DispatchQueue.main.async {
                if let rootVC = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                        AdsManager.shared.showInterstitialAd(for: .launch, from: rootVC)
                    }
            }
        }
    }
    
    func adDidFailToLoad(for adType: AdType, error: any Error) {
        
    }
    
    func adWillPresent(for adType: AdType) {
        
    }
    
    func adDidDismiss(for adType: AdType) {
        
    }
    
    func adDidFailToPresent(for adType: AdType, error: any Error) {
        
    }
}

#Preview {
    ContentView()
}
