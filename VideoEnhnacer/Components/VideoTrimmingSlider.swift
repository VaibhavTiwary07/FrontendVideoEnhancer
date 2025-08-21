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

    @State private var isDragging = false
    @State private var hapticTimer: Timer?

    private let trackHeight: CGFloat = 50
    private let cornerRadius: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            let windowWidth = CGFloat(presetDuration / duration) * trackWidth
            let maxStart = max(0, duration - presetDuration)
            let startPosition = CGFloat(startTime / duration) * trackWidth

            ZStack(alignment: .leading) {
                // Background track with thumbnails
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
                                        .frame(width: geo.size.width / CGFloat(max(thumbnails.count, 1)), height: trackHeight)
                                        .clipped()
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    )

                // Selection window
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
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(LinearGradient.primaryTheme.opacity(0.8), lineWidth: 2)
                    )
                    .offset(x: startPosition)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    startHapticFeedback()
                                }

                                let newPosition = min(max(0, startPosition + value.translation.width), trackWidth - windowWidth)
                                let newStart = Double(newPosition / trackWidth) * duration
                                startTime = min(newStart, maxStart)
                                endTime = min(startTime + presetDuration, duration)
                            }
                            .onEnded { _ in
                                isDragging = false
                                endHapticFeedback()
                            }
                    )

                // Time labels
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
                                        Capsule()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .offset(x: max(0, min(trackWidth - 60, startPosition - 20)))

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
                                        Capsule()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .offset(x: min(0, max(-trackWidth + 60, startPosition + windowWidth - trackWidth + 20)))
                    }
                }
                .frame(height: trackHeight)
            }
        }
        .frame(height: trackHeight)
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

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VideoTrimmingSlider(
        startTime: .constant(0),
        endTime: .constant(30),
        duration: 60,
        presetDuration: 30,
        gradientType: .redPink,
        thumbnails: []
    )
    .frame(height: 60)
    .padding()
    .background(Color.black)
}

