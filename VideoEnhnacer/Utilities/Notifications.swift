import Foundation

extension Notification.Name {
    static let goHomeRequested = Notification.Name("GoHomeRequestedNotification")
    static let homeResumeGateRequested = Notification.Name("HomeResumeGateRequestedNotification")
    static let homeAdRequested = Notification.Name("HomeAdRequestedNotification")
    static let homeTabBecameActive = Notification.Name("HomeTabBecameActiveNotification")
    // Foreground resume flow
    static let appReturnedToForeground = Notification.Name("AppReturnedToForegroundNotification")
    static let resumeContentRequested = Notification.Name("ResumeContentRequestedNotification")
    static let resumeOverlayTapped = Notification.Name("ResumeOverlayTappedNotification")
    static let splashDidHide = Notification.Name("SplashDidHideNotification")
    // Ads
    static let adsManagerDidDismissAd = Notification.Name("AdsManagerDidDismissAd")
    static let adsManagerDidFailToPresent = Notification.Name("AdsManagerDidFailToPresent")
    static let adsManagerDidTimeout = Notification.Name("AdsManagerDidTimeout")
}
