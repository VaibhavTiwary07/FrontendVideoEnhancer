import Foundation
import AVFoundation
import UIKit
import Combine

// MARK: - Video Processing Protocol
/// Defines the contract for video processing operations following Single Responsibility Principle
protocol VideoProcessingProtocol: AnyObject {
    // MARK: - Video Information
    func getVideoInfo(from url: URL) async throws -> VideoInfo
    func validateVideoFile(at url: URL) async throws -> Bool
    
    // MARK: - Trimming Operations
    func trimVideo(
        at url: URL,
        startTime: Double,
        endTime: Double,
        quality: VideoQuality
    ) async throws -> URL
    
    // MARK: - Thumbnail Generation
    func generateThumbnails(
        for url: URL,
        count: Int,
        quality: ThumbnailQuality
    ) async throws -> [UIImage]
    
    func generateThumbnail(
        for url: URL,
        at time: Double,
        quality: ThumbnailQuality
    ) async throws -> UIImage
    
    // MARK: - Video Compression
    func compressVideo(
        at url: URL,
        quality: VideoQuality,
        progress: @escaping (Double) -> Void
    ) async throws -> URL
    
    // MARK: - Format Conversion
    func convertVideoFormat(
        at url: URL,
        to format: VideoFormat,
        quality: VideoQuality
    ) async throws -> URL
}

// MARK: - Video Info
struct VideoInfo {
    let url: URL
    let duration: TimeInterval
    let dimensions: CGSize
    let frameRate: Float
    let bitRate: Double
    let format: String
    let fileSize: Int64
    let hasAudio: Bool
    let metadata: [String: Any]
    
    var aspectRatio: Double {
        dimensions.width / dimensions.height
    }
    
    var isValidForProcessing: Bool {
        duration > 0 && dimensions.width > 0 && dimensions.height > 0
    }
}

// MARK: - Video Quality
enum VideoQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case original = "original"
    
    var displayName: String {
        switch self {
        case .low: return "Low (360p)"
        case .medium: return "Medium (720p)"
        case .high: return "High (1080p)"
        case .original: return "Original"
        }
    }
    
    var exportPreset: String {
        switch self {
        case .low: return AVAssetExportPresetLowQuality
        case .medium: return AVAssetExportPresetMediumQuality
        case .high: return AVAssetExportPresetHighestQuality
        case .original: return AVAssetExportPresetPassthrough
        }
    }
}

// MARK: - Thumbnail Quality
enum ThumbnailQuality {
    case low
    case medium
    case high
    
    var size: CGSize {
        switch self {
        case .low: return CGSize(width: 120, height: 68)
        case .medium: return CGSize(width: 240, height: 135)
        case .high: return CGSize(width: 480, height: 270)
        }
    }
}

// MARK: - Video Format
enum VideoFormat: String, CaseIterable {
    case mp4 = "mp4"
    case mov = "mov"
    case m4v = "m4v"
    
    var displayName: String {
        rawValue.uppercased()
    }
    
    var fileExtension: String {
        rawValue
    }
    
    var avFileType: AVFileType {
        switch self {
        case .mp4, .m4v: return .mp4
        case .mov: return .mov
        }
    }
}

// MARK: - Video Processing Error
enum VideoProcessingError: Error, LocalizedError {
    case fileNotFound
    case invalidFormat
    case processingFailed(String)
    case exportFailed(String)
    case invalidTimeRange
    case insufficientStorage
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Video file not found"
        case .invalidFormat:
            return "Unsupported video format"
        case .processingFailed(let reason):
            return "Video processing failed: \(reason)"
        case .exportFailed(let reason):
            return "Video export failed: \(reason)"
        case .invalidTimeRange:
            return "Invalid time range for trimming"
        case .insufficientStorage:
            return "Insufficient storage space"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
}