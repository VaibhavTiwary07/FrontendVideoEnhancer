import SwiftUI
import UIKit

final class ForegroundResumeController: ObservableObject {
    @Published var showResumeBanner: Bool = false
    private(set) var didShowResumeAdThisActivation: Bool = false
    private var lastResumeAdTimestamp: Date?
    private let resumeAdCooldown: TimeInterval = 180 // 3 minutes
    
    // Cold start + resume gating
    @Published private(set) var coldStart: Bool = true
    private var hasEverEnteredBackground: Bool = false

    private var adDismissObserver: NSObjectProtocol?
    private var adFailObserver: NSObjectProtocol?

    // Overlay window
    private var overlayWindow: UIWindow?
    private var overlayHost: UIViewController?

    deinit {
        if let ob = adDismissObserver { NotificationCenter.default.removeObserver(ob) }
        if let ob = adFailObserver { NotificationCenter.default.removeObserver(ob) }
    }
    
    init() {
        NotificationCenter.default.addObserver(forName: .splashDidHide, object: nil, queue: .main) { [weak self] _ in
            self?.coldStart = false
            print("ad diagnose: splashDidHide received; coldStart=false")
        }
    }

    func onEnterBackground() {
        // Reset per-activation guards
        didShowResumeAdThisActivation = false
        showResumeBanner = false
        hideOverlayWindow()
        print("ad diagnose: entered background; reset resume guards")
        hasEverEnteredBackground = true
    }

    func onEnterForeground() {
        // Notify observers
        NotificationCenter.default.post(name: .appReturnedToForeground, object: nil)
        // If cold start or we have not been backgrounded yet, do not show resume overlay
        guard !coldStart && hasEverEnteredBackground else {
            print("ad diagnose: foreground on cold start or no background yet; skipping resume overlay")
            return
        }
        // Show resume overlay and prepare resume ad
        showResumeBanner = true
        showOverlayWindow()
        AdsManager.shared.suppressNonResumeAdPresentations = true
        AdsManager.shared.loadInterstitialAd(for: .resumeButtonClick)
        print("ad diagnose: foreground; showing resume overlay")
    }

    func handleResumeTapped(videoPlayerManager: VideoPlayerManager) {
        // Close overlay to avoid double taps
        showResumeBanner = false
        hideOverlayWindow()
        print("ad diagnose: resume overlay tapped; will attempt resume ad present")

        // If subscribed, skip ad and resume immediately
        if SubscriptionManager.shared.isAppSubscribed() {
            resumeAll(videoPlayerManager: videoPlayerManager)
            return
        }

        // Guard one ad per activation and respect cooldown
        let now = Date()
        if didShowResumeAdThisActivation || (lastResumeAdTimestamp != nil && now.timeIntervalSince(lastResumeAdTimestamp!) < resumeAdCooldown) {
            resumeAll(videoPlayerManager: videoPlayerManager)
            return
        }

        // Observe ad dismissal or failure to resume afterwards (only handle resume ad)
        adDismissObserver = NotificationCenter.default.addObserver(forName: .adsManagerDidDismissAd, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let t = note.object as? AdType, t != .resumeButtonClick { return }
            self.cleanupAdObservers()
            self.markAdShown()
            AdsManager.shared.suppressNonResumeAdPresentations = false
            AdsManager.shared.processPendingQueue()
            // Second pass after transitions settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                AdsManager.shared.processPendingQueue()
            }
            self.resumeAll(videoPlayerManager: videoPlayerManager)
        }
        adFailObserver = NotificationCenter.default.addObserver(forName: .adsManagerDidFailToPresent, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let t = note.object as? AdType, t != .resumeButtonClick { return }
            self.cleanupAdObservers()
            AdsManager.shared.suppressNonResumeAdPresentations = false
            AdsManager.shared.processPendingQueue()
            // Second pass after transitions settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                AdsManager.shared.processPendingQueue()
            }
            self.resumeAll(videoPlayerManager: videoPlayerManager)
        }

        // Present ad after a short settle delay to let UI stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if let presenter = UIHelpers.topViewController() {
                print("ad diagnose: topVC=\(String(describing: type(of: presenter))) for ad=resumeButtonClick")
                AdsManager.shared.showInterstitialAd(for: .resumeButtonClick, from: presenter)
            } else if let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first {
                print("ad diagnose: fallback rootVC=\(String(describing: type(of: rootVC))) for ad=resumeButtonClick")
                AdsManager.shared.showInterstitialAd(for: .resumeButtonClick, from: rootVC)
            } else {
                // If no presenter, just resume content
                print("ad diagnose: no presenter available for resumeButtonClick; resuming content without ad")
                AdsManager.shared.suppressNonResumeAdPresentations = false
                AdsManager.shared.processPendingQueue()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    AdsManager.shared.processPendingQueue()
                }
                self.resumeAll(videoPlayerManager: videoPlayerManager)
            }
        }
    }

    private func resumeAll(videoPlayerManager: VideoPlayerManager) {
        // Ask views to resume their own content (e.g., trimming preview)
        NotificationCenter.default.post(name: .resumeContentRequested, object: nil)
        // Resume shared comparison players
        videoPlayerManager.resumeActiveViewPlayers()
        print("ad diagnose: content resumed after ad flow")
    }

    private func cleanupAdObservers() {
        if let ob = adDismissObserver { NotificationCenter.default.removeObserver(ob) }
        if let ob = adFailObserver { NotificationCenter.default.removeObserver(ob) }
        adDismissObserver = nil
        adFailObserver = nil
    }

    private func markAdShown() {
        didShowResumeAdThisActivation = true
        lastResumeAdTimestamp = Date()
    }

    // MARK: - Overlay Window Management
    private func showOverlayWindow() {
        guard overlayWindow == nil else { return }
        guard let scene = UIHelpers.keyWindow()?.windowScene else { return }

        let window = UIWindow(windowScene: scene)
        window.backgroundColor = .clear
        window.windowLevel = UIWindow.Level.statusBar + 1
        let host = UIHostingController(rootView: ResumeOverlayView(onResume: {
            // Signal SwiftUI layer (ContentView) to handle ad+resume via controller
            NotificationCenter.default.post(name: .resumeOverlayTapped, object: nil)
        }))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        overlayWindow = window
        overlayHost = host
        print("ad diagnose: overlay window shown")
    }

    private func hideOverlayWindow() {
        overlayHost = nil
        if let window = overlayWindow {
            window.isHidden = true
        }
        overlayWindow = nil
        print("ad diagnose: overlay window hidden")
    }
}
