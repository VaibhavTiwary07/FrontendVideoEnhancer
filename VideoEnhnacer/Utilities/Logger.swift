import Foundation
import os.log

// MARK: - App Logger
/// Centralized logging system following Single Responsibility Principle
final class AppLogger {
    
    // MARK: - Singleton
    static let shared = AppLogger()
    
    // MARK: - Log Categories
    enum Category: String, CaseIterable {
        case general = "General"
        case videoPlayer = "VideoPlayer"
        case videoProcessing = "VideoProcessing"
        case enhancement = "Enhancement"
        case navigation = "Navigation"
        case networking = "Networking"
        case ui = "UI"
        case performance = "Performance"
        
        var osLog: OSLog {
            OSLog(subsystem: "com.videoenhancer.app", category: rawValue)
        }
        
        var emoji: String {
            switch self {
            case .general: return "📱"
            case .videoPlayer: return "🎥"
            case .videoProcessing: return "⚙️"
            case .enhancement: return "✨"
            case .navigation: return "🧭"
            case .networking: return "🌐"
            case .ui: return "🎨"
            case .performance: return "⚡"
            }
        }
    }
    
    // MARK: - Log Level
    enum LogLevel: Int, CaseIterable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
        
        var name: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            case .critical: return "CRITICAL"
            }
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
    
    // MARK: - Configuration
    private var minimumLogLevel: LogLevel = .debug
    private var enabledCategories: Set<Category> = Set(Category.allCases)
    private var enableOSLog: Bool = true
    private var enableFileLogging: Bool = false
    private var logFileURL: URL?
    
    // MARK: - Private Properties
    private let dateFormatter: DateFormatter
    private let logQueue = DispatchQueue(label: "com.videoenhancer.logging", qos: .utility)
    
    // MARK: - Initialization
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        setupFileLogging()
    }
    
    // MARK: - Configuration Methods
    func configure(
        minimumLogLevel: LogLevel = .debug,
        enabledCategories: Set<Category> = Set(Category.allCases),
        enableOSLog: Bool = true,
        enableFileLogging: Bool = false
    ) {
        self.minimumLogLevel = minimumLogLevel
        self.enabledCategories = enabledCategories
        self.enableOSLog = enableOSLog
        self.enableFileLogging = enableFileLogging
        
        if enableFileLogging {
            setupFileLogging()
        }
    }
    
    // MARK: - Public Logging Methods
    func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: Category = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let error = error {
            logMessage += " - Error: \(error.localizedDescription)"
        }
        log(logMessage, level: .error, category: category, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: Category = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let error = error {
            logMessage += " - Error: \(error.localizedDescription)"
        }
        log(logMessage, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Specialized Logging Methods
    func logVideoPlayerEvent(_ event: VideoPlayerEvent, details: [String: Any] = [:]) {
        let message = formatVideoPlayerEvent(event, details: details)
        log(message, level: .info, category: .videoPlayer)
    }
    
    func logEnhancementEvent(_ event: EnhancementEvent, details: [String: Any] = [:]) {
        let message = formatEnhancementEvent(event, details: details)
        log(message, level: .info, category: .enhancement)
    }
    
    func logNavigationEvent(_ event: NavigationEvent, details: [String: Any] = [:]) {
        let message = formatNavigationEvent(event, details: details)
        log(message, level: .info, category: .navigation)
    }
    
    func logPerformanceMetric(_ metric: PerformanceMetric, value: Double, unit: String = "") {
        let message = "Performance - \(metric.rawValue): \(value)\(unit)"
        log(message, level: .info, category: .performance)
    }
    
    // MARK: - Private Core Logging Method
    private func log(
        _ message: String,
        level: LogLevel,
        category: Category,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Check if logging is enabled for this level and category
        guard level.rawValue >= minimumLogLevel.rawValue,
              enabledCategories.contains(category) else { return }
        
        logQueue.async {
            let timestamp = self.dateFormatter.string(from: Date())
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            let location = "\(fileName):\(function):\(line)"
            
            let formattedMessage = "\(level.emoji) \(category.emoji) [\(level.name)] \(timestamp) \(location) - \(message)"
            
            // Console logging
            print(formattedMessage)
            
            // OS Log
            if self.enableOSLog {
                os_log("%{public}@", log: category.osLog, type: level.osLogType, formattedMessage)
            }
            
            // File logging
            if self.enableFileLogging {
                self.writeToFile(formattedMessage)
            }
        }
    }
    
    // MARK: - File Logging
    private func setupFileLogging() {
        guard enableFileLogging else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentsPath.appendingPathComponent("app_logs.txt")
        
        // Create file if it doesn't exist
        if let url = logFileURL, !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
    }
    
    private func writeToFile(_ message: String) {
        guard let url = logFileURL else { return }
        
        do {
            let data = (message + "\n").data(using: .utf8)!
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { fileHandle.closeFile() }
            
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        } catch {
            print("Failed to write to log file: \(error)")
        }
    }
    
    // MARK: - Event Formatters
    private func formatVideoPlayerEvent(_ event: VideoPlayerEvent, details: [String: Any]) -> String {
        var message = "VideoPlayer - \(event.rawValue)"
        if !details.isEmpty {
            let detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += " (\(detailsString))"
        }
        return message
    }
    
    private func formatEnhancementEvent(_ event: EnhancementEvent, details: [String: Any]) -> String {
        var message = "Enhancement - \(event.rawValue)"
        if !details.isEmpty {
            let detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += " (\(detailsString))"
        }
        return message
    }
    
    private func formatNavigationEvent(_ event: NavigationEvent, details: [String: Any]) -> String {
        var message = "Navigation - \(event.rawValue)"
        if !details.isEmpty {
            let detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += " (\(detailsString))"
        }
        return message
    }
    
    // MARK: - Log Management
    func clearLogs() {
        guard let url = logFileURL else { return }
        
        logQueue.async {
            do {
                try "".write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to clear log file: \(error)")
            }
        }
    }
    
    func getLogFileURL() -> URL? {
        return logFileURL
    }
}

// MARK: - Event Types
enum VideoPlayerEvent: String {
    case setupStarted = "Setup Started"
    case setupCompleted = "Setup Completed"
    case playbackStarted = "Playback Started"
    case playbackPaused = "Playback Paused"
    case seekPerformed = "Seek Performed"
    case loopCompleted = "Loop Completed"
    case error = "Error Occurred"
}

enum EnhancementEvent: String {
    case processingStarted = "Processing Started"
    case processingProgress = "Processing Progress"
    case processingCompleted = "Processing Completed"
    case processingCancelled = "Processing Cancelled"
    case processingFailed = "Processing Failed"
    case optionSelected = "Option Selected"
}

enum NavigationEvent: String {
    case flowStarted = "Flow Started"
    case flowCompleted = "Flow Completed"
    case screenAppeared = "Screen Appeared"
    case screenDisappeared = "Screen Disappeared"
    case navigationAction = "Navigation Action"
    case deepLinkHandled = "Deep Link Handled"
}

enum PerformanceMetric: String {
    case videoLoadTime = "Video Load Time"
    case processingTime = "Processing Time"
    case thumbnailGenerationTime = "Thumbnail Generation Time"
    case memoryUsage = "Memory Usage"
    case appLaunchTime = "App Launch Time"
}

// MARK: - Convenience Extensions
extension AppLogger {
    // Quick access methods for common categories
    func logUI(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .ui)
    }
    
    func logNetworking(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .networking)
    }
    
    func logPerformance(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .performance)
    }
}

// MARK: - Global Logging Functions
func logDebug(_ message: String, category: AppLogger.Category = .general) {
    AppLogger.shared.debug(message, category: category)
}

func logInfo(_ message: String, category: AppLogger.Category = .general) {
    AppLogger.shared.info(message, category: category)
}

func logWarning(_ message: String, category: AppLogger.Category = .general) {
    AppLogger.shared.warning(message, category: category)
}

func logError(_ message: String, category: AppLogger.Category = .general, error: Error? = nil) {
    AppLogger.shared.error(message, category: category, error: error)
}

func logCritical(_ message: String, category: AppLogger.Category = .general, error: Error? = nil) {
    AppLogger.shared.critical(message, category: category, error: error)
}