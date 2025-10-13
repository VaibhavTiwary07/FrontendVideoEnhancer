import Foundation
import FirebaseRemoteConfig

class ConfigManager {
    // Singleton instance
    static let shared = ConfigManager()
    
    // In-memory storage for config values (all as NSNumber)
    private var configValues: [String: NSNumber] = [:]
    
    // Default values (all as NSNumber)
    private let defaultValues: [String: NSNumber] = [
        "interstitial_launch": NSNumber(value: 1),
        "interstitial_resume": NSNumber(value: 1),
        "interstitial_home": NSNumber(value: 1),
        "nooperations": NSNumber(value: 1),
        "rateus_panel": NSNumber(value: 1),
        "subscription_mode": NSNumber(value: 1)
    ]
    
    private let remoteConfig: RemoteConfig
    private let defaultsKey = "cachedRemoteConfig"
    private let lastFetchTimeKey = "lastConfigFetchTime"
    private let minimumFetchInterval: TimeInterval = 0 // 0 means no cache
    
    private init() {
        // Initialize Firebase Remote Config
        remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = minimumFetchInterval // Disable caching
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(defaultValues)
    }
    
    // Fetch and activate remote config with comprehensive cache clearing
    func initialize(completion: @escaping (Error?) -> Void) {
        print("Starting Remote Config fetch with cache clearing...")
        
        // Clear all possible caches
        clearAllCaches()
        
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                print("Fetch failed with error: \(error.localizedDescription)")
                self.loadCachedOrDefaultConfig()
                completion(error)
                return
            }
            
            switch status {
            case .successFetchedFromRemote:
                print("Fetch status: Success - Fetched from remote server")
                // Store fetch time
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastFetchTimeKey)
            case .successUsingPreFetchedData:
                print("Fetch status: Success - Using pre-fetched/cached data")
            @unknown default:
                print("Fetch status: Unknown (\(status.rawValue))")
            }
            
            // Store fetched values as NSNumber
            self.updateConfigValues()
            self.cacheConfig()
            completion(nil)
        }
    }
    
    // Force fetch without any caching
    func forceFetch(completion: @escaping (Error?) -> Void) {
        print("Force fetching Remote Config...")
        
        // Clear all caches
        clearAllCaches()
        
        // Use fetch(completionHandler:) instead of fetchAndActivate for more control
        remoteConfig.fetch { [weak self] (status, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Force fetch failed: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            print("Force fetch completed with status: \(status.rawValue)")
            
            // Activate the fetched values
            self.remoteConfig.activate { [weak self] (changed, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Activation failed: \(error.localizedDescription)")
                } else {
                    print("Activation successful, config changed: \(changed)")
                }
                
                // Update our in-memory values regardless of activation status
                self.updateConfigValues()
                self.cacheConfig()
                completion(error)
            }
        }
    }
    
    // Clear all possible cache layers
    private func clearAllCaches() {
        // 1. Clear UserDefaults cache
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        
        // 2. Clear Firebase Remote Config cache domain
        let remoteConfigDomain = Bundle.main.bundleIdentifier! + ".remoteconfig"
        UserDefaults.standard.removePersistentDomain(forName: remoteConfigDomain)
        
        // 3. Clear in-memory cache
        configValues.removeAll()
        
        // 4. Force Firebase to clear its cache (iOS 13+)
        if #available(iOS 13.0, *) {
            remoteConfig.ensureInitialized { [weak self] result in
//                switch result {
//                case .success:
//                    print("Remote Config initialized, cache should be cleared")
//                case .failure(let error):
//                    print("Failed to reinitialize Remote Config: \(error)")
//                }
            }
        }
        
        UserDefaults.standard.synchronize()
        print("All caches cleared")
    }
    
    // Update config values from Remote Config
    private func updateConfigValues() {
        print("Raw Firebase Remote Config Values:")
        let keys = ["interstitial_launch", "interstitial_resume", "interstitial_home", "nooperations", "rateus_panel", "subscription_mode"]
        
        for key in keys {
            let value = self.remoteConfig[key]
            let numberValue = value.numberValue ?? self.defaultValues[key] ?? NSNumber(value: 0)
            
            print("\(key): source=\(value.source.rawValue), number=\(numberValue), string=\(value.stringValue ?? "nil")")
            
            self.configValues[key] = numberValue
        }
        
        print("Updated Config Values:")
        self.printConfigValues()
    }
    
    // Load cached or default config
    private func loadCachedOrDefaultConfig() {
        if let cachedConfig = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: NSNumber] {
            configValues = cachedConfig
            print("Loaded cached values:")
            self.printConfigValues()
        } else {
            configValues = defaultValues
            print("Loaded default values:")
            self.printConfigValues()
        }
    }
    
    // Cache config to UserDefaults
    private func cacheConfig() {
        UserDefaults.standard.set(configValues, forKey: defaultsKey)
        UserDefaults.standard.synchronize()
    }
    
    // Get config value as NSNumber
    func getNumber(forKey key: String) -> NSNumber {
        return configValues[key] ?? defaultValues[key] ?? NSNumber(value: 0)
    }
    
    // Convenience methods to get specific types
    func getBool(forKey key: String) -> Bool {
        return getNumber(forKey: key).boolValue
    }
    
    func getInt(forKey key: String) -> Int {
        return getNumber(forKey: key).intValue
    }
    
    // Print current config values
    func printConfigValues() {
        print("Current Remote Config Values:")
        for (key, value) in configValues {
            print("\(key): \(value)")
        }
    }
    
    // Check if we need to fetch based on time
    func shouldFetch() -> Bool {
        let lastFetch = UserDefaults.standard.double(forKey: lastFetchTimeKey)
        let currentTime = Date().timeIntervalSince1970
        return (currentTime - lastFetch) > minimumFetchInterval
    }
}
