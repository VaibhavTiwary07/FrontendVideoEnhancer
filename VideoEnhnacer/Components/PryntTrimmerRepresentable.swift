import SwiftUI
import AVFoundation
import PryntTrimmerView

// MARK: - Enhanced PryntTrimmerView SwiftUI Wrapper
/// Complete implementation of PryntTrimmerView with full delegate support and customization
struct PryntTrimmerRepresentable: UIViewRepresentable {
    // MARK: - Bindings
    @Binding var startTime: CMTime
    @Binding var endTime: CMTime
    @Binding var currentTime: CMTime?
    
    // MARK: - Properties
    let asset: AVAsset
    let handleColor: UIColor
    let mainColor: UIColor
    let positionBarColor: UIColor
    let backgroundColor: UIColor
    
    // MARK: - Callbacks
    let onPositionChanged: ((CMTime) -> Void)?
    let onPositionStoppedMoving: ((CMTime) -> Void)?
    let onTrimChanged: ((CMTime, CMTime) -> Void)?
    let onEditingBegan: (() -> Void)?
    let onEditingEnded: (() -> Void)?
    
    // MARK: - Initialization
    init(
        startTime: Binding<CMTime>,
        endTime: Binding<CMTime>,
        currentTime: Binding<CMTime?> = .constant(nil),
        asset: AVAsset,
        handleColor: UIColor = .white,
        mainColor: UIColor = UIColor(red: 1.0, green: 0.596, blue: 0.329, alpha: 1.0), // Orange theme
        positionBarColor: UIColor = .white,
        backgroundColor: UIColor = .black,
        onPositionChanged: ((CMTime) -> Void)? = nil,
        onPositionStoppedMoving: ((CMTime) -> Void)? = nil,
        onTrimChanged: ((CMTime, CMTime) -> Void)? = nil,
        onEditingBegan: (() -> Void)? = nil,
        onEditingEnded: (() -> Void)? = nil
    ) {
        self._startTime = startTime
        self._endTime = endTime
        self._currentTime = currentTime
        self.asset = asset
        self.handleColor = handleColor
        self.mainColor = mainColor
        self.positionBarColor = positionBarColor
        self.backgroundColor = backgroundColor
        self.onPositionChanged = onPositionChanged
        self.onPositionStoppedMoving = onPositionStoppedMoving
        self.onTrimChanged = onTrimChanged
        self.onEditingBegan = onEditingBegan
        self.onEditingEnded = onEditingEnded
    }

    func makeUIView(context: Context) -> TrimmerView {
        let trimmer = TrimmerView()
        
        // Set asset and delegate
        trimmer.asset = asset
        trimmer.delegate = context.coordinator
        
        // Apply custom styling
        trimmer.handleColor = handleColor
        trimmer.mainColor = mainColor
        trimmer.positionBarColor = positionBarColor
        trimmer.backgroundColor = backgroundColor
        
        // Configure additional properties for better UX
        trimmer.showsRulerView = true
        trimmer.rulerLabelInterval = 5.0
        trimmer.maxLength = 60.0 // Max 60 seconds selection
        trimmer.minLength = 1.0  // Min 1 second selection
        
        return trimmer
    }

    func updateUIView(_ uiView: TrimmerView, context: Context) {
        // Update coordinator reference
        context.coordinator.parent = self
        
        // Update trimmer times if changed from outside
        if let currentTime = currentTime {
            context.coordinator.updatePositionBar(to: currentTime, in: uiView)
        }
        
        // Sync any external time changes
        context.coordinator.syncTimesFromParent(in: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    // MARK: - Coordinator with Full TrimmerViewDelegate Implementation
    class Coordinator: NSObject, TrimmerViewDelegate {
        var parent: PryntTrimmerRepresentable
        private var isUpdatingFromTrimmer = false

        init(parent: PryntTrimmerRepresentable) {
            self.parent = parent
            super.init()
        }
        
        // MARK: - TrimmerViewDelegate Methods
        
        func didChangePositionBar(_ playerTime: CMTime) {
            // Called when user scrubs the position bar
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.currentTime = playerTime
                self.parent.onPositionChanged?(playerTime)
                print("🎚️ PryntTrimmer - Position changed: \(playerTime.seconds)")
            }
        }
        
        func positionBarStoppedMoving(_ playerTime: CMTime) {
            // Called when user stops scrubbing
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.currentTime = playerTime
                self.parent.onPositionStoppedMoving?(playerTime)
                print("🎚️ PryntTrimmer - Position stopped at: \(playerTime.seconds)")
            }
        }
        
        func didBeginEditing() {
            // Called when user starts trimming
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.onEditingBegan?()
                print("✂️ PryntTrimmer - Began editing")
            }
        }
        
        func didEndEditing() {
            // Called when user stops trimming
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.onEditingEnded?()
                print("✂️ PryntTrimmer - Ended editing")
            }
        }
        
        func trimmerDidChange(startTime: CMTime, endTime: CMTime) {
            // Called when trim range changes
            guard !isUpdatingFromTrimmer else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isUpdatingFromTrimmer = true
                self.parent.startTime = startTime
                self.parent.endTime = endTime
                self.parent.onTrimChanged?(startTime, endTime)
                self.isUpdatingFromTrimmer = false
                print("✂️ PryntTrimmer - Trim changed: \(startTime.seconds) to \(endTime.seconds)")
            }
        }
        
        // MARK: - Helper Methods
        
        func updatePositionBar(to time: CMTime, in trimmerView: TrimmerView) {
            // Update position bar without triggering delegate callbacks
            trimmerView.seek(to: time)
        }
        
        func syncTimesFromParent(in trimmerView: TrimmerView) {
            // Sync external time changes to trimmer (avoiding infinite loops)
            guard !isUpdatingFromTrimmer else { return }
            
            let currentStartTime = trimmerView.startTime ?? .zero
            let currentEndTime = trimmerView.endTime ?? parent.asset.duration
            
            if !parent.startTime.isEqual(to: currentStartTime) || !parent.endTime.isEqual(to: currentEndTime) {
                // Update trimmer with external changes
                print("🔄 PryntTrimmer - Syncing external time changes")
                trimmerView.resetTimeRange()
                // Note: Direct time setting would require more complex position calculations
            }
        }
        
        // Legacy sync method for backward compatibility
        func syncTimes(from trimmer: TrimmerView) {
            parent.startTime = trimmer.startTime ?? .zero
            Task { @MainActor in
                do {
                    let duration = try await parent.asset.load(.duration)
                    parent.endTime = trimmer.endTime ?? duration
                } catch {
                    print("❌ Error loading asset duration: \(error)")
                }
            }
        }
    }
}
