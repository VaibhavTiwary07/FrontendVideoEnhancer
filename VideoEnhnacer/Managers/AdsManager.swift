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
        
        let request = Request()
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Failed to load \(adType.rawValue) ad: \(error.localizedDescription)")
                self.delegate?.adDidFailToLoad(for: adType, error: error)
                return
            }
            
            self.interstitials[adType] = ad
            ad?.fullScreenContentDelegate = self
            print("\(adType.rawValue) ad loaded successfully")
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
        
        // Check retry limit (max 2 retries)
        if retryCount > 2 {
            print("❌ Max retry attempts reached for \(adType.rawValue) ad")
            isPresenting = false
            return
        }
        
        // Avoid attempting to present while another interstitial is on screen
        if isPresenting {
            print("⏭️ Skipping present for \(adType.rawValue) — an interstitial is already presenting")
            return
        }
        
        // Enhanced view hierarchy validation
        guard viewController.view.window != nil && 
              viewController.presentedViewController == nil &&
              !viewController.isBeingDismissed &&
              !viewController.isBeingPresented else {
            print("⚠️ Cannot present \(adType.rawValue) ad - view controller not ready (window: \(viewController.view.window != nil), presented: \(viewController.presentedViewController != nil), dismissing: \(viewController.isBeingDismissed), presenting: \(viewController.isBeingPresented)). Retrying...")
            
            // Reset presenting flag since we're not actually presenting
            isPresenting = false
            
            // Retry after a longer delay to ensure view hierarchy is stable
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if let topVC = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                    let properTopVC = self.findTopViewController(from: topVC)
                    print("🔄 Retrying \(adType.rawValue) ad (attempt \(retryCount + 1)) with top VC: \(String(describing: type(of: properTopVC)))")
                    self.showInterstitialAd(for: adType, from: properTopVC, retryCount: retryCount + 1)
                }
            }
            return
        }
        
        guard let interstitial = interstitials[adType] else {
            print("\(adType.rawValue) ad not loaded")
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
                        
                        print("📊 Paid revenue for \(adType.rawValue): \(value) \(currency) | precision=\(precision)")
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
        print("📱 Presenting \(adType.rawValue) ad from \(String(describing: type(of: viewController)))")
        interstitial.present(from: viewController)
        
        // Safety timeout to reset presenting flag if ad doesn't trigger callbacks
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.isPresenting {
                print("⏰ Timeout: Resetting isPresenting flag for stuck \(adType.rawValue) ad")
                self.isPresenting = false
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
}

// MARK: - GADFullScreenContentDelegate
extension AdsManager: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Find which ad type this ad belongs to
        if let interAd = ad as? InterstitialAd,
           let adType = interstitials.first(where: { $0.value === interAd })?.key {
            print("\(adType.rawValue) ad will present")
            isPresenting = true
            delegate?.adWillPresent(for: adType)
        }
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Find which ad type this ad belongs to
        if let interAd = ad as? InterstitialAd,
           let adType = interstitials.first(where: { $0.value === interAd })?.key {
            print("\(adType.rawValue) ad dismissed")
            delegate?.adDidDismiss(for: adType)
            // Remove the used ad and reload a new one
            interstitials.removeValue(forKey: adType)
            isPresenting = false
            loadInterstitialAd(for: adType)
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        // Find which ad type this ad belongs to
        if let interAd = ad as? InterstitialAd,
           let adType = interstitials.first(where: { $0.value === interAd })?.key {
            print("\(adType.rawValue) ad failed to present: \(error.localizedDescription)")
            delegate?.adDidFailToPresent(for: adType, error: error)
            // Remove stale ad instance and attempt to reload a fresh one
            interstitials.removeValue(forKey: adType)
            isPresenting = false
            
            // If failure was due to view hierarchy issues, attempt retry with proper view controller
            if error.localizedDescription.contains("window hierarchy") {
                print("⚠️ Retrying \(adType.rawValue) ad presentation due to view hierarchy issue...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadInterstitialAd(for: adType)
                    // Retry presentation after ad loads
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let topVC = UIApplication.shared.connectedScenes
                            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                            .first {
                            self.showInterstitialAd(for: adType, from: self.findTopViewController(from: topVC))
                        }
                    }
                }
            } else {
                loadInterstitialAd(for: adType)
            }
        }
    }
}
