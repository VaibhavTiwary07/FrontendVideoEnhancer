import GoogleMobileAds
import UIKit
import FirebaseAnalytics
import Combine

enum AdType: String, CaseIterable {
    case launch
    case homeButtonClick
    case resumeButtonClick
}

final class AdsManager: NSObject {
    static let shared = AdsManager()
    
    private var interstitials: [AdType: InterstitialAd] = [:]
    private var isPresenting: Bool = false
    private var retryAttempts: [AdType: Int] = [:]
    private var lastAdRequestTime: [AdType: Date] = [:]
    private var lastAdPresentationTime: [AdType: Date] = [:]
    private let adCooldownInterval: TimeInterval = 30.0
    var suppressNonResumeAdPresentations: Bool = false
    private var pendingPresentationQueue: [AdType] = []
    private var isLoading: [AdType: Bool] = [:]

    // Track if resume ad is loaded and ready to present
    @Published var isResumeAdReady: Bool = false

    // ✅ New state protection variables
    private var isProcessingQueue = false
    private var activeRetryTimers: [AdType: Bool] = [:]
    private var lastQueueProcessTime: Date?
    
    private let adUnitIDs: [AdType: String] = [
        .launch: {
            #if DEBUG
            return "ca-app-pub-3940256099942544/4411468910"
            #else
            return "ca-app-pub-8572140050384873/6247483535"
            #endif
        }(),
        .homeButtonClick: {
            #if DEBUG
            return "ca-app-pub-3940256099942544/4411468910"
            #else
            return "ca-app-pub-8572140050384873/5129842982"
            #endif
        }(),
        .resumeButtonClick: {
            #if DEBUG
            return "ca-app-pub-3940256099942544/4411468910"
            #else
            return "ca-app-pub-8572140050384873/7879580666"
            #endif
        }()
    ]
    
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleSubscriptionUnlocked), name: .clearAllLocks, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSubscriptionExpired), name: .subscriptionSessionExpired, object: nil)
        
        AdType.allCases.forEach { isLoading[$0] = false }
        
        DispatchQueue.main.async { [weak self] in
            self?.preloadAllAds()
        }
    }
    
    // MARK: - Config
    
    private func shouldShowAd(for adType: AdType) -> Bool {
        let key: String
        switch adType {
        case .launch: key = "interstitial_launch"
        case .resumeButtonClick: key = "interstitial_resume"
        case .homeButtonClick: key = "interstitial_home"
        }
        let shouldShow = ConfigManager.shared.getBool(forKey: key)
        print("Remote Config check for \(adType.rawValue): \(key) = \(shouldShow)")
        return shouldShow
    }
    
    // MARK: - Subscription Handlers
    
    @objc private func handleSubscriptionUnlocked() {
        print("AdsManager: subscription active — clearing ads")
        interstitials.removeAll()
        isLoading.removeAll()
        pendingPresentationQueue.removeAll()
        AdType.allCases.forEach { isLoading[$0] = false }
    }
    
    @MainActor @objc private func handleSubscriptionExpired() {
        print("AdsManager: subscription expired — resuming ad preload")
        preloadAllAds()
    }
    
    // MARK: - Load
    
    @MainActor func loadInterstitialAd(for adType: AdType) {
        if SubscriptionManager.shared.isAppSubscribed() {
            print("Skipping load for \(adType.rawValue) — subscribed")
            return
        }
        if !shouldShowAd(for: adType) {
            print("Skipping load for \(adType.rawValue) — disabled by Remote Config")
            return
        }
        guard let adUnitID = adUnitIDs[adType] else { return }
        guard !(isLoading[adType] ?? false), interstitials[adType] == nil else { return }
        
        isLoading[adType] = true
        print("ad diagnose: load request adType=\(adType.rawValue)")
        
        let request = Request()
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoading[adType] = false
            
            if let error = error {
                print("ad diagnose: load failed \(adType.rawValue): \(error.localizedDescription)")

                // Mark resume ad as not ready on load failure
                if adType == .resumeButtonClick {
                    self.isResumeAdReady = false
                    print("DEBUG_RESUME: Resume ad failed to load, marked as not ready")
                }

                self.delegate?.adDidFailToLoad(for: adType, error: error)
                return
            }
            
            self.interstitials[adType] = ad
            ad?.fullScreenContentDelegate = self
            print("ad diagnose: loaded adType=\(adType.rawValue)")

            // Mark resume ad as ready when loaded
            if adType == .resumeButtonClick {
                self.isResumeAdReady = true
                print("DEBUG_RESUME: Resume ad loaded and ready to present")
            }

            self.delegate?.adDidLoad(for: adType)
        }
    }
    
    // MARK: - Show
    
    @MainActor func showInterstitialAd(for adType: AdType, from viewController: UIViewController, retryCount: Int = 0) {
        let now = Date()
        
        // Debounce
        if let lastRequest = lastAdRequestTime[adType], now.timeIntervalSince(lastRequest) < 1.0 {
            print("ad diagnose: debounced \(adType.rawValue)")
            return
        }
        lastAdRequestTime[adType] = now
        
        // Cooldown (except resume)
        if adType != .resumeButtonClick,
           let lastPresentation = lastAdPresentationTime[adType],
           now.timeIntervalSince(lastPresentation) < adCooldownInterval {
            print("ad diagnose: cooldown \(adType.rawValue)")
            return
        }
        
        // Subscription / Config
        if SubscriptionManager.shared.isAppSubscribed() { return }
        if !shouldShowAd(for: adType) { return }
        
        // First launch skip
        if adType == .launch && !UserDefaults.standard.bool(forKey: "HasShownFirstLaunchAd") {
            interstitials.removeValue(forKey: adType)
            isLoading[adType] = false
            return
        }
        
        // Retry limit
        if retryAttempts[adType, default: 0] >= 3 {
            print("Max retries reached \(adType.rawValue)")
            retryAttempts[adType] = 0
            isPresenting = false
            processPendingQueue()
            return
        }
        
        // Queue non-resume ads if suppressed
        if suppressNonResumeAdPresentations && adType != .resumeButtonClick {
            if !pendingPresentationQueue.contains(adType) {
                pendingPresentationQueue.append(adType)
                print("ad diagnose: queued \(adType.rawValue) (resume active)")
            }
            return
        }
        
        // If already presenting
        if isPresenting {
            if adType != .resumeButtonClick && !pendingPresentationQueue.contains(adType) {
                pendingPresentationQueue.append(adType)
                print("ad diagnose: queued \(adType.rawValue) (already presenting)")
            }
            return
        }
        
        // VC readiness
        guard viewController.view.window != nil,
              viewController.presentedViewController == nil,
              !viewController.isBeingDismissed,
              !viewController.isBeingPresented else {
            if activeRetryTimers[adType] == true { return }
            activeRetryTimers[adType] = true
            
            retryAttempts[adType, default: 0] += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                self.activeRetryTimers[adType] = false
                if let topVC = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                    let properTopVC = self.findTopViewController(from: topVC)
                    self.showInterstitialAd(for: adType, from: properTopVC, retryCount: retryCount + 1)
                }
            }
            return
        }
        
        // Ready to show
        guard let interstitial = interstitials[adType] else {
            print("ad diagnose: ad not loaded \(adType.rawValue)")
            loadInterstitialAd(for: adType)
            retryAttempts[adType, default: 0] += 1
            if activeRetryTimers[adType] == true { return }
            activeRetryTimers[adType] = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                guard let self = self else { return }
                self.activeRetryTimers[adType] = false
                if let topVC = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                    let properTopVC = self.findTopViewController(from: topVC)
                    self.showInterstitialAd(for: adType, from: properTopVC, retryCount: retryCount + 1)
                }
            }
            return
        }
        
        if isPresenting {
            print("⚠️ Double-present prevented for \(adType.rawValue)")
            return
        }
        
        // Validate frame dimensions before presenting
        let frame = viewController.view.frame
        guard frame.width > 0 && frame.height > 0 && frame.width.isFinite && frame.height.isFinite else {
            print("ad diagnose: invalid frame dimensions (w:\(frame.width), h:\(frame.height)); deferring presentation")
            // Retry after view layout completes
            if activeRetryTimers[adType] == true { return }
            activeRetryTimers[adType] = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.activeRetryTimers[adType] = false
                if let topVC = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                    let properTopVC = self.findTopViewController(from: topVC)
                    self.showInterstitialAd(for: adType, from: properTopVC, retryCount: retryCount + 1)
                }
            }
            return
        }

        // Present
        isPresenting = true
        lastAdPresentationTime[adType] = now
        print("ad diagnose: presenting \(adType.rawValue) with valid frame (w:\(frame.width), h:\(frame.height))")

        interstitial.paidEventHandler = { adValue in
            Analytics.logEvent("Ad_Impression", parameters: [
                "adunitid": self.adUnitIDs[adType] ?? "none",
                "placement": adType.rawValue,
                "network": "Admob",
                "value": adValue.value.doubleValue,
                "currency": adValue.currencyCode
            ])
        }
        interstitial.present(from: viewController)
    }
    
    // MARK: - Preload
    
    @MainActor func preloadAllAds() {
        if SubscriptionManager.shared.isAppSubscribed() {
            interstitials.removeAll()
            isLoading.removeAll()
            pendingPresentationQueue.removeAll()
            AdType.allCases.forEach { isLoading[$0] = false }
            return
        }
        
        if isLoading.values.contains(true) {
            print("Skipping preload — already loading")
            return
        }
        
        AdType.allCases.forEach { adType in
            if shouldShowAd(for: adType) {
                loadInterstitialAd(for: adType)
            } else {
                print("Skipping preload \(adType.rawValue) — disabled")
            }
        }
    }
    
    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return findTopViewController(from: presented)
        }
        if let nav = viewController as? UINavigationController {
            return findTopViewController(from: nav.visibleViewController ?? nav)
        }
        if let tab = viewController as? UITabBarController {
            return findTopViewController(from: tab.selectedViewController ?? tab)
        }
        return viewController
    }
    
    func processPendingQueue() {
        if isProcessingQueue { return }
        isProcessingQueue = true
        defer { isProcessingQueue = false }
        
        let now = Date()
        if let last = lastQueueProcessTime, now.timeIntervalSince(last) < 1.0 {
            print("Queue throttled")
            return
        }
        lastQueueProcessTime = now
        
        if isPresenting || suppressNonResumeAdPresentations { return }
        guard let next = pendingPresentationQueue.first else { return }
        pendingPresentationQueue.removeFirst()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.isPresenting || self.suppressNonResumeAdPresentations {
                self.pendingPresentationQueue.insert(next, at: 0)
                return
            }
            if !self.shouldShowAd(for: next) {
                self.processPendingQueue()
                return
            }
            if let topVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first {
                let properTopVC = self.findTopViewController(from: topVC)
                self.showInterstitialAd(for: next, from: properTopVC)
            }
        }
    }
}

// MARK: - FullScreenContentDelegate
extension AdsManager: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard let interAd = ad as? InterstitialAd,
              let adType = interstitials.first(where: { $0.value === interAd })?.key else { return }
        print("ad diagnose: will present \(adType.rawValue)")
        isPresenting = true
        delegate?.adWillPresent(for: adType)
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard let interAd = ad as? InterstitialAd,
              let adType = interstitials.first(where: { $0.value === interAd })?.key else { return }
        print("ad diagnose: dismissed \(adType.rawValue)")
        delegate?.adDidDismiss(for: adType)

        // Post notification for observers (e.g., ForegroundResumeController)
        NotificationCenter.default.post(name: .adsManagerDidDismissAd, object: adType)

        // Mark resume ad as not ready after dismissal (needs reload)
        if adType == .resumeButtonClick {
            isResumeAdReady = false
            print("DEBUG_RESUME: Resume ad dismissed, marked as not ready")
        }

        interstitials.removeValue(forKey: adType)
        isLoading[adType] = false
        retryAttempts[adType] = 0

        if shouldShowAd(for: adType) {
            loadInterstitialAd(for: adType)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isPresenting = false
            if adType == .resumeButtonClick { self.processPendingQueue() }
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        guard let interAd = ad as? InterstitialAd,
              let adType = interstitials.first(where: { $0.value === interAd })?.key else { return }
        print("ad diagnose: fail \(adType.rawValue): \(error.localizedDescription)")
        delegate?.adDidFailToPresent(for: adType, error: error)

        // Post notification for observers (e.g., ForegroundResumeController)
        NotificationCenter.default.post(name: .adsManagerDidFailToPresent, object: adType)

        // Mark resume ad as not ready on presentation failure
        if adType == .resumeButtonClick {
            isResumeAdReady = false
            print("DEBUG_RESUME: Resume ad failed to present, marked as not ready")
        }

        interstitials.removeValue(forKey: adType)
        isLoading[adType] = false
        retryAttempts[adType] = 0

        if shouldShowAd(for: adType) {
            loadInterstitialAd(for: adType)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isPresenting = false
            if adType == .resumeButtonClick { self.processPendingQueue() }
        }
    }
}

