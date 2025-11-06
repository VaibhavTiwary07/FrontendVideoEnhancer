import Foundation
import SwiftUI
import Photos
import AVFoundation

// MARK: - iOS 15 Video Loader
/// Simplified video loader for iOS 15 that works directly with PHAsset
/// This provides similar functionality to OptimizedVideoLoader but without iOS 16+ dependencies
@available(iOS 15.0, *)
final class iOS15VideoLoader {

    // MARK: - Video Load Result
    struct LoadResult {
        let url: URL
        let isTemporary: Bool
        let loadTime: TimeInterval
        let strategy: String
    }

    // MARK: - Errors
    enum LoadError: LocalizedError {
        case assetNotFound
        case invalidAsset
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .assetNotFound: return "Video asset not found"
            case .invalidAsset: return "Invalid video asset"
            case .exportFailed: return "Failed to export video"
            }
        }
    }

    // MARK: - Load from PHAsset
    /// Load video directly from PHAsset (iOS 15 compatible)
    /// - Parameters:
    ///   - asset: PHAsset from Photos library
    ///   - context: Context for logging
    /// - Returns: Video URL and metadata
    func loadVideo(from asset: PHAsset, context: String) async throws -> LoadResult {
        let startTime = Date()
        print("📱 [\(context)] Loading video for iOS 15...")

        guard asset.mediaType == .video else {
            throw LoadError.invalidAsset
        }

        // Try fast method first - get URL directly
        do {
            let url = try await getVideoURL(for: asset)
            let loadTime = Date().timeIntervalSince(startTime)

            logMetrics(
                context: context,
                duration: loadTime,
                strategy: "DirectURL",
                url: url
            )

            return LoadResult(
                url: url,
                isTemporary: false,
                loadTime: loadTime,
                strategy: "DirectURL"
            )
        } catch {
            print("⚠️ [\(context)] Direct URL failed, trying export...")

            // Fallback: Export video to temporary location
            let url = try await exportVideo(asset: asset)
            let loadTime = Date().timeIntervalSince(startTime)

            logMetrics(
                context: context,
                duration: loadTime,
                strategy: "Export",
                url: url
            )

            return LoadResult(
                url: url,
                isTemporary: true,
                loadTime: loadTime,
                strategy: "Export"
            )
        }
    }

    // MARK: - Private Methods

    /// Get video URL directly from PHAsset without copying
    private func getVideoURL(for asset: PHAsset) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .fastFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(throwing: LoadError.invalidAsset)
                    return
                }

                continuation.resume(returning: urlAsset.url)
            }
        }
    }

    /// Export video to temporary directory as fallback
    private func exportVideo(asset: PHAsset) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestExportSession(
                forVideo: asset,
                options: options,
                exportPreset: AVAssetExportPresetPassthrough
            ) { exportSession, _ in
                guard let session = exportSession else {
                    continuation.resume(throwing: LoadError.exportFailed)
                    return
                }

                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("video_\(UUID().uuidString).mov")

                session.outputURL = outputURL
                session.outputFileType = .mov

                session.exportAsynchronously {
                    switch session.status {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .failed:
                        continuation.resume(throwing: session.error ?? LoadError.exportFailed)
                    case .cancelled:
                        continuation.resume(throwing: LoadError.exportFailed)
                    default:
                        continuation.resume(throwing: LoadError.exportFailed)
                    }
                }
            }
        }
    }

    /// Log performance metrics
    private func logMetrics(context: String, duration: TimeInterval, strategy: String, url: URL) {
        let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
        let sizeStr = size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "unknown"
        print("📱 [\(context)] Load completed in \(String(format: "%.2f", duration))s using \(strategy) (size: \(sizeStr))")
    }
}

// MARK: - Helper Extension
@available(iOS 15.0, *)
extension iOS15VideoLoader {
    /// Load video from asset identifier
    func loadVideo(from identifier: String, context: String) async throws -> LoadResult {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else {
            throw LoadError.assetNotFound
        }

        return try await loadVideo(from: asset, context: context)
    }
}
