import SwiftUI

struct VideoTrimmingSlider: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    let duration: Double
    let gradientType: GradientType
    
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var isDraggingWindow = false
    @State private var dragOffset: CGFloat = 0
    
    private let handleWidth: CGFloat = 20
    private let minTrimDuration: Double = 5 // Minimum 5 seconds
    
    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - handleWidth
            let startPosition = CGFloat(startTime / duration) * trackWidth
            let endPosition = CGFloat(endTime / duration) * trackWidth
            let windowWidth = endPosition - startPosition
            
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 40)
                
                // Video timeline preview (optional - can add thumbnail frames here)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 40)
                
                // Selection window
                RoundedRectangle(cornerRadius: 8)
                    .fill(gradientType.base.opacity(0.3))
                    .frame(width: windowWidth, height: 40)
                    .offset(x: startPosition)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(gradientType.base, lineWidth: 2)
                            .frame(width: windowWidth, height: 40)
                            .offset(x: startPosition)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDraggingStart && !isDraggingEnd {
                                    isDraggingWindow = true
                                    let newStartPosition = max(0, min(trackWidth - windowWidth, startPosition + value.translation.width))
                                    let newStartTime = Double(newStartPosition / trackWidth) * duration
                                    let windowDuration = endTime - startTime
                                    
                                    startTime = newStartTime
                                    endTime = min(duration, newStartTime + windowDuration)
                                }
                            }
                            .onEnded { _ in
                                isDraggingWindow = false
                            }
                    )
                
                // Start handle
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .frame(width: handleWidth, height: 40)
                    .offset(x: startPosition)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(gradientType.base, lineWidth: 2)
                            .frame(width: handleWidth, height: 40)
                            .offset(x: startPosition)
                    )
                    .overlay(
                        // Handle grip lines
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(gradientType.base)
                                    .frame(width: 8, height: 2)
                            }
                        }
                        .offset(x: startPosition)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingStart = true
                                let newPosition = max(0, min(endPosition - CGFloat(minTrimDuration / duration) * trackWidth, startPosition + value.translation.width))
                                startTime = Double(newPosition / trackWidth) * duration
                            }
                            .onEnded { _ in
                                isDraggingStart = false
                            }
                    )
                
                // End handle
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .frame(width: handleWidth, height: 40)
                    .offset(x: endPosition)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(gradientType.base, lineWidth: 2)
                            .frame(width: handleWidth, height: 40)
                            .offset(x: endPosition)
                    )
                    .overlay(
                        // Handle grip lines
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(gradientType.base)
                                    .frame(width: 8, height: 2)
                            }
                        }
                        .offset(x: endPosition)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingEnd = true
                                let newPosition = min(trackWidth, max(startPosition + CGFloat(minTrimDuration / duration) * trackWidth, endPosition + value.translation.width))
                                endTime = Double(newPosition / trackWidth) * duration
                            }
                            .onEnded { _ in
                                isDraggingEnd = false
                            }
                    )
                
                // Time labels
                VStack {
                    Spacer()
                    HStack {
                        Text(formatTime(startTime))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .offset(x: startPosition)
                        
                        Spacer()
                        
                        Text(formatTime(endTime))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .offset(x: endPosition - 40) // Offset to align with handle
                    }
                }
                .padding(.top, 45)
            }
        }
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
            gradientType: .redPink
        )
        .frame(height: 80)
        .padding()
        
        VideoTrimmingSlider(
            startTime: .constant(0),
            endTime: .constant(30),
            duration: 60,
            gradientType: .purpleGray
        )
        .frame(height: 80)
        .padding()
    }
    .background(Color.black)
}