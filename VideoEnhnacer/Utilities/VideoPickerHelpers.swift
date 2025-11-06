import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Photos

// MARK: - Movie Transferable
/// Transferable type for importing videos from PhotosPicker
/// Handles video import when PhotosPickerItem.itemIdentifier is unavailable
@available(iOS 16.0, *)
struct MovieTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let originalFile = received.file

            // Copy to temporary directory with unique name
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("imported_video_\(UUID().uuidString).mov")

            try FileManager.default.copyItem(at: originalFile, to: tempURL)

            print("🎥 [VideoPickerHelpers] Imported video to: \(tempURL.lastPathComponent)")

            return Self(url: tempURL)
        }
    }
}

// MARK: - PhotosPickerItem Extensions
@available(iOS 16.0, *)
extension PhotosPickerItem {

    /// Load video URL from PhotosPickerItem with automatic fallback
    /// - Parameter context: Context string for logging (e.g., "Comparison", "Trimming")
    /// - Returns: URL to the video file
    /// - Throws: Errors from PHAsset or loadTransferable operations
    ///
    /// Uses a two-pronged approach:
    /// 1. Try itemIdentifier + PHAsset (fast, works for most local videos)
    /// 2. Fallback to loadTransferable (slower, works for ALL videos including iCloud)
    func loadVideoURL(context: String = "VideoSelection") async throws -> URL? {
        print("🎥 [\(context)] Starting video load...")

        // APPROACH 1: Try using itemIdentifier (fast path for local videos)
        if let identifier = self.itemIdentifier {
            print("🎥 [\(context)] Has itemIdentifier: \(identifier)")

            let assets = PHAsset.fetchAssets(
                withLocalIdentifiers: [identifier],
                options: nil
            )

            if let asset = assets.firstObject {
                print("🎥 [\(context)] Found PHAsset, loading via resource manager...")
                do {
                    return try await loadVideoFromPHAsset(asset, context: context)
                } catch {
                    print("⚠️ [\(context)] PHAsset loading failed: \(error.localizedDescription)")
                    print("🔄 [\(context)] Falling back to loadTransferable...")
                }
            } else {
                print("⚠️ [\(context)] No PHAsset found for identifier")
            }
        } else {
            print("ℹ️ [\(context)] No itemIdentifier available")
        }

        // APPROACH 2: Fallback to loadTransferable (works for iCloud, recent videos, etc.)
        print("🎥 [\(context)] Using loadTransferable approach...")

        guard let movie = try await self.loadTransferable(type: MovieTransferable.self) else {
            print("❌ [\(context)] loadTransferable returned nil")
            return nil
        }

        print("✅ [\(context)] Successfully loaded via loadTransferable: \(movie.url.lastPathComponent)")
        return movie.url
    }

    /// Load video from PHAsset using resource manager
    private func loadVideoFromPHAsset(_ asset: PHAsset, context: String) async throws -> URL? {
        return try await withCheckedThrowingContinuation { continuation in
            let resources = PHAssetResource.assetResources(for: asset)

            guard let resource = resources.first(where: { $0.type == .video }) else {
                print("❌ [\(context)] No video resource found in PHAsset")
                continuation.resume(returning: nil)
                return
            }

            // Use temporary directory
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("video_\(UUID().uuidString).mov")

            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            print("📥 [\(context)] Downloading video data...")

            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: fileURL,
                options: options
            ) { error in
                if let error = error {
                    print("❌ [\(context)] Error writing video: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ [\(context)] Video saved: \(fileURL.lastPathComponent)")
                    continuation.resume(returning: fileURL)
                }
            }
        }
    }
}
