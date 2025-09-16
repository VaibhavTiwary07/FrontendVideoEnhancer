//
//  AdsManager.swift
//  VideoEnhancementApp
//
//  Created by apple on 03/09/25.
//

import GoogleMobileAds
import UIKit
import FirebaseAnalytics

// Enum to represent different ad types
enum AdType: String, CaseIterable {
    case launch
    case homeButtonClick
    case resumeButtonClick
}

// AdsManager class to handle loading and showing interstitial ads for different events
final class AdsManager: NSObject {
    // Singleton instance for easy access
    static let shared = AdsManager()
    
    // Dictionary to store interstitial ads by ad type
    private var interstitials: [AdType: InterstitialAd] = [:]
    
    // Prevent concurrent presentations and double-present races
    private(set) var isPresenting: Bool = false
    
    // Track retry attempts to prevent infinite loops
    private var retryAttempts: [AdType: Int] = [:]
    
    // Suppress non-resume ad presentations during resume flow
    var suppressNonResumeAdPresentations: Bool = false
    
    // Queue for pending ad presentation intents when suppressed or busy (deduped)
    private var pendingPresentationQueue: [AdType] = []
    
    // Ad Unit IDs (Replace with your actual AdMob Interstitial Ad Unit IDs)
    private let adUnitIDs: [AdType: String] = [
        .launch: "ca-app-pub-8572140050384873/6247483535", // Test ID for launch
        .homeButtonClick: "ca-app-pub-8572140050384873/5129842982", // Test ID for home button
        .resumeButtonClick: "ca-app-pub-8572140050384873/7879580666" // Test ID for resume button
    ]
    
    // Delegate protocol for ad events
    protocol AdsManagerDelegate {
        func adDidLoad(for adType: AdType)
        func adDidFailToLoad(for adType: AdType, error: Error)
        func adWillPresent(for adType: AdType)
        func adDidDismiss(for adType: AdType)
        func adDidFailToPresent(for adType: AdType, error: Error)
    }
    
    var delegate: AdsManagerDelegate?
    
    private override init() {
        super.init()
        // Observe subscription changes to manage ad lifecycle
        NotificationCenter.default.addObserver(self, selector: #selector(handleSubscriptionUnlocked), name: .clearAllLocks, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSubscriptionExpired), name: .subscriptionSessionExpired, object: nil)
    }

    @objc private func handleSubscriptionUnlocked() {
        print("🔕 AdsManager: subscription active — clearing ads and disabling preload")
        interstitials.removeAll()
    }
    
    @objc private func handleSubscriptionExpired() {
        print("🔔 AdsManager: subscription expired — resuming ad preload")
        preloadAllAds()
    }
    
    // Load interstitial ad for a specific ad type
    func loadInterstitialAd(for adType: AdType) {
        // Do not load ads if user is subscribed
        if SubscriptionManager.shared.isAppSubscribed() {
            print("🔕 Skipping load for \(adType.rawValue) — user is subscribed")
            return
        }
        guard let adUnitID = adUnitIDs[adType] else {
            print("No Ad Unit ID found for \(adType.rawValue)")
            return
        }
        print("ad diagnose: load request adType=\(adType.rawValue) adUnitID=\(adUnitID)")
        
        let request = Request()
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            
            if let error = error {
                print("ad diagnose: load failed adType=\(adType.rawValue) adUnitID=\(adUnitID) error=\(error.localizedDescription)")
                self.delegate?.adDidFailToLoad(for: adType, error: error)
                return
            }
            
            self.interstitials[adType] = ad
            ad?.fullScreenContentDelegate = self
            print("ad diagnose: loaded adType=\(adType.rawValue) adUnitID=\(adUnitID)")
            self.delegate?.adDidLoad(for: adType)
        }
    }
    
    // Show interstitial ad for a specific ad type
    func showInterstitialAd(for adType: AdType, from viewController: UIViewController, retryCount: Int = 0) {
        // Do not show ads if user is subscribed
        if SubscriptionManager.shared.isAppSubscribed() {
            print("🔕 Suppressing interstitial for \(adType.rawValue) — user is subscribed")
            return
        }
        // Gate other ad types while resume flow is active
        if suppressNonResumeAdPresentations && adType != .resumeButtonClick {
            if !pendingPresentationQueue.contains(adType) {
                pendingPresentationQueue.append(adType)
            }
            print("ad diagnose: deferred present adType=\(adType.rawValue) due to active resume flow (enqueued)")
            return
        }
        
        // Check retry limit (max 2 retries)
        if retryCount > 2 {
            print("❌ Max retry attempts reached for \(adType.rawValue) ad")
            isPresenting = false
            return
        }
        
        // Avoid attempting to present while another interstitial is on screen
        if isPresenting {
            // Defer lower-priority requests if a presentation is underway
            if adType != .resumeButtonClick && !pendingPresentationQueue.contains(adType) {
                pendingPresentationQueue.append(adType)
                print("ad diagnose: deferred present adType=\(adType.rawValue) because another ad is presenting (enqueued)")
            } else {
                print("ad diagnose: present skipped — already presenting adType=\(adType.rawValue)")
            }
            return
        }
        
        // Enhanced view hierarchy validation
        guard viewController.view.window != nil && 
              viewController.presentedViewController == nil &&
              !viewController.isBeingDismissed &&
              !viewController.isBeingPresented else {
            print("ad diagnose: vc not ready adType=\(adType.rawValue) window=\(viewController.view.window != nil) presented=\(viewController.presentedViewController != nil) dismissing=\(viewController.isBeingDismissed) presenting=\(viewController.isBeingPresented) retry=\(retryCount+1)")
            
            // Reset presenting flag since we're not actually presenting
            isPresenting = false
            
            // Retry after a longer delay to ensure view hierarchy is stable
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if let topVC = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                    let properTopVC = self.findTopViewController(from: topVC)
                    print("ad diagnose: retry present adType=\(adType.rawValue) attempt=\(retryCount+1) topVC=\(String(describing: type(of: properTopVC)))")
                    self.showInterstitialAd(for: adType, from: properTopVC, retryCount: retryCount + 1)
                }
            }
            return
        }
        
        guard let interstitial = interstitials[adType] else {
            if let unit = adUnitIDs[adType] { print("ad diagnose: not loaded adType=\(adType.rawValue) adUnitID=\(unit) — loading & retry") }
            else { print("ad diagnose: not loaded adType=\(adType.rawValue) — no adUnitID") }
            loadInterstitialAd(for: adType)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                if let topVC = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                    let properTopVC = self.findTopViewController(from: topVC)
                    print("ad diagnose: retry after load adType=\(adType.rawValue) topVC=\(String(describing: type(of: properTopVC)))")
                    self.showInterstitialAd(for: adType, from: properTopVC, retryCount: retryCount + 1)
                }
            }
            return
        }
        guard let adUnitID = adUnitIDs[adType] else {
            print("No Ad Unit ID found for \(adType.rawValue)")
            return
        }
        // 🔹 Paid event handler (revenue event)
        interstitial.paidEventHandler = { adValue in
                        let value = adValue.value.doubleValue
                        let currency = adValue.currencyCode
                        let precision = adValue.precision.rawValue
                        
                        print("ad diagnose: paid event adType=\(adType.rawValue) adUnitID=\(adUnitID) value=\(value) currency=\(currency) precision=\(precision)")
                        // Log as single consolidated event
                        Analytics.logEvent("Ad_Impression", parameters: [
                            "adunitid": adUnitID,
                            "placement": adType.rawValue,
                            "network": "Admob",
                            "value": value,
                            "currency": currency,
                            "shown": true, // always true when paid event arrives
                            "precision": precision
                        ])
                    }
        // Set guard prior to present to prevent near-simultaneous duplicate presents
        isPresenting = true
        print("ad diagnose: presenting adType=\(adType.rawValue) adUnitID=\(adUnitID) from=\(String(describing: type(of: viewController)))")
        interstitial.present(from: viewController)
        
        // Safety timeout to reset presenting flag if ad doesn't trigger callbacks
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.isPresenting {
                print("ad diagnose: timeout reset isPresenting adType=\(adType.rawValue)")
                // Release presentation lock and clean stale interstitial
                self.isPresenting = false
                // Remove stale ad and trigger a reload for future attempts
                self.interstitials.removeValue(forKey: adType)
                self.loadInterstitialAd(for: adType)
                // Notify listeners about timeout for targeted recovery flows
                NotificationCenter.default.post(name: .adsManagerDidTimeout, object: adType)
                // If resume flow timed out, unblock and drain queued intents
                if adType == .resumeButtonClick {
                    self.suppressNonResumeAdPresentations = false
                    self.processPendingQueue()
                    // Second pass after transitions settle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.processPendingQueue()
                    }
                }
            }
        }
    }
    
    // Preload all ads for all ad types
    func preloadAllAds() {
        // Do not preload ads if user is subscribed
        if SubscriptionManager.shared.isAppSubscribed() {
            print("🔕 Skipping preload — user is subscribed")
            interstitials.removeAll()
            return
        }
        AdType.allCases.forEach { adType in
            loadInterstitialAd(for: adType)
        }
    }
    
    // Helper method to find the topmost view controller
    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presentedViewController = viewController.presentedViewController {
            return findTopViewController(from: presentedViewController)
        }
        if let navigationController = viewController as? UINavigationController {
            return findTopViewController(from: navigationController.visibleViewController ?? navigationController)
        }
        if let tabBarController = viewController as? UITabBarController {
            return findTopViewController(from: tabBarController.selectedViewController ?? tabBarController)
        }
        return viewController
    }
    
    // Drain any pending presentations (e.g., after resume flow completes)
    func processPendingQueue() {
        // Nothing to do if blocked or empty
        if isPresenting || suppressNonResumeAdPresentations { return }
        guard let next = pendingPresentationQueue.first else { return }

        // Try after a short grace delay to avoid transition collisions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.isPresenting || self.suppressNonResumeAdPresentations {
                // Retry later if still blocked
                self.processPendingQueue()
                return
            }

            // Verify we still have the same next intent
            guard !self.pendingPresentationQueue.isEmpty else { return }
            let intent = self.pendingPresentationQueue.removeFirst()

            if let topVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first {
                let properTopVC = self.findTopViewController(from: topVC)
                self.showInterstitialAd(for: intent, from: properTopVC)
            } else if let presenter = UIHelpers.topViewController() {
                self.showInterstitialAd(for: intent, from: presenter)
            } else {
                // If no presenter now, push back and retry soon
                self.pendingPresentationQueue.insert(intent, at: 0)
                self.processPendingQueue()
            }
        }
    }
}

// MARK: - GADFullScreenContentDelegate
extension AdsManager: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Find which ad type this ad belongs to
        if let interAd = ad as? InterstitialAd,
           let adType = interstitials.first(where: { $0.value === interAd })?.key {
            print("ad diagnose: will present adType=\(adType.rawValue)")
            isPresenting = true
            delegate?.adWillPresent(for: adType)
        }
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Find which ad type this ad belongs to
        if let interAd = ad as? InterstitialAd,
           let adType = interstitials.first(where: { $0.value === interAd })?.key {
            print("ad diagnose: dismissed adType=\(adType.rawValue)")
            delegate?.adDidDismiss(for: adType)
            NotificationCenter.default.post(name: .adsManagerDidDismissAd, object: adType)
            // Remove the used ad and reload a new one
            interstitials.removeValue(forKey: adType)
            isPresenting = false
            loadInterstitialAd(for: adType)
            // If we just finished the resume flow, allow queued intents to proceed
            if adType == .resumeButtonClick { self.processPendingQueue() }
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        // Find which ad type this ad belongs to
        if let interAd = ad as? InterstitialAd,
           let adType = interstitials.first(where: { $0.value === interAd })?.key {
            print("ad diagnose: fail to present adType=\(adType.rawValue) error=\(error.localizedDescription)")
            delegate?.adDidFailToPresent(for: adType, error: error)
            // Remove stale ad instance and attempt to reload a fresh one
            interstitials.removeValue(forKey: adType)
            isPresenting = false
            
            // If failure was due to view hierarchy issues, attempt retry with proper view controller
            if error.localizedDescription.contains("window hierarchy") {
                print("ad diagnose: retry due to window hierarchy adType=\(adType.rawValue)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadInterstitialAd(for: adType)
                    // Retry presentation after ad loads
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let topVC = UIApplication.shared.connectedScenes
                            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                            .first {
                            let vc = self.findTopViewController(from: topVC)
                            print("ad diagnose: retry after fail adType=\(adType.rawValue) topVC=\(String(describing: type(of: vc)))")
                            self.showInterstitialAd(for: adType, from: vc)
                        }
                    }
                }
            } else {
                loadInterstitialAd(for: adType)
            }
            NotificationCenter.default.post(name: .adsManagerDidFailToPresent, object: adType, userInfo: ["error": error.localizedDescription])
            // If resume failed to present, unblock and try any queued intents
            if adType == .resumeButtonClick { self.processPendingQueue() }
        }
    }
}
