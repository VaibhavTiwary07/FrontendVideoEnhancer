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
    }
    
    // Load interstitial ad for a specific ad type
    func loadInterstitialAd(for adType: AdType) {
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
    func showInterstitialAd(for adType: AdType, from viewController: UIViewController) {
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
        interstitial.present(from: viewController)
    }
    
    // Preload all ads for all ad types
    func preloadAllAds() {
        AdType.allCases.forEach { adType in
            loadInterstitialAd(for: adType)
        }
    }
}

// MARK: - GADFullScreenContentDelegate
extension AdsManager: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Find which ad type this ad belongs to
        if let adType = interstitials.first(where: { $0.value === ad })?.key {
            print("\(adType.rawValue) ad will present")
            delegate?.adWillPresent(for: adType)
        }
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Find which ad type this ad belongs to
        if let adType = interstitials.first(where: { $0.value === ad })?.key {
            print("\(adType.rawValue) ad dismissed")
            delegate?.adDidDismiss(for: adType)
            // Remove the used ad and reload a new one
            interstitials.removeValue(forKey: adType)
            loadInterstitialAd(for: adType)
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        // Find which ad type this ad belongs to
        if let adType = interstitials.first(where: { $0.value === ad })?.key {
            print("\(adType.rawValue) ad failed to present: \(error.localizedDescription)")
            delegate?.adDidFailToPresent(for: adType, error: error)
        }
    }
}
