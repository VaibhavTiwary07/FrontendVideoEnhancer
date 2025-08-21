import Foundation
import AVFoundation

class VideoTrimmerManager {
    enum TrimError: Error {
        case exportFailed
    }

    func exportSegment(sourceURL: URL, startTime: Double, endTime: Double, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(TrimError.exportFailed))
            return
        }

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let duration = CMTime(seconds: endTime - startTime, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: start, duration: duration)
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(outputURL))
            case .failed, .cancelled:
                completion(.failure(exportSession.error ?? TrimError.exportFailed))
            default:
                break
            }
        }
    }
}

