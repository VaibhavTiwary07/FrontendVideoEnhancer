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

    /// Load video URL from PhotosPickerItem with optimized strategy selection
    /// - Parameter context: Context string for logging (e.g., "Comparison", "Trimming")
    /// - Returns: URL to the video file
    /// - Throws: Errors from video loading operations
    ///
    /// OPTIMIZED APPROACH:
    /// 1. Try FastPHAsset strategy (direct AVAsset URL - FASTEST, no copying)
    /// 2. Fallback to Transferable (copies file - slower but works for iCloud/simulator)
    ///
    /// Performance: FastPHAsset is 10-50x faster than copying for local videos
    func loadVideoURL(context: String = "VideoSelection") async throws -> URL? {
        let startTime = Date()
        print("⚡️ [\(context)] Starting optimized video load...")

        // Try optimized loader first (uses strategies pattern)
        let loader = OptimizedVideoLoader()
        do {
            let url = try await loader.loadVideoURLOptimized(context: context)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ [\(context)] Loaded in \(String(format: "%.2f", elapsed))s")
            return url
        } catch {
            print("❌ [\(context)] Optimized load failed: \(error.localizedDescription)")
            throw error
        }
    }
}
