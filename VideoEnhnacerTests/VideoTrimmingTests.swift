import XCTest
import SwiftUI
@testable import VideoEnhnacer
import AVFoundation

final class VideoTrimmingTests: XCTestCase {
    // Test that coordinator forwards seek and trim range updates
    func testCoordinatorForwardsPlayerCommands() {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("VideoEnhnacer/normal.mp4")
        let asset = AVAsset(url: url)
        class MockPlayerManager: VideoTrimmingPlayerManager {
            var lastSeek: Double?
            var lastTrim: (Double, Double)?
            init(url: URL) { super.init(videoURL: url) }
            override func seek(to time: Double) { lastSeek = time }
            override func setTrimRange(start: CMTime, end: CMTime) { lastTrim = (start.seconds, end.seconds) }
        }
        let mock = MockPlayerManager(url: url)
        var start = CMTime.zero
        var end = CMTime(seconds: 5, preferredTimescale: 600)
        var current: CMTime? = nil
        let trimmer = PryntTrimmerRepresentable(startTime: Binding(get: { start }, set: { start = $0 }),
                                                endTime: Binding(get: { end }, set: { end = $0 }),
                                                currentTime: Binding(get: { current }, set: { current = $0 }),
                                                asset: asset,
                                                thumbnails: [],
                                                playerManager: mock)
        let coordinator = PryntTrimmerRepresentable.Coordinator(parent: trimmer, playerManager: mock)
        let testTime = CMTime(seconds: 1, preferredTimescale: 600)
        coordinator.didChangePositionBar(testTime)
        XCTAssertEqual(mock.lastSeek, 1, accuracy: 0.01)
        coordinator.positionBarStoppedMoving(testTime)
        XCTAssertEqual(mock.lastSeek, 1, accuracy: 0.01)
        let endTime = CMTime(seconds: 3, preferredTimescale: 600)
        coordinator.trimmerDidChange(startTime: testTime, endTime: endTime)
        XCTAssertEqual(mock.lastTrim?.0, 1, accuracy: 0.01)
        XCTAssertEqual(mock.lastTrim?.1, 3, accuracy: 0.01)
    }

    // Test player loops to start after reaching end of trim range
    func testPlayerLoopsWithinTrimRange() throws {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("VideoEnhnacer/normal.mp4")
        let manager = VideoTrimmingPlayerManager(videoURL: url)
        manager.setupPlayer()
        // Wait briefly for player to be ready
        sleep(1)
        manager.setTrimRange(start: CMTime(seconds: 0, preferredTimescale: 600), end: CMTime(seconds: 1, preferredTimescale: 600))
        manager.seek(to: 1)
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: manager.player?.currentItem)
        XCTAssertEqual(manager.player?.currentTime().seconds ?? 0, 0, accuracy: 0.2)
    }

    // Test thumbnail generation returns correct count
    func testThumbnailGenerationCount() async throws {
        let service = VideoProcessingService()
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("VideoEnhnacer/normal.mp4")
        let thumbnails = try await service.generateThumbnails(for: url, count: 3, quality: .low)
        XCTAssertEqual(thumbnails.count, 3)
    }
}
