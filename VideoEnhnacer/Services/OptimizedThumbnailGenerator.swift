import Foundation
import UIKit
import AVFoundation

// MARK: - Thumbnail Generator Protocol (SOLID: Dependency Inversion)
protocol ThumbnailGeneratorProtocol {
    func generateThumbnails(
        for videoURL: URL,
        count: Int,
        size: CGSize
    ) async -> [UIImage]
}

// MARK: - Optimized Thumbnail Generator
/// High-performance thumbnail generation with parallel processing
/// SOLID Principles: Single Responsibility, Open/Closed
final class OptimizedThumbnailGenerator: ThumbnailGeneratorProtocol {

    // MARK: - Configuration
    private struct Configuration {
        static let maxConcurrentGenerations = 4 // Optimal for most devices
        static let imageQuality: CGFloat = 0.7
        static let cacheEnabled = true
    }

    // MARK: - Cache
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 100 // Limit number of cached items
        cache.totalCostLimit = 50_000_000 // ~50MB
    }

    // MARK: - Public Methods
    func generateThumbnails(
        for videoURL: URL,
        count: Int,
        size: CGSize
    ) async -> [UIImage] {
        let startTime = Date()
        print("⚡️ [ThumbnailGen] Starting parallel generation of \(count) thumbnails...")

        let thumbnails = await generateThumbnailsInParallel(
            videoURL: videoURL,
            count: count,
            size: size
        )

        let elapsed = Date().timeIntervalSince(startTime)
        let avgTime = elapsed / Double(count)
        print("⚡️ [ThumbnailGen] Generated \(thumbnails.count)/\(count) thumbnails in \(String(format: "%.2f", elapsed))s (avg: \(String(format: "%.3f", avgTime))s/thumbnail)")

        return thumbnails
    }

    // MARK: - Private Methods
    private func generateThumbnailsInParallel(
        videoURL: URL,
        count: Int,
        size: CGSize
    ) async -> [UIImage] {
        let asset = AVAsset(url: videoURL)

        // Get duration first
        guard let duration = try? await asset.load(.duration) else {
            print("❌ [ThumbnailGen] Failed to load asset duration")
            return []
        }

        let durationSeconds = CMTimeGetSeconds(duration)

        // Calculate time points for thumbnails
        let timePoints = (0..<count).map { index in
            CMTime(
                seconds: durationSeconds * Double(index) / Double(max(count - 1, 1)),
                preferredTimescale: 600
            )
        }

        // Generate thumbnails in parallel with controlled concurrency
        return await withTaskGroup(of: (Int, UIImage?).self, returning: [UIImage].self) { group in
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = size
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            // Add tasks with concurrency control
            for (index, time) in timePoints.enumerated() {
                group.addTask {
                    await self.generateSingleThumbnail(
                        generator: generator,
                        time: time,
                        index: index,
                        videoURL: videoURL,
                        size: size
                    )
                }

                // Rate limiting: only start next batch after previous completes
                if (index + 1) % Configuration.maxConcurrentGenerations == 0 {
                    _ = await group.next() // Wait for one to complete before adding more
                }
            }

            // Collect all results
            var results: [(Int, UIImage?)] = []
            for await result in group {
                results.append(result)
            }

            // Sort by index and filter out nils
            return results
                .sorted { $0.0 < $1.0 }
                .compactMap { $0.1 }
        }
    }

    private func generateSingleThumbnail(
        generator: AVAssetImageGenerator,
        time: CMTime,
        index: Int,
        videoURL: URL,
        size: CGSize
    ) async -> (Int, UIImage?) {
        // Check cache first
        let cacheKey = "\(videoURL.lastPathComponent)_\(index)_\(Int(size.width))x\(Int(size.height))" as NSString

        if Configuration.cacheEnabled, let cachedImage = cache.object(forKey: cacheKey) {
            print("💾 [ThumbnailGen] Using cached thumbnail #\(index)")
            return (index, cachedImage)
        }

        // Generate new thumbnail
        do {
            let cgImage = try await generator.image(at: time).image
            let image = UIImage(cgImage: cgImage)

            // Cache the result
            if Configuration.cacheEnabled {
                cache.setObject(image, forKey: cacheKey)
            }

            return (index, image)
        } catch {
            print("⚠️ [ThumbnailGen] Failed to generate thumbnail #\(index): \(error.localizedDescription)")
            return (index, nil)
        }
    }

    // MARK: - Cache Management
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Progressive Thumbnail Generator
/// Generates thumbnails progressively and delivers them as they're ready
final class ProgressiveThumbnailGenerator {

    typealias ProgressCallback = (Int, UIImage, Int) -> Void // (index, image, total)

    private let generator: OptimizedThumbnailGenerator

    init() {
        self.generator = OptimizedThumbnailGenerator()
    }

    /// Generate thumbnails progressively, calling the progress callback for each one
    func generateThumbnails(
        for videoURL: URL,
        count: Int,
        size: CGSize,
        onProgress: @escaping ProgressCallback
    ) async {
        let asset = AVAsset(url: videoURL)

        guard let duration = try? await asset.load(.duration) else {
            return
        }

        let durationSeconds = CMTimeGetSeconds(duration)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = size

        // Generate and deliver progressively
        for index in 0..<count {
            let time = CMTime(
                seconds: durationSeconds * Double(index) / Double(max(count - 1, 1)),
                preferredTimescale: 600
            )

            do {
                let cgImage = try await imageGenerator.image(at: time).image
                let image = UIImage(cgImage: cgImage)

                // Deliver immediately
                onProgress(index, image, count)
            } catch {
                print("⚠️ [ProgressiveThumbnailGen] Failed thumbnail #\(index): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Thumbnail Configuration
struct ThumbnailConfiguration {
    let count: Int
    let size: CGSize
    let quality: ThumbnailQuality

    enum ThumbnailQuality {
        case low    // Fast generation, lower quality
        case medium // Balanced
        case high   // Slower generation, high quality

        var cgSize: CGSize {
            switch self {
            case .low: return CGSize(width: 80, height: 80)
            case .medium: return CGSize(width: 120, height: 120)
            case .high: return CGSize(width: 200, height: 200)
            }
        }
    }

    static var defaultConfig: ThumbnailConfiguration {
        ThumbnailConfiguration(
            count: DeviceSize.isSmallPhone ? 6 : 10,
            size: ThumbnailQuality.medium.cgSize,
            quality: .medium
        )
    }

    static var fastConfig: ThumbnailConfiguration {
        ThumbnailConfiguration(
            count: 6,
            size: ThumbnailQuality.low.cgSize,
            quality: .low
        )
    }
}
