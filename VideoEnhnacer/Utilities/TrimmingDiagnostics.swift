import Foundation
import UIKit
import os.log

/// Singleton logger for trimming diagnostics
/// Writes all trimming-related logs to a file for easy debugging
final class TrimmingDiagnostics {
    static let shared = TrimmingDiagnostics()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.trimming.diagnostics", attributes: .concurrent)

    // Use iOS-compatible document directory path
    private var logFileURL: URL {
        // iOS devices: Use Documents directory (accessible via Files app)
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("trimming_debug.log")
    }

    // Unified logging for iOS device console (visible in Xcode and Console app)
    private let osLog = OSLog(subsystem: "com.videoenhancer.trimming", category: "Diagnostics")

    private init() {
        // Initialize log file
        DispatchQueue.main.async {
            self.clearLog()
            let deviceInfo = """
            ═══════════════════════════════════════════════════════════════
            TRIMMING DIAGNOSTICS LOG STARTED
            Device: \(UIDevice.current.model)
            iOS Version: \(UIDevice.current.systemVersion)
            Device Name: \(UIDevice.current.name)
            Log Location: \(self.logFileURL.path)
            ═══════════════════════════════════════════════════════════════
            """
            self.write(deviceInfo)
            // Also log to system console for device debugging
            os_log("%{public}@", log: self.osLog, type: .info, deviceInfo)
        }
    }

    /// Log a message with timestamp
    static func log(_ message: String) {
        shared.write(message)
    }

    /// Clear the log file
    static func clearLog() {
        shared.clearLog()
    }

    /// Get the path to the log file (for debugging/sharing)
    static func getLogFilePath() -> URL {
        return shared.logFileURL
    }

    /// Get log contents as string
    static func getLogContents() -> String? {
        do {
            return try String(contentsOf: shared.logFileURL, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Check if log file exists
    static func logFileExists() -> Bool {
        return shared.fileManager.fileExists(atPath: shared.logFileURL.path)
    }

    /// Get log file size in bytes
    static func getLogFileSize() -> Int64? {
        guard logFileExists() else { return nil }
        do {
            let attrs = try shared.fileManager.attributesOfItem(atPath: shared.logFileURL.path)
            return attrs[.size] as? Int64
        } catch {
            return nil
        }
    }

    /// Share log file via UIActivityViewController
    static func shareLogFile(from viewController: UIViewController? = nil) {
        guard logFileExists() else {
            os_log("Log file does not exist", log: shared.osLog, type: .error)
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [shared.logFileURL],
            applicationActivities: nil
        )

        // For iPad compatibility
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        // Present from root view controller if not provided
        let presenter = viewController ?? UIApplication.shared.windows.first?.rootViewController
        presenter?.present(activityVC, animated: true)

        os_log("Log file shared: %{public}@", log: shared.osLog, type: .info, shared.logFileURL.path)
    }

    // MARK: - Private Methods

    private func write(_ message: String) {
        queue.async(flags: .barrier) {
            let timestamp = Date().timeIntervalSince1970
            let formattedMessage = "[\(timestamp)] \(message)\n"

            // Log to system console for device debugging (visible in Xcode Console and macOS Console.app)
            os_log("%{public}@", log: self.osLog, type: .debug, message)

            // Also write to file
            do {
                if !self.fileManager.fileExists(atPath: self.logFileURL.path) {
                    self.fileManager.createFile(atPath: self.logFileURL.path, contents: nil)
                }

                if let fileHandle = FileHandle(forWritingAtPath: self.logFileURL.path) {
                    defer { try? fileHandle.close() }
                    fileHandle.seekToEndOfFile()
                    if let data = formattedMessage.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                }
            } catch {
                // Log error to system console if file writing fails
                os_log("Failed to write to log file: %{public}@", log: self.osLog, type: .error, error.localizedDescription)
            }
        }
    }

    private func clearLog() {
        queue.async(flags: .barrier) {
            try? self.fileManager.removeItem(at: self.logFileURL)
        }
    }
}
