import Foundation
import AVFoundation
import UIKit
import CoreImage

// MARK: - Video Processing Service
/// Concrete implementation of VideoProcessingProtocol following Single Responsibility Principle
final class VideoProcessingService: VideoProcessingProtocol {
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let processingQueue = DispatchQueue(label: "video.processing", qos: .userInitiated)
    
    // MARK: - iOS 15 Compatibility Helpers
    private func loadAssetProperty<T>(_ asset: AVAsset, property: AVAsyncProperty<AVAsset, T>) async throws -> T {
        if #available(iOS 16.0, *) {
            return try await asset.load(property)
        } else {
            // iOS 15 fallback - convert property to legacy key
            let key = propertyToLegacyKey(property)
            return try await withCheckedThrowingContinuation { continuation in
                asset.loadValuesAsynchronously(forKeys: [key]) {
                    var error: NSError?
                    let status = asset.statusOfValue(forKey: key, error: &error)
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if status == .loaded {
                        do {
                            let value = try self.extractPropertyValue(from: asset, key: key) as! T
                            continuation.resume(returning: value)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        continuation.resume(throwing: VideoProcessingError.processingFailed("Failed to load asset property"))
                    }
                }
            }
        }
    }
    
    private func loadTrackProperty<T>(_ track: AVAssetTrack, property: AVAsyncProperty<AVAssetTrack, T>) async throws -> T {
        if #available(iOS 16.0, *) {
            return try await track.load(property)
        } else {
            // iOS 15 fallback
            let key = trackPropertyToLegacyKey(property)
            return try await withCheckedThrowingContinuation { continuation in
                track.loadValuesAsynchronously(forKeys: [key]) {
                    var error: NSError?
                    let status = track.statusOfValue(forKey: key, error: &error)
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if status == .loaded {
                        do {
                            let value = try self.extractTrackPropertyValue(from: track, key: key) as! T
                            continuation.resume(returning: value)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        continuation.resume(throwing: VideoProcessingError.processingFailed("Failed to load asset property"))
                    }
                }
            }
        }
    }
    
    private func propertyToLegacyKey<T>(_ property: AVAsyncProperty<AVAsset, T>) -> String {
        // Map iOS 16+ properties to iOS 15 keys
        switch "\(property)" {
        case let str where str.contains("duration"):
            return "duration"
        case let str where str.contains("tracks"):
            return "tracks"
        case let str where str.contains("isPlayable"):
            return "playable"
        default:
            return "duration" // Default fallback
        }
    }
    
    private func trackPropertyToLegacyKey<T>(_ property: AVAsyncProperty<AVAssetTrack, T>) -> String {
        // Map iOS 16+ track properties to iOS 15 keys
        switch "\(property)" {
        case let str where str.contains("naturalSize"):
            return "naturalSize"
        case let str where str.contains("nominalFrameRate"):
            return "nominalFrameRate"
        case let str where str.contains("estimatedDataRate"):
            return "estimatedDataRate"
        default:
            return "naturalSize" // Default fallback
        }
    }
    
    private func extractPropertyValue(from asset: AVAsset, key: String) throws -> Any {
        switch key {
        case "duration":
            return asset.duration
        case "tracks":
            return asset.tracks
        case "playable":
            return asset.isPlayable
        default:
            throw VideoProcessingError.processingFailed("Unsupported property type")
        }
    }
    
    private func extractTrackPropertyValue(from track: AVAssetTrack, key: String) throws -> Any {
        switch key {
        case "naturalSize":
            return track.naturalSize
        case "nominalFrameRate":
            return track.nominalFrameRate
        case "estimatedDataRate":
            return track.estimatedDataRate
        default:
            throw VideoProcessingError.processingFailed("Unsupported property type")
        }
    }
    
    // MARK: - VideoProcessingProtocol Implementation
    func getVideoInfo(from url: URL) async throws -> VideoInfo {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    // Use preferPreciseDurationAndTiming for accurate video info on all devices
                    let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
                    let asset = AVURLAsset(url: url, options: assetOptions)
                    
                    // Load required properties
                    Task {
                        do {
                            let duration = try await self.loadAssetProperty(asset, property: .duration)
                            let tracks = try await self.loadAssetProperty(asset, property: .tracks)
                            
                            guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
                                continuation.resume(throwing: VideoProcessingError.invalidFormat)
                                return
                            }
                            
                            let naturalSize = try await self.loadTrackProperty(videoTrack, property: .naturalSize)
                            let nominalFrameRate = try await self.loadTrackProperty(videoTrack, property: .nominalFrameRate)
                            let estimatedDataRate = try await self.loadTrackProperty(videoTrack, property: .estimatedDataRate)
                            
                            // Get file attributes
                            let attributes = try self.fileManager.attributesOfItem(atPath: url.path)
                            let fileSize = attributes[.size] as? Int64 ?? 0
                            
                            // Check for audio track
                            let hasAudio = tracks.contains { $0.mediaType == .audio }
                            
                            let videoInfo = VideoInfo(
                                url: url,
                                duration: CMTimeGetSeconds(duration),
                                dimensions: naturalSize,
                                frameRate: nominalFrameRate,
                                bitRate: Double(estimatedDataRate),
                                format: url.pathExtension.lowercased(),
                                fileSize: fileSize,
                                hasAudio: hasAudio,
                                metadata: [:]
                            )
                            
                            continuation.resume(returning: videoInfo)
                            
                        } catch {
                            continuation.resume(throwing: VideoProcessingError.processingFailed(error.localizedDescription))
                        }
                    }
                } catch {
                    continuation.resume(throwing: VideoProcessingError.processingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func validateVideoFile(at url: URL) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    // Check if file exists
                    guard self.fileManager.fileExists(atPath: url.path) else {
                        continuation.resume(returning: false)
                        return
                    }

                    // Check if it's a valid video file
                    let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
                    let asset = AVURLAsset(url: url, options: assetOptions)
                    Task {
                        do {
                            let isPlayable = try await self.loadAssetProperty(asset, property: .isPlayable)
                            let duration = try await self.loadAssetProperty(asset, property: .duration)
                            
                            let isValid = isPlayable && CMTimeGetSeconds(duration) > 0
                            continuation.resume(returning: isValid)
                        } catch {
                            continuation.resume(returning: false)
                        }
                    }
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func trimVideo(at url: URL, startTime: Double, endTime: Double, quality: VideoQuality) async throws -> URL {
        guard startTime < endTime else {
            throw VideoProcessingError.invalidTimeRange
        }

        TrimmingDiagnostics.log("🎬 [VideoProcessingService] trimVideo called: start=\(startTime)s end=\(endTime)s quality=\(quality)")
        TrimmingDiagnostics.log("📱 [VideoProcessingService] Device: \(UIDevice.current.model), iOS: \(UIDevice.current.systemVersion)")

        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    // CRITICAL FIX for iOS 15 / iPod Touch 7th gen:
                    // Use preferPreciseDurationAndTiming for accurate start time on older devices
                    let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
                    let asset = AVURLAsset(url: url, options: assetOptions)

                    TrimmingDiagnostics.log("✅ [VideoProcessingService] AVURLAsset created with preferPreciseDurationAndTiming=true")

                    guard let exportSession = AVAssetExportSession(asset: asset, presetName: quality.exportPreset) else {
                        continuation.resume(throwing: VideoProcessingError.exportFailed("Could not create export session"))
                        return
                    }

                    // Set time range - Use CMTimeRangeMake with start + duration for better iOS 15 compatibility
                    // iOS 15 on older devices (iPod Touch) has issues with CMTimeRangeFromTimeToTime
                    let timescale: CMTimeScale = 600 // Standard for video (600 = multiple of 24, 25, 30 fps)
                    let startCMTime = CMTime(seconds: startTime, preferredTimescale: timescale)
                    let durationCMTime = CMTime(seconds: endTime - startTime, preferredTimescale: timescale)
                    let timeRange = CMTimeRangeMake(start: startCMTime, duration: durationCMTime)

                    // Log the exact CMTime values for debugging iOS 15 issues
                    TrimmingDiagnostics.log("⏱️ [VideoProcessingService] CMTime details:")
                    TrimmingDiagnostics.log("   Start: \(startTime)s → CMTime(\(startCMTime.value)/\(startCMTime.timescale)) = \(CMTimeGetSeconds(startCMTime))s")
                    TrimmingDiagnostics.log("   Duration: \(endTime - startTime)s → CMTime(\(durationCMTime.value)/\(durationCMTime.timescale)) = \(CMTimeGetSeconds(durationCMTime))s")
                    TrimmingDiagnostics.log("   End (calculated): \(CMTimeGetSeconds(CMTimeAdd(startCMTime, durationCMTime)))s")
                    TrimmingDiagnostics.log("   TimeRange valid: \(CMTIMERANGE_IS_VALID(timeRange)), empty: \(CMTIMERANGE_IS_EMPTY(timeRange))")

                    exportSession.timeRange = timeRange
                    
                    // Set output URL
                    let outputURL = self.generateOutputURL(for: url, suffix: "_trimmed")
                    if self.fileManager.fileExists(atPath: outputURL.path) {
                        do {
                            try self.fileManager.removeItem(at: outputURL)
                        } catch {
                            continuation.resume(throwing: VideoProcessingError.exportFailed("Could not clear previous trimmed file"))
                            return
                        }
                    }
                    exportSession.outputURL = outputURL
                    exportSession.outputFileType = .mp4

                    exportSession.exportAsynchronously {
                        switch exportSession.status {
                        case .completed:
                            do {
                                let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                                let fileSize = (attrs[.size] as? NSNumber)?.doubleValue ?? 0
                                let fileSizeMB = fileSize / (1024.0 * 1024.0)
                                TrimmingDiagnostics.log("✅ [VideoProcessingService] Trim completed: outputURL=\(outputURL.lastPathComponent) size=\(String(format: "%.1f", fileSizeMB))MB")
                            } catch {
                                TrimmingDiagnostics.log("✅ [VideoProcessingService] Trim completed: outputURL=\(outputURL.lastPathComponent)")
                            }
                            continuation.resume(returning: outputURL)
                        case .failed:
                            let error = exportSession.error?.localizedDescription ?? "Unknown export error"
                            continuation.resume(throwing: VideoProcessingError.exportFailed(error))
                        case .cancelled:
                            continuation.resume(throwing: VideoProcessingError.cancelled)
                        default:
                            continuation.resume(throwing: VideoProcessingError.exportFailed("Export failed with status: \(exportSession.status.rawValue)"))
                        }
                    }
                } catch {
                    continuation.resume(throwing: VideoProcessingError.processingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func generateThumbnails(for url: URL, count: Int, quality: ThumbnailQuality) async throws -> [UIImage] {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
                    let asset = AVURLAsset(url: url, options: assetOptions)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = quality.size
                    
                    Task {
                        do {
                            let duration = try await self.loadAssetProperty(asset, property: .duration)
                            let durationSeconds = CMTimeGetSeconds(duration)
                            
                            var times: [NSValue] = []
                            let increment = durationSeconds / Double(count)
                            
                            for i in 0..<count {
                                let time = CMTime(seconds: Double(i) * increment, preferredTimescale: 600)
                                times.append(NSValue(time: time))
                            }
                            
                            var images: [UIImage] = []
                            
                            for timeValue in times {
                                do {
                                    let cgImage = try generator.copyCGImage(at: timeValue.timeValue, actualTime: nil)
                                    let image = UIImage(cgImage: cgImage)
                                    images.append(image)
                                } catch {
                                    print("Failed to generate thumbnail at time \(timeValue): \(error)")
                                    // Continue with other thumbnails
                                }
                            }
                            
                            continuation.resume(returning: images)
                            
                        } catch {
                            continuation.resume(throwing: VideoProcessingError.processingFailed(error.localizedDescription))
                        }
                    }
                } catch {
                    continuation.resume(throwing: VideoProcessingError.processingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func generateThumbnail(for url: URL, at time: Double, quality: ThumbnailQuality) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
                    let asset = AVURLAsset(url: url, options: assetOptions)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = quality.size
                    
                    let cmTime = CMTime(seconds: time, preferredTimescale: 600)
                    
                    do {
                        let cgImage = try generator.copyCGImage(at: cmTime, actualTime: nil)
                        let image = UIImage(cgImage: cgImage)
                        continuation.resume(returning: image)
                    } catch {
                        continuation.resume(throwing: VideoProcessingError.processingFailed(error.localizedDescription))
                    }
                } catch {
                    continuation.resume(throwing: VideoProcessingError.processingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func compressVideo(at url: URL, quality: VideoQuality, progress: @escaping (Double) -> Void) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
                    let asset = AVURLAsset(url: url, options: assetOptions)
                    
                    guard let exportSession = AVAssetExportSession(asset: asset, presetName: quality.exportPreset) else {
                        continuation.resume(throwing: VideoProcessingError.exportFailed("Could not create export session"))
                        return
                    }
                    
                    let outputURL = self.generateOutputURL(for: url, suffix: "_compressed")
                    if self.fileManager.fileExists(atPath: outputURL.path) {
                        do {
                            try self.fileManager.removeItem(at: outputURL)
                        } catch {
                            continuation.resume(throwing: VideoProcessingError.exportFailed("Could not clear previous compressed file"))
                            return
                        }
                    }
                    exportSession.outputURL = outputURL
                    exportSession.outputFileType = .mp4
                    
                    // Monitor progress
                    let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                        DispatchQueue.main.async {
                            progress(Double(exportSession.progress))
                        }
                    }
                    
                    exportSession.exportAsynchronously {
                        progressTimer.invalidate()
                        
                        switch exportSession.status {
                        case .completed:
                            DispatchQueue.main.async {
                                progress(1.0)
                            }
                            continuation.resume(returning: outputURL)
                        case .failed:
                            let error = exportSession.error?.localizedDescription ?? "Unknown export error"
                            continuation.resume(throwing: VideoProcessingError.exportFailed(error))
                        case .cancelled:
                            continuation.resume(throwing: VideoProcessingError.cancelled)
                        default:
                            continuation.resume(throwing: VideoProcessingError.exportFailed("Export failed with status: \(exportSession.status.rawValue)"))
                        }
                    }
                } catch {
                    continuation.resume(throwing: VideoProcessingError.processingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func convertVideoFormat(at url: URL, to format: VideoFormat, quality: VideoQuality) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
                    let asset = AVURLAsset(url: url, options: assetOptions)
                    
                    guard let exportSession = AVAssetExportSession(asset: asset, presetName: quality.exportPreset) else {
                        continuation.resume(throwing: VideoProcessingError.exportFailed("Could not create export session"))
                        return
                    }

                    let outputURL = self.generateOutputURL(for: url, suffix: "_converted", extension: format.fileExtension)
                    if self.fileManager.fileExists(atPath: outputURL.path) {
                        do {
                            try self.fileManager.removeItem(at: outputURL)
                        } catch {
                            continuation.resume(throwing: VideoProcessingError.exportFailed("Could not clear previous converted file"))
                            return
                        }
                    }
                    exportSession.outputURL = outputURL
                    exportSession.outputFileType = format.avFileType
                    
                    exportSession.exportAsynchronously {
                        switch exportSession.status {
                        case .completed:
                            continuation.resume(returning: outputURL)
                        case .failed:
                            let error = exportSession.error?.localizedDescription ?? "Unknown export error"
                            continuation.resume(throwing: VideoProcessingError.exportFailed(error))
                        case .cancelled:
                            continuation.resume(throwing: VideoProcessingError.cancelled)
                        default:
                            continuation.resume(throwing: VideoProcessingError.exportFailed("Export failed with status: \(exportSession.status.rawValue)"))
                        }
                    }
                } catch {
                    continuation.resume(throwing: VideoProcessingError.processingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    private func generateOutputURL(for inputURL: URL, suffix: String, extension: String? = nil) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        let fileExtension = `extension` ?? inputURL.pathExtension
        let outputFileName = "\(fileName)\(suffix).\(fileExtension)"
        
        return documentsDirectory.appendingPathComponent(outputFileName)
    }
    
    private func checkAvailableStorage() throws {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw VideoProcessingError.insufficientStorage
        }
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentsDirectory.path)
            if let freeSpace = attributes[.systemFreeSize] as? NSNumber {
                let freeSpaceInBytes = freeSpace.int64Value
                let minimumRequiredSpace: Int64 = 100 * 1024 * 1024 // 100 MB
                
                if freeSpaceInBytes < minimumRequiredSpace {
                    throw VideoProcessingError.insufficientStorage
                }
            }
        } catch {
            throw VideoProcessingError.insufficientStorage
        }
    }
}
