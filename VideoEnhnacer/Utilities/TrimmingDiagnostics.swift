import Foundation

/// Singleton logger for trimming diagnostics
/// Writes all trimming-related logs to a file for easy debugging
final class TrimmingDiagnostics {
    static let shared = TrimmingDiagnostics()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.trimming.diagnostics", attributes: .concurrent)
    private var logFileURL: URL {
        // Save directly to project directory for easy access during development
        return URL(fileURLWithPath: "/Users/vaibhavtiwary/Downloads/VideoEnhnacer_30th_Oct 2/trimming_debug.log")
    }

    private init() {
        // Initialize log file
        DispatchQueue.main.async {
            self.clearLog()
            self.write("═══════════════════════════════════════════════════════════════")
            self.write("TRIMMING DIAGNOSTICS LOG STARTED")
            self.write("═══════════════════════════════════════════════════════════════")
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

    // MARK: - Private Methods

    private func write(_ message: String) {
        queue.async(flags: .barrier) {
            let timestamp = Date().timeIntervalSince1970
            let formattedMessage = "[\(timestamp)] \(message)\n"

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
                // Silently fail - don't want logging to crash the app
            }
        }
    }

    private func clearLog() {
        queue.async(flags: .barrier) {
            try? self.fileManager.removeItem(at: self.logFileURL)
        }
    }
}
