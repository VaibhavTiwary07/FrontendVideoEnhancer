import Foundation
import UIKit

class LoadingDebugLogger {
    static let shared = LoadingDebugLogger()
    private let logFileName = "loading_debug.log"
    private var fileURL: URL?

    private init() {
        setupLogFile()
    }

    private func setupLogFile() {
        // Get project directory path (works in simulator/debug builds)
        let projectPath = #file
            .replacingOccurrences(of: "/VideoEnhnacer/Utilities/LoadingDebugLogger.swift", with: "")

        fileURL = URL(fileURLWithPath: projectPath).appendingPathComponent(logFileName)

        // Create/clear log file with header
        let header = """
        =====================================
        LOADING DEBUG LOG
        Started: \(Date())
        Device: \(UIDevice.current.name) (\(UIDevice.current.systemVersion))
        Model: \(UIDevice.current.model)
        =====================================

        """

        do {
            try header.write(to: fileURL!, atomically: true, encoding: .utf8)
            print("📝 LoadingDebugLogger: Writing to \(fileURL!.path)")
        } catch {
            print("❌ LoadingDebugLogger: Failed to create log file: \(error)")
        }
    }

    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let fileName = (file as NSString).lastPathComponent
        let entry = "[\(timestamp)] \(fileName):\(line) \(function)\n  → \(message)\n\n"

        // Print to console
        print(entry)

        // Append to file in project directory
        guard let fileURL = fileURL else { return }

        do {
            let handle = try FileHandle(forWritingTo: fileURL)
            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) {
                handle.write(data)
            }
            try handle.close()
        } catch {
            // File might not exist yet, try to append to it
            if let existingContent = try? String(contentsOf: fileURL, encoding: .utf8) {
                let newContent = existingContent + entry
                try? newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
}
