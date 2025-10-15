import Foundation
import StoreKit
import Combine
import AVFoundation
import Photos
import SwiftUI

// MARK: - Server-backed Enhancement Service
final class ServerEnhancementService: ObservableObject, EnhancementServiceProtocol {
    // Published state
    @Published private var processingState: EnhancementProcessingState = .idle
    @Published private var progress: Double = 0.0
    @Published private(set) var currentTaskId: String = ""
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    
    var processingStatePublisher: Published<EnhancementProcessingState>.Publisher { $processingState }
    var progressPublisher: Published<Double>.Publisher { $progress }
    
    private let baseURL = AppConfig.baseURL
    private let videoProcessingService: VideoProcessingProtocol
    private var pollTimer: Timer?
    private let enhancementRegistry: EnhancementTypeRegistry
    private let enhancementProgressWeight: Double = 0.8
    private let downloadProgressWeight: Double = 0.2
    
    init(videoProcessingService: VideoProcessingProtocol = VideoProcessingService(), enhancementRegistry: EnhancementTypeRegistry = .shared) {
        self.videoProcessingService = videoProcessingService
        self.enhancementRegistry = enhancementRegistry
    }
    
    func getSupportedEnhancementTypes() -> [EnhancementType] {
        enhancementRegistry.getAllEnhancementTypes()
    }
    
    func validateEnhancement(request: EnhancementRequest) throws {
        let supported = getSupportedEnhancementTypes()
        guard supported.contains(where: { $0.id == request.enhancementType.id }) else {
            throw EnhancementError.invalidInput("Unsupported enhancement type: \(request.enhancementType.id)")
        }
    }
    
    func cancelProcessing() async {
        // Only attempt to cancel if we're actually processing
        let (shouldCancel, taskId) = await MainActor.run { () -> (Bool, String) in
            let shouldCancel: Bool = {
                switch self.processingState {
                case .preparing, .processing:
                    return true
                default:
                    return false
                }
            }()
            let taskId = self.currentTaskId

            self.pollTimer?.invalidate()
            self.pollTimer = nil
            self.processingState = .cancelled
            self.progress = 0.0
            self.showAlert = false

            return (shouldCancel, taskId)
        }

        if shouldCancel && !taskId.isEmpty {
            do {
                try await cancelTask(taskId: taskId)
                await MainActor.run {
                    self.currentTaskId = ""
                }
            } catch {
                // Only show alert if user actively canceled (not during cleanup of completed task)
                await showErrorAlert(title: "Cancel Failed", message: "Failed to cancel task: \(error.localizedDescription)")
            }
        } else if !taskId.isEmpty {
            // Clear task ID even if not actively processing
            await MainActor.run {
                self.currentTaskId = ""
            }
        }
    }
    
    func processVideo(at url: URL, with request: EnhancementRequest) async throws -> EnhancementResult {
        try await withCheckedThrowingContinuation { continuation in
            Task { [weak self] in
                guard let self = self else { return }
                await self.updateState(.preparing, progress: 0.0)
                
                do {
                    let (endpoint, includeLevel) = self.mapEndpoint(for: request.enhancementType.id)

                    let effectiveURL: URL
                    if let start = request.trimStartTime, let end = request.trimEndTime, end > start {
                        let quality = self.videoQualityFromOutputQuality(request.outputQuality)
                        effectiveURL = try await self.videoProcessingService.trimVideo(at: url, startTime: start, endTime: end, quality: quality)
                    } else {
                        effectiveURL = url
                    }

                    try await self.uploadVideo(
                        videoURL: effectiveURL,
                        endpoint: endpoint,
                        includeLevel: includeLevel,
                        level: self.mapLevel(for: request)
                    )
                    await self.updateState(.processing(phase: .analysis), progress: 0.3 * enhancementProgressWeight)
                    
                    try await self.pollUntilComplete(taskId: self.currentTaskId)
                    
                    let (processedURL, originalURL) = try await self.fetchResult(taskId: self.currentTaskId)
                    
                    let result = EnhancementResult(
                        originalURL: originalURL ?? effectiveURL,
                        processedURL: processedURL,
                        enhancementType: request.enhancementType,
                        processingTime: 0,
                        metadata: EnhancementMetadata(
                            processingTime: 0,
                            enhancementStrength: 0,
                            qualityScore: 0,
                            fileSize: 0,
                            appliedSettings: [
                                "endpoint": endpoint,
                                "level": self.mapLevel(for: request) ?? ""
                            ]
                        )
                    )
                    await self.updateState(.completed(result), progress: 1.0)
//                    await showSuccessAlert(title: "Processing Complete", message: "Your video has been processed successfully!")

                    // Clear task ID after successful completion
                    await MainActor.run {
                        self.currentTaskId = ""
                    }

                    // Call show rate us panel using configManager value for rate us panel
                    self.showRateUsPanel()
                    continuation.resume(returning: result)
                } catch {
                    await self.updateState(.failed(.processingFailed(error.localizedDescription)), progress: self.progress)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func showRateUsPanel() {
        print("Showing rate us panel")
        let shouldShow = ConfigManager.shared.getBool(forKey: "rateus_panel")
        if shouldShow {
            // Ensure UI-related code runs on the main thread
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.windows.first?.windowScene {
                    if #available(iOS 14.0, *) {
                        SKStoreReviewController.requestReview(in: windowScene)
                    } else {
                        SKStoreReviewController.requestReview()
                    }
                } else {
                    print("Error: UIWindowScene is unavailable")
                }
            }
        }
    }
    
    // MARK: - Private helpers
    private func mapEndpoint(for enhancementId: String) -> (String, Bool) {
        switch enhancementId {
        case "ai_auto_enhancement":
            return ("/brightness", true)
        case "ai_denoise":
            return ("/denoise", true)
        case "face_enhancer":
            return ("/face_enhance", false)
        case "ai_color":
            return ("/colorization", false)
        case "stabilizer":
            return ("/stabilization", true)
        case "frame_interpolation":
            return ("/interpolation", true)
        case "ai_upscale":
            return ("/upscale", true)
        default:
            return ("/brightness", true)
        }
    }
    
    private func mapLevel(for request: EnhancementRequest) -> String? {
        let id = request.enhancementType.id
        let opt = request.selectedOption.id
        switch id {
        case "ai_auto_enhancement", "ai_denoise", "stabilizer":
            return opt
        case "frame_interpolation":
            return opt
        case "ai_upscale":
            let mapped = opt.lowercased()
            if mapped == "1080p" || mapped == "1080" { return "1080" }
            if mapped == "2k" { return "2K" }
            if mapped == "4k" { return "4K" }
            return "1080"
        case "ai_color", "face_enhancer":
            return nil
        default:
            return opt
        }
    }

    private func videoQualityFromOutputQuality(_ outputQuality: OutputQuality) -> VideoQuality {
        switch outputQuality {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .original: return .original
        }
    }
    
    @MainActor
    private func updateState(_ state: EnhancementProcessingState, progress: Double) {
        self.processingState = state
        self.progress = progress
    }
    
    @MainActor
    private func showErrorAlert(title: String, message: String) {
        self.showAlert = true
        self.alertTitle = title
        self.alertMessage = message
    }
    
    @MainActor
    private func showSuccessAlert(title: String, message: String) {
        self.showAlert = true
        self.alertTitle = title
        self.alertMessage = message
    }
    
    private func uploadVideo(videoURL: URL, endpoint: String, includeLevel: Bool, level: String?) async throws {
            guard let url = URL(string: baseURL + endpoint) else {
                throw EnhancementError.processingFailed("Invalid URL")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            if includeLevel, let level = level {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"level\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(level)\r\n".data(using: .utf8)!)
            }
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
            let data = try Data(contentsOf: videoURL)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body
            
            let (respData, response) = try await URLSession.shared.data(for: request)
            
            // Check for 503 responses
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 503 {
                guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: String],
                      let error = json["error"],
                      let status = json["status"] else {
                    throw EnhancementError.processingFailed("Invalid 503 response from server")
                }
                // Show "Server Busy" alert for both "busy" and "insufficient_memory" statuses
                await showErrorAlert(title: "Server Busy", message: "Server busy, please try again after some time")
                throw EnhancementError.processingFailed(error)
            }
            
            guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let taskId = json["task_id"] as? String else {
                throw EnhancementError.processingFailed("Invalid response from server")
            }
            await MainActor.run {
                self.currentTaskId = taskId
            }
        }
        
        private func pollUntilComplete(taskId: String) async throws {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.processingState = .processing(phase: .enhancement)
                    self.progress = max(self.progress, 0.3 * self.enhancementProgressWeight)
                    
                    self.pollTimer?.invalidate()
                    self.pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                        guard let url = URL(string: self.baseURL + "/progress/" + taskId) else { return }
                        URLSession.shared.dataTask(with: url) { data, response, _ in
                            DispatchQueue.main.async {
                                guard let data = data,
                                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                      let status = json["status"] as? String else { return }
                                
                                let serverProgress = json["progress"] as? Double ?? 0.0
                                let scaledProgress = serverProgress * self.enhancementProgressWeight
                                self.progress = max(scaledProgress, self.progress)
                                
                                if status == "completed" {
                                    timer.invalidate()
                                    self.pollTimer = nil
                                    continuation.resume()
                                } else if status == "failed" {
                                    timer.invalidate()
                                    self.pollTimer = nil
                                    let errorMsg = json["error"] as? String ?? "Unknown error"
                                    // Show "Server Busy" alert for all failures, including memory-related errors
                                    self.showErrorAlert(title: "Server Busy", message: "Server busy, please try again after some time")
                                    continuation.resume(throwing: EnhancementError.processingFailed(errorMsg))
                                }
                            }
                        }.resume()
                    }
                }
            }
        }
    
    private func fetchResult(taskId: String) async throws -> (URL, URL?) {
        guard let url = URL(string: baseURL + "/result/" + taskId) else {
            throw EnhancementError.processingFailed("Bad result URL")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let processedURL = json["processed_url"] else {
            throw EnhancementError.processingFailed("No processed_url")
        }
        let originalURL = json["original_url"]
        
        let processedLocal = try await downloadToDocuments(taskID: taskId, prefix: "enhanced_video", baseURL: baseURL)
        
        await MainActor.run {
            self.progress = self.enhancementProgressWeight + (self.downloadProgressWeight / (originalURL != nil ? 2 : 1))
        }
        
        var originalLocal: URL? = nil
        if let originalURL = originalURL {
            originalLocal = try await downloadToDocuments(from: originalURL, prefix: "original_video")
            await MainActor.run {
                self.progress = 1.0
            }
        }
        
        return (processedLocal, originalLocal)
    }
    
    private func downloadToDocuments(from path: String, prefix: String) async throws -> URL {
        guard let url = URL(string: baseURL + path) else { throw EnhancementError.processingFailed("Bad download URL") }
        return try await downloadToDocuments(taskID: UUID().uuidString, prefix: prefix, baseURL: baseURL)
    }
    
    private func downloadToDocuments(taskID: String, prefix: String, baseURL: String) async throws -> URL {
        guard let url = URL(string: "\(baseURL)/download/processed/\(taskID)") else {
            throw EnhancementError.processingFailed("Invalid download URL for task ID: \(taskID)")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let sessionIdentifier = "com.example.download.\(UUID().uuidString)"
            let configuration = URLSessionConfiguration.default
            let delegateQueue = OperationQueue()
            delegateQueue.maxConcurrentOperationCount = 1
            
            let progressDelegate = DownloadProgressDelegate(
                progressWeight: downloadProgressWeight / 2,
                progressOffset: enhancementProgressWeight,
                progressHandler: { [weak self] progress in
                    self?.progress = progress
                },
                completionHandler: { [weak self] location, error in
                    guard let self = self else { return }
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let location = location else {
                        continuation.resume(throwing: EnhancementError.processingFailed("Download failed: no location"))
                        return
                    }
                    
                    do {
                        let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("\(prefix)_\(UUID().uuidString).mp4")
                        try? FileManager.default.removeItem(at: destURL)
                        try FileManager.default.moveItem(at: location, to: destURL)
                        continuation.resume(returning: destURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            )
            
            let session = URLSession(configuration: configuration, delegate: progressDelegate, delegateQueue: delegateQueue)
            
            let downloadTask = session.downloadTask(with: url)
            downloadTask.resume()
            
            Task {
                await withTaskCancellationHandler {
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * 60))
                    session.invalidateAndCancel()
                } onCancel: {
                    session.invalidateAndCancel()
                }
            }
        }
    }
    
    private func cancelTask(taskId: String) async throws {
        guard !taskId.isEmpty else { return }
        guard let url = URL(string: baseURL + "/cancel/" + taskId) else {
            throw EnhancementError.processingFailed("Invalid cancel URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            await MainActor.run {
                self.currentTaskId = ""
            }
        } else {
            throw EnhancementError.processingFailed("Cancel task failed with status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
    }
}
// MARK: - Download Progress Delegate
class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let progressHandler: (Double) -> Void
    private let completionHandler: (URL?, Error?) -> Void
    private let progressWeight: Double
    private let progressOffset: Double
    
    init(progressWeight: Double, progressOffset: Double, progressHandler: @escaping (Double) -> Void, completionHandler: @escaping (URL?, Error?) -> Void) {
        self.progressWeight = progressWeight
        self.progressOffset = progressOffset
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let scaledProgress = progressOffset + (progress * progressWeight)
        DispatchQueue.main.async {
            self.progressHandler(scaledProgress)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            completionHandler(nil, error)
            return
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        completionHandler(location, nil)
    }
}


