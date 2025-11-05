import SwiftUI
import AVFoundation
import UIKit

struct VideoTrimmingSlider: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    let duration: Double
    let presetDuration: Double
    let gradientType: GradientType
    let thumbnails: [UIImage]

    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var isDraggingWindow = false
    @State private var hapticTimer: Timer?
    @State private var initialStartPosition: CGFloat = 0
    @State private var initialEndPosition: CGFloat = 0
    @State private var initialWindowPosition: CGFloat = 0

    private let handleWidth: CGFloat = 24
    private let trackHeight: CGFloat = 50
    private let cornerRadius: CGFloat = 12
    private let minDuration: Double = 1.0 // Minimum 1 second trim duration

    var body: some View {
        GeometryReader { geometry in
            // Safety check for geometry and duration to prevent crashes
            if geometry.size.width > 0 && geometry.size.height > 0 && 
               !geometry.size.width.isNaN && !geometry.size.height.isNaN && 
               duration > 0 {
                
                let trackWidth = max(handleWidth, geometry.size.width - handleWidth)
                let startPosition = max(0, min(trackWidth, CGFloat(startTime / duration) * trackWidth))
                let endPosition = max(startPosition + 10, min(trackWidth, CGFloat(endTime / duration) * trackWidth))
                let windowWidth = max(10, endPosition - startPosition)

                ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.3))
                    .frame(height: trackHeight)
                    .overlay(
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: max(10, geo.size.width / CGFloat(max(thumbnails.count, 1))), height: trackHeight)
                                        .clipped()
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: startPosition, height: trackHeight)
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: trackWidth - endPosition, height: trackHeight)
                    .offset(x: endPosition)

                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.47, blue: 0.47).opacity(0.2),
                                Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: windowWidth, height: trackHeight)
                    .offset(x: startPosition)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient.primaryTheme.opacity(0.8),
                                lineWidth: 2
                            )
                            .frame(width: windowWidth, height: trackHeight)
                            .offset(x: startPosition)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDraggingWindow {
                                    isDraggingWindow = true
                                    initialWindowPosition = startPosition // Store initial window position
                                    TrimmingDiagnostics.log("↔️ [VideoTrimmingSlider] Started dragging trim window")
                                }
                                let newStart = max(0, min(trackWidth - windowWidth, initialWindowPosition + value.translation.width))
                                let newTime = Double(newStart / trackWidth) * duration
                                let windowDuration = endTime - startTime
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                    startTime = newTime
                                    endTime = min(newTime + windowDuration, duration)
                                }
                            }
                            .onEnded { _ in
                                TrimmingDiagnostics.log("↔️ [VideoTrimmingSlider] Finished dragging window - start: \(startTime)s, end: \(endTime)s, duration: \(endTime - startTime)s")
                                isDraggingWindow = false
                            }
                    )

                appleStyleHandle(position: startPosition, isDragging: isDraggingStart)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDraggingStart {
                                    isDraggingStart = true
                                    initialStartPosition = startPosition // Store initial position
                                    startHapticFeedback()
                                    TrimmingDiagnostics.log("◀️ [VideoTrimmingSlider] Started dragging start handle")
                                }
                                // Use initial position + translation to avoid circular reference
                                let maxStart = CGFloat((endTime - minDuration) / duration) * trackWidth
                                let newStart = max(0, min(maxStart, initialStartPosition + value.translation.width))
                                let newTime = Double(newStart / trackWidth) * duration
                                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9)) {
                                    startTime = newTime
                                }
                            }
                            .onEnded { _ in
                                TrimmingDiagnostics.log("◀️ [VideoTrimmingSlider] Finished dragging start handle - startTime: \(startTime)s (duration: \(endTime - startTime)s)")
                                isDraggingStart = false
                                endHapticFeedback()
                            }
                    )

                // End Handle
                appleStyleHandle(position: endPosition, isDragging: isDraggingEnd)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDraggingEnd {
                                    isDraggingEnd = true
                                    initialEndPosition = endPosition // Store initial position
                                    startHapticFeedback()
                                    TrimmingDiagnostics.log("▶️ [VideoTrimmingSlider] Started dragging end handle")
                                }
                                // Use initial position + translation to avoid circular reference
                                let minEnd = CGFloat((startTime + minDuration) / duration) * trackWidth
                                let newEnd = max(minEnd, min(trackWidth, initialEndPosition + value.translation.width))
                                let newTime = Double(newEnd / trackWidth) * duration
                                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9)) {
                                    endTime = newTime
                                }
                            }
                            .onEnded { _ in
                                TrimmingDiagnostics.log("▶️ [VideoTrimmingSlider] Finished dragging end handle - endTime: \(endTime)s (duration: \(endTime - startTime)s)")
                                isDraggingEnd = false
                                endHapticFeedback()
                            }
                    )

                VStack {
                    Spacer()
                    HStack {
                        Text(formatTime(startTime))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.7))
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .offset(x: max(0, min(geometry.size.width.safeValue - 60, startPosition - 20)))

                        Spacer()

                        Text(formatTime(endTime))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.7))
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .offset(x: min(0, max(-geometry.size.width.safeValue + 60, endPosition - geometry.size.width.safeValue + 20)))
                    }
                }
                .padding(.top, trackHeight + 8)
            }
            } else {
                // Fallback for invalid geometry
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: trackHeight)
                    .overlay(Text("Loading...").foregroundColor(.secondary))
            }
        }
        .frame(height: trackHeight + 30)
    }

    @ViewBuilder
    private func appleStyleHandle(position: CGFloat, isDragging: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.3))
                .frame(width: handleWidth, height: trackHeight)
                .offset(x: position + 1, y: 1)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: handleWidth, height: trackHeight)
                .offset(x: position)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(LinearGradient.primaryTheme, lineWidth: isDragging ? 3 : 2)
                        .frame(width: handleWidth, height: trackHeight)
                        .offset(x: position)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
            VStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.8))
                        .frame(width: 8, height: 1)
                }
            }
            .offset(x: position)
            .opacity(isDragging ? 0.8 : 0.5)
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.8))
                .offset(x: position)
                .offset(y: -15)
                .opacity(isDragging ? 0.8 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: isDragging)
        }
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }

    private func startHapticFeedback() {
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred(intensity: 0.5)
        }
    }

    private func endHapticFeedback() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    private func formatTime(_ timeInSeconds: Double) -> String {
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VStack(spacing: 40) {
        VideoTrimmingSlider(
            startTime: .constant(10),
            endTime: .constant(40),
            duration: 120,
            presetDuration: 30,
            gradientType: .redPink,
            thumbnails: []
        )
        .frame(height: 80)
        .padding()
    }
    .background(Color.black)
}
