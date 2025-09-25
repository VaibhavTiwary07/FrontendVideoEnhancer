import Foundation
import Combine
import AVFoundation
import Photos
import SwiftUI

// MARK: - Server-backed Enhancement Service (uses given Sd backend contract)
final class ServerEnhancementService: ObservableObject, EnhancementServiceProtocol {
    // Published state
    @Published private var processingState: EnhancementProcessingState = .idle
    @Published private var progress: Double = 0.0
    
    var processingStatePublisher: Published<EnhancementProcessingState>.Publisher { $processingState }
    var progressPublisher: Published<Double>.Publisher { $progress }
    
    private let baseURL = AppConfig.baseURL
    private let videoProcessingService: VideoProcessingProtocol
    private var pollTimer: Timer?
    private var currentTaskId: String = ""
    private let enhancementRegistry: EnhancementTypeRegistry
    private var activeContinuation: CheckedContinuation<EnhancementResult, Error>?
    private var pollingContinuation: CheckedContinuation<Void, Error>?
    private var pendingCancellationError: EnhancementError?
    private var processingTask: Task<Void, Never>?
    
    init(videoProcessingService: VideoProcessingProtocol = VideoProcessingService(), enhancementRegistry: EnhancementTypeRegistry = .shared) {
        self.videoProcessingService = videoProcessingService
        self.enhancementRegistry = enhancementRegistry
    }
    
    func getSupportedEnhancementTypes() -> [EnhancementType] {
        enhancementRegistry.getAllEnhancementTypes()
    }
    
    func validateEnhancement(request: EnhancementRequest) throws {
        // Basic validation as in existing service
        let supported = getSupportedEnhancementTypes()
        guard supported.contains(where: { $0.id == request.enhancementType.id }) else {
            throw EnhancementError.invalidInput("Unsupported enhancement type: \(request.enhancementType.id)")
        }
    }
    
    func cancelProcessing() async {
        // If no task has been created yet, surface an informative failure and stop any local work.
        guard !currentTaskId.isEmpty else {
            let error = EnhancementError.processingFailed("No active task to cancel")
            pendingCancellationError = error
            await updateState(.failed(error), progress: progress)
            await invalidatePollingTimer(resumeWith: .failure(error))
            processingTask?.cancel()
            return
        }

        guard let url = URL(string: baseURL + "/cancel/" + currentTaskId) else {
            let error = EnhancementError.processingFailed("Cancellation failed: Invalid URL")
            pendingCancellationError = error
            await updateState(.failed(error), progress: progress)
            await invalidatePollingTimer(resumeWith: .failure(error))
            processingTask?.cancel()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnhancementError.processingFailed("Cancellation failed: Invalid response")
            }

            switch httpResponse.statusCode {
            case 200:
                pendingCancellationError = .cancelled
                await updateState(.cancelled, progress: 0.0)
                await invalidatePollingTimer(resumeWith: .failure(.cancelled))
            case 404:
                let error = EnhancementError.processingFailed("Task not found or already completed")
                pendingCancellationError = error
                await updateState(.failed(error), progress: progress)
                await invalidatePollingTimer(resumeWith: .failure(error))
            default:
                let error = EnhancementError.processingFailed("Cancellation failed with status code: \(httpResponse.statusCode)")
                pendingCancellationError = error
                await updateState(.failed(error), progress: progress)
                await invalidatePollingTimer(resumeWith: .failure(error))
            }
        } catch let enhancementError as EnhancementError {
            pendingCancellationError = enhancementError
            await updateState(.failed(enhancementError), progress: progress)
            await invalidatePollingTimer(resumeWith: .failure(enhancementError))
        } catch {
            let enhancementError = EnhancementError.processingFailed("Cancellation failed: \(error.localizedDescription)")
            pendingCancellationError = enhancementError
            await updateState(.failed(enhancementError), progress: progress)
            await invalidatePollingTimer(resumeWith: .failure(enhancementError))
        }

        currentTaskId = ""
        processingTask?.cancel()
    }
    
    func processVideo(at url: URL, with request: EnhancementRequest) async throws -> EnhancementResult {
        try await withCheckedThrowingContinuation { continuation in
            guard processingTask == nil else {
                continuation.resume(throwing: EnhancementError.processingFailed("Processing already in progress"))
                return
            }
            processingTask = Task { [weak self] in
                guard let self = self else { return }
                self.activeContinuation = continuation
                self.pendingCancellationError = nil
                self.currentTaskId = ""

                await self.updateState(.preparing, progress: 0.0)

                defer { self.processingTask = nil }

                do {
                    let (endpoint, includeLevel) = self.mapEndpoint(for: request.enhancementType.id)

                    // Determine which URL to upload: trimmed segment if provided, else original
                    let effectiveURL: URL
                    if let start = request.trimStartTime, let end = request.trimEndTime, end > start {
                        let quality = self.videoQualityFromOutputQuality(request.outputQuality)
                        effectiveURL = try await self.videoProcessingService.trimVideo(
                            at: url,
                            startTime: start,
                            endTime: end,
                            quality: quality
                        )
                    } else {
                        effectiveURL = url
                    }

                    try Task.checkCancellation()

                    try await self.uploadVideo(
                        videoURL: effectiveURL,
                        endpoint: endpoint,
                        includeLevel: includeLevel,
                        level: self.mapLevel(for: request)
                    )

                    try Task.checkCancellation()

                    await self.updateState(.processing(phase: .analysis), progress: 0.3)

                    // Start polling
                    try await self.pollUntilComplete(taskId: self.currentTaskId)

                    try Task.checkCancellation()

                    // Fetch result
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
                    self.currentTaskId = ""
                    self.pendingCancellationError = nil
                    self.completeProcessing(with: .success(result))
                } catch {
                    await self.handleProcessingFailure(error)
                }
            }
        }
    }
    
    // MARK: - Private helpers
    private func mapEndpoint(for enhancementId: String) -> (String, Bool) {
        switch enhancementId {
        case "ai_auto_enhancement":
            return ("/brightness", true) // brightness is auto enhancement
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
            return opt // low/medium/high
        case "frame_interpolation":
            return opt // smooth/fluid
        case "ai_upscale":
            // Align to backend expected values
            let mapped = opt.lowercased()
            if mapped == "1080p" || mapped == "1080" { return "1080" }
            if mapped == "2k" { return "2K" }
            if mapped == "4k" { return "4K" }
            return "1080" // default
        case "ai_color", "face_enhancer":
            return nil // backend doesn’t require level
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
    
    private func uploadVideo(videoURL: URL, endpoint: String, includeLevel: Bool, level: String?) async throws {
        guard let url = URL(string: baseURL + endpoint) else { throw EnhancementError.processingFailed("Invalid URL") }
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
        
        let (respData, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any]
        guard let taskId = json?["task_id"] as? String else {
            throw EnhancementError.processingFailed("Invalid response from server")
        }
        self.currentTaskId = taskId
    }
    
    private func pollUntilComplete(taskId: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.pollingContinuation = continuation
                self.processingState = .processing(phase: .enhancement)
                self.progress = max(self.progress, 0.3)

                self.pollTimer?.invalidate()
                self.pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                    guard let self = self else { return }
                    guard let url = URL(string: self.baseURL + "/progress/" + taskId) else { return }
                    URLSession.shared.dataTask(with: url) { data, response, _ in
                        DispatchQueue.main.async {
                            guard let data = data,
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                            let status = json["status"] as? String ?? ""
                            let prog = json["progress"] as? Double ?? 0.0
                            self.progress = prog
                            if status == "completed" {
                                self.invalidatePollingTimer(resumeWith: .success(()))
                            } else if status == "failed" {
                                let msg = json["error"] as? String ?? "Unknown error"
                                let error = EnhancementError.processingFailed(msg)
                                self.invalidatePollingTimer(resumeWith: .failure(error))
                            }
                        }
                    }.resume()
                }
            }
        }
    }
    
    private func fetchResult(taskId: String) async throws -> (URL, URL?) {
        guard let url = URL(string: baseURL + "/result/" + taskId) else { throw EnhancementError.processingFailed("Bad result URL") }
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
        guard let processedURL = json?["processed_url"] else { throw EnhancementError.processingFailed("No processed_url") }
        let originalURL = json?["original_url"]
        
        let processedLocal = try await downloadToDocuments(from: processedURL, prefix: "enhanced_video")
        var originalLocal: URL? = nil
        if let originalURL = originalURL {
            originalLocal = try? await downloadToDocuments(from: originalURL, prefix: "original_video")
        }
        return (processedLocal, originalLocal)
    }

    private func downloadToDocuments(from path: String, prefix: String) async throws -> URL {
        guard let url = URL(string: baseURL + path) else { throw EnhancementError.processingFailed("Bad download URL") }
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(prefix)_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.moveItem(at: tempURL, to: destURL)
        return destURL
    }

    private func completeProcessing(with result: Result<EnhancementResult, Error>) {
        guard let continuation = activeContinuation else { return }
        activeContinuation = nil
        switch result {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func resumePollingContinuation(with result: Result<Void, EnhancementError>) {
        guard let continuation = pollingContinuation else { return }
        pollingContinuation = nil
        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    @MainActor
    private func invalidatePollingTimer(resumeWith result: Result<Void, EnhancementError>? = nil) {
        pollTimer?.invalidate()
        pollTimer = nil
        if let result {
            resumePollingContinuation(with: result)
        }
    }

    private func handleProcessingFailure(_ error: Error) async {
        let resolvedError: EnhancementError

        if let pending = pendingCancellationError {
            resolvedError = pending
        } else if error is CancellationError {
            resolvedError = .cancelled
        } else if let enhancementError = error as? EnhancementError {
            resolvedError = enhancementError
        } else {
            resolvedError = .processingFailed(error.localizedDescription)
        }

        let currentProgress = self.progress

        if case .cancelled = resolvedError {
            await updateState(.cancelled, progress: 0.0)
        } else {
            await updateState(.failed(resolvedError), progress: currentProgress)
        }

        await invalidatePollingTimer(resumeWith: .failure(resolvedError))

        currentTaskId = ""

        completeProcessing(with: .failure(resolvedError))
        pendingCancellationError = nil
    }
}
