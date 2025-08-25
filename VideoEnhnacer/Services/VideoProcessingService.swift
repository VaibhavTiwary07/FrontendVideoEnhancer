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
    
    // MARK: - VideoProcessingProtocol Implementation
    func getVideoInfo(from url: URL) async throws -> VideoInfo {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let asset = AVURLAsset(url: url)
                    
                    // Load required properties
                    Task {
                        do {
                            let duration = try await asset.load(.duration)
                            let tracks = try await asset.load(.tracks)
                            
                            guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
                                continuation.resume(throwing: VideoProcessingError.invalidFormat)
                                return
                            }
                            
                            let naturalSize = try await videoTrack.load(.naturalSize)
                            let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                            let estimatedDataRate = try await videoTrack.load(.estimatedDataRate)
                            
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
                    let asset = AVURLAsset(url: url)
                    Task {
                        do {
                            let isPlayable = try await asset.load(.isPlayable)
                            let duration = try await asset.load(.duration)
                            
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
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let asset = AVURLAsset(url: url)
                    
                    guard let exportSession = AVAssetExportSession(asset: asset, presetName: quality.exportPreset) else {
                        continuation.resume(throwing: VideoProcessingError.exportFailed("Could not create export session"))
                        return
                    }
                    
                    // Set time range
                    let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
                    let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
                    let timeRange = CMTimeRangeFromTimeToTime(start: startCMTime, end: endCMTime)
                    exportSession.timeRange = timeRange
                    
                    // Set output URL
                    let outputURL = self.generateOutputURL(for: url, suffix: "_trimmed")
                    exportSession.outputURL = outputURL
                    exportSession.outputFileType = .mp4
                    
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
    
    func generateThumbnails(for url: URL, count: Int, quality: ThumbnailQuality) async throws -> [UIImage] {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let asset = AVURLAsset(url: url)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = quality.size
                    
                    Task {
                        do {
                            let duration = try await asset.load(.duration)
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
                    let asset = AVURLAsset(url: url)
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
                    let asset = AVURLAsset(url: url)
                    
                    guard let exportSession = AVAssetExportSession(asset: asset, presetName: quality.exportPreset) else {
                        continuation.resume(throwing: VideoProcessingError.exportFailed("Could not create export session"))
                        return
                    }
                    
                    let outputURL = self.generateOutputURL(for: url, suffix: "_compressed")
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
                    let asset = AVURLAsset(url: url)
                    
                    guard let exportSession = AVAssetExportSession(asset: asset, presetName: quality.exportPreset) else {
                        continuation.resume(throwing: VideoProcessingError.exportFailed("Could not create export session"))
                        return
                    }
                    
                    let outputURL = self.generateOutputURL(for: url, suffix: "_converted", extension: format.fileExtension)
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