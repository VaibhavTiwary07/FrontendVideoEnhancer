import SwiftUI
import UserMessagingPlatform
import AppTrackingTransparency

struct ContentView: View, AdsManager.AdsManagerDelegate {
    @EnvironmentObject var videoPlayerManager: VideoPlayerManager
    @EnvironmentObject var resumeController: ForegroundResumeController
    @StateObject var historyManager = HistoryManager()
    @State private var selectedTab = 0
    @State private var isSidebarExpanded = false
    @State private var isShowingPaywall = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var homeCarouselSegment = 0
    @State private var adShowingValue: Int = 0
    @State private var adsTrackingCountNumber: Int = 0
    @State private var hasInitializedAds = false // Flag for one-time ad initialization

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
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
                
                CustomTabBar(selectedTab: $selectedTab)
            }
            .disabled(isSidebarExpanded)
            
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
                resumeController.onEnterBackground()
                prepareForNextLaunchAd()
            case .active:
                resumeController.onEnterForeground()
                updateAdShowingValue()
                if hasInitializedAds {
                    checkAndShowLaunchAd()
                }
            default:
                break
            }
        }
        .onAppear {
            SubscriptionManager.shared.checkSubscriptionExpiry()
            checkFirstLaunch()
            trackAppLaunch()
        }
        .task {
            guard !hasInitializedAds else { return }
            hasInitializedAds = true
            AdsManager.shared.delegate = self
            await handlePrivacyConsentFlow()
            preloadAds()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goHomeRequested)) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .resumeOverlayTapped)) { _ in
            print("ad diagnose: ContentView received resumeOverlayTapped; delegating to resumeController")
            resumeController.handleResumeTapped(videoPlayerManager: videoPlayerManager)
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .splashDidHide)) { _ in
            print("ad diagnose: splashDidHide received; coldStart=\(!UserDefaults.standard.bool(forKey: "isFirstLaunch"))")
            updateAdShowingValue()
            checkAndShowLaunchAd()
        }
    }
    
    private func checkFirstLaunch() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "isFirstLaunch")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "isFirstLaunch")
            UserDefaults.standard.set(false, forKey: "HasShownFirstLaunchAd") // Ensure launch ad is skipped
            UserDefaults.standard.set(0, forKey: "AdCanShow")
            print("🚀 First launch detected, setting AdCanShow to 0, HasShownFirstLaunchAd to false")
        } else {
            print("🔄 Not first launch, checking AdCanShow")
        }
    }
    
    private func trackAppLaunch() {
        var launchCount = UserDefaults.standard.integer(forKey: "AppLaunchCount")
        launchCount += 1
        UserDefaults.standard.set(launchCount, forKey: "AppLaunchCount")
        print("📊 Current launch count: \(launchCount)")
        
        if launchCount >= 2 {
            adShowingValue = 1
            UserDefaults.standard.set(1, forKey: "AdCanShow")
            UserDefaults.standard.set(true, forKey: "HasShownFirstLaunchAd")
            print("✅ Ad will show - launch count: \(launchCount)")
        } else {
            adShowingValue = 0
            UserDefaults.standard.set(0, forKey: "AdCanShow")
            UserDefaults.standard.set(false, forKey: "HasShownFirstLaunchAd")
            print("🚫 First launch - no ad")
        }
        UserDefaults.standard.synchronize()
    }
    
    private func prepareForNextLaunchAd() {
        print("🔚 App closing - preparing for next launch")
        let launchCount = UserDefaults.standard.integer(forKey: "AppLaunchCount")
        print("📊 Next launch count will be: \(launchCount + 1)")
        if launchCount >= 1 {
            UserDefaults.standard.set(1, forKey: "AdCanShow")
            UserDefaults.standard.set(true, forKey: "HasShownFirstLaunchAd")
            print("✅ Set AdCanShow to 1, HasShownFirstLaunchAd to true for next launch")
        }
        UserDefaults.standard.synchronize()
    }
    
    private func updateAdShowingValue() {
        adShowingValue = UserDefaults.standard.integer(forKey: "AdCanShow")
        print("📊 Updated adShowingValue: \(adShowingValue)")
        gettingGdprTrackingCount()
    }
    
    private func gettingGdprTrackingCount() {
        let trackingCount = UserDefaults.standard.integer(forKey: "GDPR-ATT-ADS")
        adsTrackingCountNumber = trackingCount
        print("📊 GDPR-ATT-ADS count: \(adsTrackingCountNumber)")
    }
    
    private func preloadAds() {
        print("📢 Preloading ads")
        AdsManager.shared.preloadAllAds()
    }
    
    private func checkAndShowLaunchAd() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "isFirstLaunch")
        guard !isFirstLaunch else {
            print("🚫 Skipping launch ad: First launch")
            return
        }
        
        guard adShowingValue > 0 else {
            print("🚫 Skipping launch ad: adShowingValue=\(adShowingValue)")
            return
        }
        
        guard adsTrackingCountNumber > 0 else {
            print("🚫 Skipping launch ad: adsTrackingCountNumber=\(adsTrackingCountNumber)")
            return
        }
        
        let isSubscribed = SubscriptionManager.shared.isAppSubscribed()
        guard !isSubscribed else {
            print("🚫 Skipping launch ad: Premium user")
            return
        }
        
        guard UserDefaults.standard.bool(forKey: "HasShownFirstLaunchAd") else {
            print("🚫 Skipping launch ad: HasShownFirstLaunchAd=false")
            return
        }
        
        print("📢 Attempting to show launch ad")
        if let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first {
            print("✅ Found root view controller, showing launch ad")
            AdsManager.shared.showInterstitialAd(for: .launch, from: rootVC)
        } else {
            print("⚠️ ContentView: No root view controller for launch ad")
        }
    }
    
    private func handlePrivacyConsentFlow() async {
        let hasCompletedGDPR = UserDefaults.standard.bool(forKey: "HasCompletedGDPR")
        if hasCompletedGDPR {
            print("✅ GDPR consent already completed, requesting ATT")
            requestIDFA()
            return
        }
        
        let parameters = RequestParameters()
        #if DEBUG
        let debugSettings = DebugSettings()
        if let deviceIdentifier = UIDevice.current.identifierForVendor?.uuidString {
            debugSettings.testDeviceIdentifiers = [deviceIdentifier]
            debugSettings.geography = .EEA
            print("🌍 Debug: Forcing EEA geography, Test Device ID: \(deviceIdentifier)")
        }
        parameters.debugSettings = debugSettings
        #endif
        parameters.isTaggedForUnderAgeOfConsent = false
        
        do {
            print("🔍 Requesting consent info update")
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            
            let status = ConsentInformation.shared.consentStatus
            print("📊 Consent status: \(status.rawValue)")
            
            if status == .required {
                print("👤 Consent required - loading and presenting form")
                if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                    try await ConsentForm.loadAndPresentIfRequired(from: rootViewController)
                    print("✅ Consent form presented successfully")
                    UserDefaults.standard.set(true, forKey: "HasCompletedGDPR")
                } else {
                    print("❌ No root view controller found for consent form presentation")
                }
            } else {
                print("➡️ Consent not required")
                UserDefaults.standard.set(true, forKey: "HasCompletedGDPR")
            }
            
            print("🔍 Requesting ATT permission")
            requestIDFA()
        } catch {
            print("❌ Consent flow failed: \(error.localizedDescription)")
            UserDefaults.standard.set(true, forKey: "HasCompletedGDPR")
            requestIDFA()
        }
    }
    
    private func requestIDFA() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("✅ Ads Access Given")
                    UserDefaults.standard.set(1, forKey: "GDPR-ATT-ADS")
                    adsTrackingCountNumber = 1
                case .denied, .restricted, .notDetermined:
                    print("🚫 Ads Access Denied/Not Determined/Restricted")
                    UserDefaults.standard.set(0, forKey: "GDPR-ATT-ADS")
                    adsTrackingCountNumber = 0
                @unknown default:
                    print("⚠️ Unknown authorization status")
                    UserDefaults.standard.set(0, forKey: "GDPR-ATT-ADS")
                    adsTrackingCountNumber = 0
                }
                UserDefaults.standard.synchronize()
                gettingGdprTrackingCount()
                preloadAds()
            }
        } else {
            print("✅ iOS < 14, assuming tracking allowed")
            UserDefaults.standard.set(1, forKey: "GDPR-ATT-ADS")
            adsTrackingCountNumber = 1
            UserDefaults.standard.synchronize()
            gettingGdprTrackingCount()
            preloadAds()
        }
    }
    
    // MARK: - AdsManagerDelegate
    func adDidLoad(for adType: AdType) {
        print("📢 Ad loaded for \(adType)")
        if adType == .launch {
            checkAndShowLaunchAd()
        }
    }
    
    func adDidFailToLoad(for adType: AdType, error: Error) {
        print("⚠️ Ad failed to load for \(adType): \(error.localizedDescription)")
    }
    
    func adWillPresent(for adType: AdType) {
        print("📢 Ad will present for \(adType)")
    }
    
    func adDidDismiss(for adType: AdType) {
        print("✅ Ad dismissed for \(adType)")
        if adType == .launch {
            AdsManager.shared.loadInterstitialAd(for: .launch)
        }
    }
    
    func adDidFailToPresent(for adType: AdType, error: Error) {
        print("❌ Ad failed to present for \(adType): \(error.localizedDescription)")
    }
}

#Preview {
    ContentView()
        .environmentObject(VideoPlayerManager())
        .environmentObject(ForegroundResumeController())
        .environmentObject(HistoryManager())
}
