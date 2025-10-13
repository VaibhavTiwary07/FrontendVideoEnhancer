import StoreKit
import Foundation
import UIKit
import FirebaseAnalytics
import SwiftUI // Added for ObservableObject

// MARK: - Constants
private let kSandboxServer = "https://sandbox.itunes.apple.com/verifyReceipt"
private let kLiveServer = "https://buy.itunes.apple.com/verifyReceipt"
private let kSharedSecret = "ade2d6379685442791c145ee48adeadd" // Replace with your actual shared secret

// MARK: - Notification Names
extension NSNotification.Name {
    static let productsFetched = Notification.Name("productsFetched")
    static let productsFetchFailed = Notification.Name("productsFetchFailed")
    static let closeSubscriptionView = Notification.Name("CloseSubscriptionView")
    static let hideActivityIndicator = Notification.Name("HideActivityIndicator")
    static let purchaseSuccessful = Notification.Name("PurchaseSuccessful")
    static let restoreFailed = Notification.Name("RestoreFailed")
    static let restoreSuccessful = Notification.Name("RestoreSuccessful")
    static let subscriptionSessionExpired = Notification.Name("SubscriptionSessionExpired")
    static let clearAllLocks = Notification.Name("ClearAllLocksHere")
}

// MARK: - Subscription Product IDs
private let subscriptionProductIDs: Set<String> = [
    "com.outthinking.videoupscaler.enhancer.weekly",
    "com.outthinking.videoupscaler.enhancer.monthly",
    "com.outthinking.videoupscaler.enhancer.yearly"
]

// MARK: - Default Values
private let defaultWatermarkPackPrice = "9.99"
private let defaultYearlyPackPrice = "29.99"
private let defaultWatermarkPackTitle = "Premium Subscription"
private let defaultWatermarkPackDescription = "Unlock all premium features"

// MARK: - SubscriptionManager
@MainActor // Ensure UI-related updates are on main thread
class SubscriptionManager: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate, ObservableObject {
    
    // MARK: - Singleton
    static let shared = SubscriptionManager()
    // Add a flag to track StoreKit operations
        private var isStoreKitOperationInProgress: Bool = false
    
    // MARK: - Observable Property for SwiftUI
    @Published var isSubscribed: Bool { // Added for SwiftUI view updates
        didSet {
            // Sync with UserDefaults for compatibility
            UserDefaults.standard.set(isSubscribed ? 1 : 0, forKey: "SubscriptionExpired")
            UserDefaults.standard.synchronize()
        }
    }
    
    private override init() {
        // Initialize isSubscribed from UserDefaults
        self.isSubscribed = UserDefaults.standard.integer(forKey: "SubscriptionExpired") != 0
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    // MARK: - Properties
    private var products: [String: SKProduct] = [:]
    private var availableProducts: [SKProduct] = []
    private var currentProduct: [String: Any] = [:]
    private var currentIsActive: Bool = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var latestReceipt: String?
    private var restoreExpired: Bool = false
    private var fetchCompletion: (([SKProduct]?, Error?) -> Void)?
    private var purchaseCompletion: ((Bool, Error?) -> Void)?
    private var restoreCompletion: ((Bool, Error?) -> Void)?
    
    // MARK: - Store Setup
    func fetchProducts(completion: @escaping ([SKProduct]?, Error?) -> Void) {
        guard products.isEmpty else {
            completion(availableProducts, nil)
            return
        }
        
        self.fetchCompletion = completion
        let request = SKProductsRequest(productIdentifiers: subscriptionProductIDs)
        request.delegate = self
        request.start()
    }
    
    // MARK: - SKProductsRequestDelegate
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        availableProducts = response.products
        products = response.products.reduce(into: [String: SKProduct]()) { result, product in
            result[product.productIdentifier] = product
        }
        
        print("Loaded products: \(response.products.map { $0.productIdentifier })")
        NotificationCenter.default.post(name: .productsFetched, object: availableProducts)
        fetchCompletion?(availableProducts, nil)
        fetchCompletion = nil
        endBackgroundTask()
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Product request failed: \(error.localizedDescription)")
        NotificationCenter.default.post(name: .productsFetchFailed, object: error.localizedDescription)
        fetchCompletion?(nil, error)
        fetchCompletion = nil
        endBackgroundTask()
    }
    
    func requestDidFinish(_ request: SKRequest) {
        print("Product request finished")
        endBackgroundTask()
    }
    
    // MARK: - Purchase Handling
    func canMakePurchases() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    func purchaseProduct(_ product: SKProduct, completion: @escaping (Bool, Error?) -> Void) {
        guard canMakePurchases() else {
            completion(false, NSError(domain: "SubscriptionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Purchases are disabled on this device"]))
            return
        }
        // Set flag to indicate StoreKit operation is starting
        isStoreKitOperationInProgress = true
        guard !availableProducts.isEmpty else {
            fetchProducts { [weak self] products, error in
                if let error = error {
                    completion(false, error)
                    return
                }
                if let product = products?.first(where: { $0.productIdentifier == product.productIdentifier }) {
                    self?.purchaseCompletion = completion
                    let payment = SKPayment(product: product)
                    SKPaymentQueue.default().add(payment)
                    // Analytics.logEvent("RemoveAds_Request", parameters: nil)
                } else {
                    completion(false, NSError(domain: "SubscriptionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Product not found"]))
                }
            }
            return
        }
        
        purchaseCompletion = completion
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
        // Analytics.logEvent("RemoveAds_Request", parameters: nil)
    }
    
    func restorePurchases(completion: @escaping (Bool, Error?) -> Void) {
        // Set flag to indicate StoreKit operation is starting
        isStoreKitOperationInProgress = true
        restoreCompletion = completion
        SKPaymentQueue.default().restoreCompletedTransactions()
        // Analytics.logEvent("Restore_RemoveAds_Request", parameters: nil)
    }
    
    // MARK: - SKPaymentTransactionObserver
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                break
            case .purchased:
                handlePurchasedTransaction(transaction)
                isStoreKitOperationInProgress = false // Reset flag on completion
            case .failed:
                handleFailedTransaction(transaction)
                isStoreKitOperationInProgress = false // Reset flag on completion
            case .restored:
                handleRestoredTransaction(transaction)
                isStoreKitOperationInProgress = false // Reset flag on completion
            case .deferred:
                SKPaymentQueue.default().finishTransaction(transaction)
                isStoreKitOperationInProgress = false // Reset flag on completion
            @unknown default:
                break
            }
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        NotificationCenter.default.post(name: .closeSubscriptionView, object: nil)
        NotificationCenter.default.post(name: .hideActivityIndicator, object: nil)
        restoreCompletion?(false, error)
        restoreCompletion = nil
        isStoreKitOperationInProgress = false // Reset flag on failure
        showAlert(title: "Restore Failed", message: error.localizedDescription)
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("Subscriptions restored")
        checkSubscriptionExpiry()
        isStoreKitOperationInProgress = false // Reset flag on failure
        showAlert(title: "Restored", message: "Subscriptions restored")
        // Analytics.logEvent("Restore_RemoveAds_Completed", parameters: nil)
    }
    
    // Helper method to check if a StoreKit operation is in progress
    func isStoreKitActive() -> Bool {
            return isStoreKitOperationInProgress
    }
    
    // MARK: - Transaction Handling
    private func handlePurchasedTransaction(_ transaction: SKPaymentTransaction) {
        print("Purchased transaction: \(transaction.transactionDate?.description ?? "No date")")
        saveProductPurchase(transaction)
        checkSubscriptionExpiry()
        subscriptionPurchasedSuccessfully()
        logPurchaseEvent(transaction.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
        NotificationCenter.default.post(name: .closeSubscriptionView, object: nil)
        purchaseCompletion?(true, nil)
        purchaseCompletion = nil
    }
    
//    private func handleFailedTransaction(_ transaction: SKPaymentTransaction) {
//        let error = transaction.error
//        if let skError = error as? SKError, skError.code != .paymentCancelled {
//            showAlert(title: "Error", message: skError.localizedDescription)
//            purchaseCompletion?(false, skError)
//        } else if error != nil {
//            showAlert(title: "Error", message: error?.localizedDescription ?? "Something went wrong. Try again.")
//            purchaseCompletion?(false, error)
//        } else {
//            purchaseCompletion?(false, nil)
//        }
//        SKPaymentQueue.default().finishTransaction(transaction)
//        NotificationCenter.default.post(name: .hideActivityIndicator, object: nil)
//        purchaseCompletion = nil
//    }
    
    private func handleFailedTransaction(_ transaction: SKPaymentTransaction) {
        let error = transaction.error
        if let skError = error as? SKError {
            switch skError.code {
            case .paymentCancelled:
                print("Purchase canceled by user")
                purchaseCompletion?(false, nil) // No error for user cancellation
            case .unknown:
                print("Unknown StoreKit error: \(skError.localizedDescription)")
                showAlert(title: "Error", message: "An unknown error occurred during the purchase. Please try again.")
                purchaseCompletion?(false, skError)
            default:
                print("StoreKit error: \(skError.code), description: \(skError.localizedDescription)")
                showAlert(title: "Error", message: skError.localizedDescription)
                purchaseCompletion?(false, skError)
            }
        } else {
            // Handle non-SKError cases (e.g., Unhandled exception)
            let errorMessage = error?.localizedDescription ?? "Something went wrong. Try again."
            print("Non-StoreKit error: \(errorMessage)")
            showAlert(title: "Error", message: errorMessage)
            purchaseCompletion?(false, error)
        }
        SKPaymentQueue.default().finishTransaction(transaction)
        NotificationCenter.default.post(name: .hideActivityIndicator, object: nil)
        purchaseCompletion = nil
    }
    
    private func handleRestoredTransaction(_ transaction: SKPaymentTransaction) {
        print("Restored transaction: \(transaction.transactionDate?.description ?? "No date")")
        saveProductPurchase(transaction.original ?? transaction)
        checkSubscriptionExpiry()
        SKPaymentQueue.default().finishTransaction(transaction)
        restoreCompletion?(true, nil)
        restoreCompletion = nil
    }
    
    // MARK: - Receipt Validation
    func validateReceipt(completion: @escaping (Bool, Date?, Error?) -> Void) {
        startBackgroundTask(taskName: "ReceiptValidationTask")
        
        Task {
            guard let receiptURL = Bundle.main.appStoreReceiptURL,
                  let receiptData = try? Data(contentsOf: receiptURL) else {
                let error = NSError(domain: "SubscriptionManager", code: 1111111, userInfo: [NSLocalizedDescriptionKey: "AppStore receipt not found"])
                DispatchQueue.main.async {
                    completion(false, nil, error)
                }
                self.endBackgroundTask()
                return
            }
            
            let requestContents = [
                "receipt-data": receiptData.base64EncodedString(),
                "password": kSharedSecret
            ]
            
            guard let requestData = try? JSONSerialization.data(withJSONObject: requestContents) else {
                let error = NSError(domain: "SubscriptionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request data"])
                DispatchQueue.main.async {
                    completion(false, nil, error)
                }
                self.endBackgroundTask()
                return
            }
            
            let storeURL = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? URL(string: kSandboxServer)! : URL(string: kLiveServer)!
            var request = URLRequest(url: storeURL)
            request.httpMethod = "POST"
            request.httpBody = requestData
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let receiptInfo = jsonResponse["latest_receipt_info"] as? [[String: Any]],
                      !receiptInfo.isEmpty,
                      let firstReceipt = receiptInfo.first,
                      let expiresDateString = firstReceipt["expires_date"] as? String else {
                    DispatchQueue.main.async {
                        completion(false, nil, nil)
                    }
                    self.endBackgroundTask()
                    return
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"
                guard let expiryDate = formatter.date(from: expiresDateString) else {
                    DispatchQueue.main.async {
                        completion(false, nil, nil)
                    }
                    self.endBackgroundTask()
                    return
                }
                
                // Compare expiryDate with current time
                let currentDate = Date()
                let isSubscriptionActive = expiryDate > currentDate
                
                // Print for debugging
                print("expiresDateString: \(expiresDateString)")
                print("expiryDate: \(expiryDate)")
                print("currentDate: \(currentDate)")
                print("isSubscriptionActive: \(isSubscriptionActive)")
                
                DispatchQueue.main.async {
                    completion(isSubscriptionActive, expiryDate, nil)
                }
                self.endBackgroundTask()
            } catch {
                DispatchQueue.main.async {
                    completion(false, nil, error)
                }
                self.endBackgroundTask()
            }
        }
    }
    
    func checkSubscriptionExpiry() {
        validateReceipt { [weak self] isValid, _, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .closeSubscriptionView, object: nil)
                NotificationCenter.default.post(name: .hideActivityIndicator, object: nil)
                
                if isValid {
                    print("Subscription active")
                    self.unlockAllFeatures()
                    NotificationCenter.default.post(name: .restoreSuccessful, object: nil)
                } else {
                    print("Subscription expired")
                    self.lockAllFeatures()
                    NotificationCenter.default.post(name: .restoreFailed, object: nil)
                }
            }
        }
    }
    
    // MARK: - Product Information
    func getPrice(for productId: String) -> String {
        guard let product = products[productId] else {
            print("Product not found: \(productId)")
            return productId == "com.outthinking.videoupscaler.enhancer.yearly" ? defaultYearlyPackPrice : defaultWatermarkPackPrice
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "\(product.price)"
    }
    
    func getCurrencyCode(for productId: String) -> String {
        guard let product = products[productId] else {
            print("Product not found: \(productId)")
            return "USD"
        }
        return product.priceLocale.currencyCode ?? "USD"
    }
    
    func getTitle(for productId: String) -> String {
        guard let product = products[productId] else {
            print("Product not found: \(productId)")
            return defaultWatermarkPackTitle
        }
        return product.localizedTitle
    }
    
    func getDescription(for productId: String) -> String {
        guard let product = products[productId] else {
            print("Product not found: \(productId)")
            return defaultWatermarkPackDescription
        }
        return product.localizedDescription
    }
    
    func getTrialPeriodDays(for productId: String) -> Int {
        guard let product = products[productId] else {
            print("Product not found: \(productId)")
            return 0
        }
        
        if #available(iOS 11.2, *) {
            guard let introductoryPrice = product.introductoryPrice else { return 0 }
            let numberOfPeriods = introductoryPrice.numberOfPeriods
            let numberOfUnits = introductoryPrice.subscriptionPeriod.numberOfUnits
            let daysPerUnit = numberOfDaysForUnit(introductoryPrice.subscriptionPeriod.unit)
            return numberOfPeriods * numberOfUnits * daysPerUnit
        }
        return 0
    }
    
    private func numberOfDaysForUnit(_ unit: SKProduct.PeriodUnit) -> Int {
        if #available(iOS 11.2, *) {
            switch unit {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .year: return 365
            @unknown default: return 0
            }
        }
        return 0
    }
    
    // MARK: - Subscription Status
    func isAppSubscribed() -> Bool {
        return isSubscribed // Use published property
    }
    
    func isSessionExpired() -> Bool {
        return UserDefaults.standard.integer(forKey: "SubscriptionSessionExpired") != 0
    }
    
    // MARK: - Feature Management
    private func lockAllFeatures() {
        print("Locking all features")
        isSubscribed = false // Triggers SwiftUI view update
        UserDefaults.standard.set(1, forKey: "SubscriptionSessionExpired")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .subscriptionSessionExpired, object: self)
    }
    
    private func unlockAllFeatures() {
        print("Unlocking all features")
        isSubscribed = true // Triggers SwiftUI view update
        UserDefaults.standard.set(0, forKey: "SubscriptionSessionExpired")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .clearAllLocks, object: nil)
        NotificationCenter.default.post(name: .hideActivityIndicator, object: nil)
    }
    
    // MARK: - Purchase Tracking
    private func saveProductPurchase(_ transaction: SKPaymentTransaction) {
        UserDefaults.standard.set(true, forKey: transaction.payment.productIdentifier)
        UserDefaults.standard.set(true, forKey: "boughtAnyProduct")
        UserDefaults.standard.set(1, forKey: "PurchasedYES")
        UserDefaults.standard.synchronize()
        
        currentProduct["product"] = transaction.payment.productIdentifier
        currentIsActive = true
    }
    
    private func subscriptionPurchasedSuccessfully() {
        UserDefaults.standard.set(1, forKey: "PurchasedYES")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Analytics
    private func logPurchaseEvent(_ productId: String) {
        let rawPrice = getPrice(for: productId)
        let currencyCode = getCurrencyCode(for: productId)
        var eventName = ""
        
        Task {
            let receiptURL = Bundle.main.appStoreReceiptURL
            guard let receiptData = try? Data(contentsOf: receiptURL!),
                  let receiptDict = try? JSONSerialization.jsonObject(with: receiptData) as? [String: Any],
                  let latestReceipts = receiptDict["latest_receipt_info"] as? [[String: Any]],
                  let firstTransaction = latestReceipts.first else {
                return
            }
            
            let isTrialPeriod = firstTransaction["is_trial_period"] as? Bool ?? false
            let isInIntroOfferPeriod = firstTransaction["is_in_intro_offer_period"] as? Bool ?? false
            
            switch productId {
            case "com.outthinking.videoupscaler.enhancer.yearly":
                eventName = (isTrialPeriod && isInIntroOfferPeriod) ? "yearly_trial_activated" : "purchase_yearly_subscription"
            case "com.outthinking.videoupscaler.enhancer.monthly":
                eventName = "purchase_monthly_subscription"
            case "com.outthinking.videoupscaler.enhancer.weekly":
                eventName = "purchase_weekly_subscription"
            default:
                eventName = "purchase_unknown"
            }
            
            let priceValue = cleanPriceString(rawPrice)
            
            Analytics.logEvent(eventName, parameters: [
                AnalyticsParameterValue: priceValue,
                AnalyticsParameterCurrency: currencyCode,
                "is_trial": isTrialPeriod,
                "is_intro_offer": isInIntroOfferPeriod
            ])
            
            print("Logged purchase: \(eventName), price = \(priceValue), currency = \(currencyCode)")
        }
    }
    
    private func cleanPriceString(_ price: String) -> Double {
        let allowedChars = CharacterSet(charactersIn: "0123456789.,")
        let filtered = price.unicodeScalars.filter { allowedChars.contains($0) }
        var cleanPrice = String(String.UnicodeScalarView(filtered))
        
        cleanPrice = cleanPrice.replacingOccurrences(of: ",", with: ".")
        
        return Double(cleanPrice) ?? 0.0
    }
    
    // MARK: - Background Tasks
    private func startBackgroundTask(taskName: String) {
        guard backgroundTask == .invalid else { return }
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: taskName) { [weak self] in
            self?.endBackgroundTask()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            if self?.backgroundTask != .invalid {
                print("Background task timed out: \(taskName)")
                self?.endBackgroundTask()
            }
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    // MARK: - Alerts
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
        }
    }
}

