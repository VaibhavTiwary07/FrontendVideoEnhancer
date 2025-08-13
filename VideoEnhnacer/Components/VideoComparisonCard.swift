import SwiftUI

struct VideoComparisonCard: View {
    let title: String
    let subtitle: String
    let normalVideo: String
    let enhancedVideo: String
    @ObservedObject var videoPlayerManager: VideoPlayerManager
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with Icon and Title
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.square")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .primaryGradient()
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Spacer()
                }
                
                // Video Comparison Slider
                VideoComparisonSlider(
                    normalVideoName: normalVideo,
                    enhancedVideoName: enhancedVideo,
                    videoPlayerManager: videoPlayerManager
                )
                .frame(height: 140)
                
                // Call to Action
                HStack {
                    Spacer()
                    
                    Text("Tap to customize →")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondaryText.opacity(0.8))
                    
                    Spacer()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isPressed ? 
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.47, blue: 0.47).opacity(0.3),
                                    Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) : 
                            LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1
                        )
                )
                .neomorphicStyle(cornerRadius: 16, shadowRadius: 8)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .padding(.horizontal, 20)
    }
}

#Preview {
    VStack(spacing: 20) {
        VideoComparisonCard(
            title: "AI Upscale",
            subtitle: "See the difference in real-time",
            normalVideo: "normal",
            enhancedVideo: "enhanced",
            videoPlayerManager: VideoPlayerManager()
        ) {
            print("Video comparison card tapped")
        }
    }
    .background(Color.appBackground)
    .padding()
}