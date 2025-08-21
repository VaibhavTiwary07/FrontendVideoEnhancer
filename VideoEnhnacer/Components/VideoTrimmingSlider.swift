import SwiftUI
import AVFoundation
import UIKit

struct VideoTrimmingSlider: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    let duration: Double
    let gradientType: GradientType
    let thumbnails: [UIImage]
    
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var isDraggingWindow = false
    @State private var dragOffset: CGFloat = 0
    @State private var hapticTimer: Timer?
    
    private let handleWidth: CGFloat = 24 // Increased for better touch target
    private let trackHeight: CGFloat = 50 // Increased height for Apple-style look
    private let cornerRadius: CGFloat = 12
    private let minTrimDuration: Double = 1 // Reduced minimum duration
    
    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - handleWidth
            let startPosition = CGFloat(startTime / duration) * trackWidth
            let endPosition = CGFloat(endTime / duration) * trackWidth
            let windowWidth = max(handleWidth, endPosition - startPosition)
            
            ZStack(alignment: .leading) {
                // Background track with actual video thumbnails
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
                    .overlay(
                        // Subtle inner shadow for depth
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                // Selection window with smooth gradient
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
                        // Selection border
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient.primaryTheme.opacity(0.8),
                                lineWidth: 2
                            )
                            .frame(width: windowWidth, height: trackHeight)
                            .offset(x: startPosition)
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 2,
                                x: 0,
                                y: 1
                            )
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDraggingStart && !isDraggingEnd {
                                    isDraggingWindow = true
                                    addHapticFeedback()
                                    
                                    let newStartPosition = max(0, min(trackWidth - windowWidth, startPosition + value.translation.width))
                                    let newStartTime = Double(newStartPosition / trackWidth) * duration
                                    let windowDuration = endTime - startTime
                                    
                                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                        startTime = newStartTime
                                        endTime = min(duration, newStartTime + windowDuration)
                                    }
                                }
                            }
                            .onEnded { _ in
                                isDraggingWindow = false
                                endHapticFeedback()
                            }
                    )
                
                // Left handle with Apple-style design
                appleStyleHandle(
                    position: startPosition,
                    isDragging: isDraggingStart,
                    isLeft: true
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDraggingStart {
                                isDraggingStart = true
                                startHapticFeedback()
                            }
                            
                            let newPosition = max(0, min(endPosition - CGFloat(minTrimDuration / duration) * trackWidth, startPosition + value.translation.width))
                            
                            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9)) {
                                startTime = Double(newPosition / trackWidth) * duration
                            }
                        }
                        .onEnded { _ in
                            isDraggingStart = false
                            endHapticFeedback()
                        }
                )
                
                // Right handle with Apple-style design
                appleStyleHandle(
                    position: endPosition,
                    isDragging: isDraggingEnd,
                    isLeft: false
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDraggingEnd {
                                isDraggingEnd = true
                                startHapticFeedback()
                            }
                            
                            let newPosition = min(trackWidth, max(startPosition + CGFloat(minTrimDuration / duration) * trackWidth, endPosition + value.translation.width))
                            
                            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9)) {
                                endTime = Double(newPosition / trackWidth) * duration
                            }
                        }
                        .onEnded { _ in
                            isDraggingEnd = false
                            endHapticFeedback()
                        }
                )
                
                // Time indicators with smooth animations
                VStack {
                    Spacer()
                    
                    HStack {
                        // Start time
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
                            .offset(x: max(0, min(geometry.size.width - 60, startPosition - 20)))
                            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: startTime)
                        
                        Spacer()
                        
                        // End time
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
                            .offset(x: min(0, max(-geometry.size.width + 60, endPosition - geometry.size.width + 20)))
                            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: endTime)
                    }
                }
                .padding(.top, trackHeight + 8)
            }
        }
        .frame(height: trackHeight + 30) // Extra height for time labels
    }
    
    // MARK: - Apple-Style Handle Component
    @ViewBuilder
    private func appleStyleHandle(position: CGFloat, isDragging: Bool, isLeft: Bool) -> some View {
        ZStack {
            // Handle shadow
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.3))
                .frame(width: handleWidth, height: trackHeight)
                .offset(x: position + 1, y: 1)
            
            // Main handle body
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: handleWidth, height: trackHeight)
                .offset(x: position)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            LinearGradient.primaryTheme,
                            lineWidth: isDragging ? 3 : 2
                        )
                        .frame(width: handleWidth, height: trackHeight)
                        .offset(x: position)
                        .shadow(
                            color: Color.black.opacity(0.2),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                )
            
            // Handle grip indicator
            VStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.8))
                        .frame(width: 8, height: 1)
                }
            }
            .offset(x: position)
            .opacity(isDragging ? 0.8 : 0.5)
            
            // Directional arrow (left or right)
            Image(systemName: isLeft ? "chevron.left" : "chevron.right")
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
    
    // MARK: - Haptic Feedback Methods
    private func startHapticFeedback() {
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred(intensity: 0.5)
        }
    }
    
    private func addHapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred(intensity: 0.3)
    }
    
    private func endHapticFeedback() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        
        // Final confirmation haptic
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
            gradientType: .redPink,
            thumbnails: []
        )
        .frame(height: 80)
        .padding()
        
        VideoTrimmingSlider(
            startTime: .constant(0),
            endTime: .constant(30),
            duration: 60,
            gradientType: .purpleGray,
            thumbnails: []
        )
        .frame(height: 80)
        .padding()
    }
    .background(Color.black)
}