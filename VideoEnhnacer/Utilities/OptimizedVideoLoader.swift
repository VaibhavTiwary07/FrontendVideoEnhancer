import Foundation
import SwiftUI
import PhotosUI
import Photos
import AVFoundation

// MARK: - Video Loading Strategy Protocol (SOLID: Dependency Inversion)
@available(iOS 16.0, *)
protocol VideoLoadingStrategy {
    func loadVideo(from item: PhotosPickerItem) async throws -> VideoLoadResult
}

// MARK: - Video Load Result
struct VideoLoadResult {
    let url: URL
    let isTemporary: Bool
    let loadTime: TimeInterval
    let strategy: String
}

// MARK: - Performance Metrics
struct VideoLoadMetrics {
    let startTime: Date
    let endTime: Date
    let strategy: String
    let fileSize: Int64?

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    func log(context: String) {
        let size = fileSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "unknown"
        print("⚡️ [\(context)] Load completed in \(String(format: "%.2f", duration))s using \(strategy) (size: \(size))")
    }
}

// MARK: - Fast PHAsset Strategy (SOLID: Single Responsibility)
/// Fastest approach: Gets URL directly from PHAsset without copying
@available(iOS 16.0, *)
final class FastPHAssetStrategy: VideoLoadingStrategy {
    func loadVideo(from item: PhotosPickerItem) async throws -> VideoLoadResult {
        let startTime = Date()

        guard let identifier = item.itemIdentifier else {
            throw VideoLoadError.noIdentifier
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else {
            throw VideoLoadError.assetNotFound
        }

        // Get video URL directly without copying (FAST!)
        let url = try await getVideoURL(for: asset)

        return VideoLoadResult(
            url: url,
            isTemporary: false,
            loadTime: Date().timeIntervalSince(startTime),
            strategy: "FastPHAsset"
        )
    }

    private func getVideoURL(for asset: PHAsset) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .fastFormat // Fast format for immediate use
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(throwing: VideoLoadError.invalidAsset)
                    return
                }

                continuation.resume(returning: urlAsset.url)
            }
        }
    }
}

// MARK: - Transferable Strategy (SOLID: Single Responsibility)
/// Fallback for iCloud/simulator videos - copies file but optimized
@available(iOS 16.0, *)
final class TransferableStrategy: VideoLoadingStrategy {
    func loadVideo(from item: PhotosPickerItem) async throws -> VideoLoadResult {
        let startTime = Date()

        guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
            throw VideoLoadError.transferFailed
        }

        return VideoLoadResult(
            url: movie.url,
            isTemporary: true,
            loadTime: Date().timeIntervalSince(startTime),
            strategy: "Transferable"
        )
    }
}

// MARK: - Optimized Video Loader (SOLID: Open/Closed)
/// Main coordinator that tries fastest strategy first, falls back if needed
@available(iOS 16.0, *)
final class OptimizedVideoLoader {

    private let strategies: [VideoLoadingStrategy]

    init(strategies: [VideoLoadingStrategy]? = nil) {
        self.strategies = strategies ?? [
            FastPHAssetStrategy(),      // Try fast approach first
            TransferableStrategy()       // Fallback to transferable
        ]
    }

    /// Load video using fastest available strategy
    /// - Parameters:
    ///   - item: PhotosPickerItem from picker
    ///   - context: Context for logging
    /// - Returns: Video URL and metadata
    func loadVideo(from item: PhotosPickerItem, context: String) async throws -> VideoLoadResult {
        print("⚡️ [\(context)] Starting optimized video load...")

        var lastError: Error?

        // Try each strategy in order (fast → slow)
        for (index, strategy) in strategies.enumerated() {
            do {
                let result = try await strategy.loadVideo(from: item)

                VideoLoadMetrics(
                    startTime: Date().addingTimeInterval(-result.loadTime),
                    endTime: Date(),
                    strategy: result.strategy,
                    fileSize: try? FileManager.default.attributesOfItem(atPath: result.url.path)[.size] as? Int64
                ).log(context: context)

                return result
            } catch {
                lastError = error
                print("⚠️ [\(context)] Strategy \(index + 1) failed: \(error.localizedDescription)")

                if index < strategies.count - 1 {
                    print("🔄 [\(context)] Trying next strategy...")
                }
            }
        }

        throw lastError ?? VideoLoadError.allStrategiesFailed
    }
}

// MARK: - Video Loading Errors
enum VideoLoadError: LocalizedError {
    case noIdentifier
    case assetNotFound
    case invalidAsset
    case transferFailed
    case allStrategiesFailed

    var errorDescription: String? {
        switch self {
        case .noIdentifier: return "No item identifier available"
        case .assetNotFound: return "PHAsset not found"
        case .invalidAsset: return "Invalid AVAsset type"
        case .transferFailed: return "Transfer operation failed"
        case .allStrategiesFailed: return "All loading strategies failed"
        }
    }
}

// MARK: - PhotosPickerItem Extension (DRY)
@available(iOS 16.0, *)
extension PhotosPickerItem {

    /// Load video URL with optimized strategy
    /// - Parameter context: Context for logging (e.g., "ComparisonCard", "TrimmingView")
    /// - Returns: Video URL
    func loadVideoURLOptimized(context: String = "VideoSelection") async throws -> URL {
        let loader = OptimizedVideoLoader()
        let result = try await loader.loadVideo(from: self, context: context)
        return result.url
    }
}

// MARK: - Video Cache Manager (Performance Optimization)
@available(iOS 16.0, *)
final class VideoCacheManager {
    static let shared = VideoCacheManager()

    private let cache = NSCache<NSString, CachedVideoInfo>()
    private let maxCacheSize: Int64 = 500_000_000 // 500MB max cache

    private init() {
        cache.totalCostLimit = Int(maxCacheSize)
    }

    func cacheVideo(_ url: URL, for identifier: String) {
        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 else {
            return
        }

        let info = CachedVideoInfo(url: url, fileSize: fileSize)
        cache.setObject(info, forKey: identifier as NSString, cost: Int(fileSize))
    }

    func getCachedVideo(for identifier: String) -> URL? {
        return cache.object(forKey: identifier as NSString)?.url
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

final class CachedVideoInfo {
    let url: URL
    let fileSize: Int64
    let cachedAt: Date

    init(url: URL, fileSize: Int64) {
        self.url = url
        self.fileSize = fileSize
        self.cachedAt = Date()
    }
}
