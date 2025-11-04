import SwiftUI
import UIKit
import Combine

final class ForegroundResumeController: ObservableObject {
    @Published var showResumeBanner: Bool = false

    // Cold start + resume gating
    @Published private(set) var coldStart: Bool = true
    private var hasEverEnteredBackground: Bool = false

    private var adDismissObserver: NSObjectProtocol?
    private var adFailObserver: NSObjectProtocol?
    private var adTimeoutObserver: NSObjectProtocol?

    // Prevent multiple simultaneous ad requests
    private var isResumeAdInProgress: Bool = false

    // Safety timer to prevent permanent stuck state
    private var adSafetyTimer: Timer?

    // Overlay window
    private var overlayWindow: UIWindow?
    private var overlayHost: UIViewController?

    // Combine cancellable for observing ad ready state
    private var adReadyCancellable: AnyCancellable?
    private var isPendingResumeOverlay: Bool = false

    deinit {
        cleanupAdObservers()
    }
    
    init() {
        NotificationCenter.default.addObserver(forName: .splashDidHide, object: nil, queue: .main) { [weak self] _ in
            self?.coldStart = false
            print("ad diagnose: splashDidHide received; coldStart=false")
        }
    }

    func onEnterBackground() {
        // Reset state
        showResumeBanner = false
        hideOverlayWindow()
        print("DEBUG_RESUME: entered background; reset resume guards")
        hasEverEnteredBackground = true

        // Reset ad state
        isResumeAdInProgress = false
        isPendingResumeOverlay = false
        adReadyCancellable?.cancel()
        cleanupAdObservers()
    }

    @MainActor func onEnterForeground() {
        // Notify observers
        NotificationCenter.default.post(name: .appReturnedToForeground, object: nil)

        // If cold start or we have not been backgrounded yet, do not show resume overlay
        guard !coldStart && hasEverEnteredBackground else {
            print("DEBUG_RESUME: foreground on cold start or no background yet; skipping resume overlay")
            return
        }

        AdsManager.shared.suppressNonResumeAdPresentations = true

        // Check if resume ad is already loaded and ready
        if AdsManager.shared.isResumeAdReady {
            print("DEBUG_RESUME: Resume ad already ready, showing overlay immediately")
            showResumeBanner = true
            showOverlayWindow()
        } else {
            print("DEBUG_RESUME: Resume ad not ready, waiting for it to load...")
            isPendingResumeOverlay = true

            // Load the ad if not already loading
            AdsManager.shared.loadInterstitialAd(for: .resumeButtonClick)

            // Observe ad ready state - show overlay when ready
            adReadyCancellable = AdsManager.shared.$isResumeAdReady
                .sink { [weak self] isReady in
                    guard let self = self else { return }
                    if isReady && self.isPendingResumeOverlay {
                        print("DEBUG_RESUME: Resume ad became ready, showing overlay now")
                        Task { @MainActor in
                            self.showResumeBanner = true
                            self.showOverlayWindow()
                            self.isPendingResumeOverlay = false
                            self.adReadyCancellable?.cancel()
                        }
                    }
                }
        }
    }

    @MainActor func handleResumeTapped(videoPlayerManager: VideoPlayerManager) {
        // Prevent multiple simultaneous ad requests
        guard !isResumeAdInProgress else {
            print("ad diagnose: resume ad already in progress, ignoring tap")
            return
        }
        
        // Close overlay to avoid double taps
        showResumeBanner = false
        hideOverlayWindow()
        print("ad diagnose: resume overlay tapped; will attempt resume ad present")

        // If subscribed, skip ad and resume immediately
        if SubscriptionManager.shared.isAppSubscribed() {
            print("DEBUG_RESUME: user subscribed, skipping ad")
            resumeAll(videoPlayerManager: videoPlayerManager)
            return
        }

        // Safety check: Ensure ad is actually ready before trying to present
        guard AdsManager.shared.isResumeAdReady else {
            print("DEBUG_RESUME: ⚠️ Ad not ready when resume button tapped! Resuming without ad.")
            resumeAll(videoPlayerManager: videoPlayerManager)
            return
        }

        // MARK AD IN PROGRESS
        isResumeAdInProgress = true
        print("DEBUG_RESUME: proceeding with resume ad presentation")

        // Start safety timer (30s timeout)
        startAdSafetyTimer(videoPlayerManager: videoPlayerManager)

        // Clean up any existing observers first
        cleanupAdObservers()

        // Observe ad dismissal or failure to resume afterwards (only handle resume ad)
        adDismissObserver = NotificationCenter.default.addObserver(forName: .adsManagerDidDismissAd, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let t = note.object as? AdType, t != .resumeButtonClick { return }
            print("ad diagnose: resume ad dismissed")
            self.cancelAdSafetyTimer()
            self.cleanupAdObservers()
            AdsManager.shared.suppressNonResumeAdPresentations = false
            AdsManager.shared.processPendingQueue()
            // Second pass after transitions settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                AdsManager.shared.processPendingQueue()
            }
            self.isResumeAdInProgress = false // RESET FLAG
            self.resumeAll(videoPlayerManager: videoPlayerManager)
        }
        
        adFailObserver = NotificationCenter.default.addObserver(forName: .adsManagerDidFailToPresent, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let t = note.object as? AdType, t != .resumeButtonClick { return }
            print("ad diagnose: resume ad failed to present")
            self.cancelAdSafetyTimer()
            self.cleanupAdObservers()
            AdsManager.shared.suppressNonResumeAdPresentations = false
            AdsManager.shared.processPendingQueue()
            // Second pass after transitions settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                AdsManager.shared.processPendingQueue()
            }
            self.isResumeAdInProgress = false // RESET FLAG
            self.resumeAll(videoPlayerManager: videoPlayerManager)
        }
        
        // Timeout fallback: treat like a fail → release and resume
        adTimeoutObserver = NotificationCenter.default.addObserver(forName: .adsManagerDidTimeout, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let t = note.object as? AdType, t != .resumeButtonClick { return }
            print("ad diagnose: resume ad timeout")
            self.cancelAdSafetyTimer()
            self.cleanupAdObservers()
            AdsManager.shared.suppressNonResumeAdPresentations = false
            AdsManager.shared.processPendingQueue()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                AdsManager.shared.processPendingQueue()
            }
            self.isResumeAdInProgress = false // RESET FLAG
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
                self.cancelAdSafetyTimer()
                AdsManager.shared.suppressNonResumeAdPresentations = false
                AdsManager.shared.processPendingQueue()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    AdsManager.shared.processPendingQueue()
                }
                self.isResumeAdInProgress = false // RESET FLAG
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
        cancelAdSafetyTimer()
        if let ob = adDismissObserver {
            NotificationCenter.default.removeObserver(ob)
            adDismissObserver = nil
        }
        if let ob = adFailObserver {
            NotificationCenter.default.removeObserver(ob)
            adFailObserver = nil
        }
        if let ob = adTimeoutObserver {
            NotificationCenter.default.removeObserver(ob)
            adTimeoutObserver = nil
        }
    }

    // MARK: - Safety Timer

    private func startAdSafetyTimer(videoPlayerManager: VideoPlayerManager) {
        cancelAdSafetyTimer() // Cancel any existing timer
        adSafetyTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("⚠️ ad diagnose: safety timer fired - force resetting isResumeAdInProgress")
            self.isResumeAdInProgress = false
            self.cleanupAdObservers()
            AdsManager.shared.suppressNonResumeAdPresentations = false
            AdsManager.shared.processPendingQueue()
            self.resumeAll(videoPlayerManager: videoPlayerManager)
        }
    }

    private func cancelAdSafetyTimer() {
        adSafetyTimer?.invalidate()
        adSafetyTimer = nil
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
