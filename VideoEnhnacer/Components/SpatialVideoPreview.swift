import SwiftUI
import AVFoundation
import AVKit

struct SpatialVideoPreview: View {
    let videoURL: URL
    let enhancementType: String
    @State private var scrollOffset: CGFloat = 0
    @StateObject private var playerManager = VideoPreviewManager()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var videoHeight: CGFloat {
        isIPad ? 350 : 280
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background depth layers
                BackgroundDepthLayers(scrollOffset: scrollOffset)
                
                // Main video preview with spatial effects
                VStack(spacing: 0) {
                    // Video container with depth
                    ZStack {
                        // Shadow layers for depth
                        ForEach(0..<3) { layer in
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.black.opacity(0.3 - Double(layer) * 0.1))
                                .frame(height: videoHeight)
                                .offset(
                                    x: CGFloat(layer) * 2,
                                    y: CGFloat(layer) * 2
                                )
                                .scaleEffect(1.0 - CGFloat(layer) * 0.02)
                        }
                        
                        // Main video layer
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.cardSoft)
                            .frame(height: videoHeight)
                            .overlay(
                                Group {
                                    if let player = playerManager.player {
                                        VideoPlayer(player: player)
                                            .disabled(true)
                                            .cornerRadius(24)
                                            .onAppear {
                                                player.play()
                                            }
                                    } else {
                                        VideoLoadingView()
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.accentWarm.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .rotation3DEffect(
                        .degrees(scrollOffset * 0.1),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.5
                    )
                    .scaleEffect(1.0 + (abs(scrollOffset) * 0.0002))
                    
                    // Contextual information overlay
                    ContextualInfoOverlay(
                        enhancementType: enhancementType,
                        scrollOffset: scrollOffset
                    )
                    .padding(.top, 20)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            setupVideo()
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
    
    private func setupVideo() {
        playerManager.setupPlayer(with: videoURL)
    }
}

struct BackgroundDepthLayers: View {
    let scrollOffset: CGFloat
    
    var body: some View {
        ZStack {
            // Distant background layer
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.interfaceSoft.opacity(0.3),
                            Color.primarySoft.opacity(0.1)
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 200
                    )
                )
                .scaleEffect(1.2)
                .offset(y: scrollOffset * 0.1)
                .blur(radius: 3)
            
            // Mid-ground layer
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.interfaceSoft.opacity(0.2))
                .scaleEffect(1.1)
                .offset(y: scrollOffset * 0.2)
                .blur(radius: 1)
        }
    }
}

struct VideoLoadingView: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.accentWarm.opacity(0.2), lineWidth: 3)
                    .frame(width: 48, height: 48)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.accentWarm, lineWidth: 3)
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotationAngle)
            }
            
            Text("Preparing Preview...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.accentWarm.opacity(0.8))
        }
        .onAppear {
            rotationAngle = 360
        }
    }
}

struct ContextualInfoOverlay: View {
    let enhancementType: String
    let scrollOffset: CGFloat
    
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Enhancement type indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.596, blue: 0.329))
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.2)
                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: showDetails)
                
                Text("Previewing with \(enhancementType)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.accentWarm.opacity(0.8))
                
                Spacer()
            }
            
            // Progressive disclosure details
            if showDetails {
                VStack(spacing: 12) {
                    PerformanceMetricsView(enhancementType: enhancementType)
                    QualityImpactView(enhancementType: enhancementType)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
            
            // Tap to reveal more info
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showDetails.toggle()
                }
                
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }) {
                HStack(spacing: 6) {
                    Text(showDetails ? "Hide Details" : "Show Enhancement Details")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.accentWarm.opacity(0.6))
                    
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.accentWarm.opacity(0.6))
                        .rotationEffect(.degrees(showDetails ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 4)
        .offset(y: scrollOffset * 0.05)
    }
}

struct PerformanceMetricsView: View {
    let enhancementType: String
    
    private var estimatedTime: String {
        switch enhancementType {
        case "AI Upscale": return "2-4 min"
        case "AI Denoise": return "1-2 min"
        case "AI Auto Enhancement": return "1-3 min"
        case "Stabilizer": return "30s-1 min"
        case "Frame Interpolation": return "3-5 min"
        default: return "1-3 min"
        }
    }
    
    private var qualityGain: String {
        switch enhancementType {
        case "AI Upscale": return "High"
        case "AI Denoise": return "Medium"
        case "AI Auto Enhancement": return "Medium-High"
        case "Stabilizer": return "Medium"
        case "Frame Interpolation": return "High"
        default: return "Medium"
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            MetricItem(
                icon: "clock",
                label: "Time",
                value: estimatedTime,
                color: Color.blue.opacity(0.8)
            )
            
            MetricItem(
                icon: "star.fill",
                label: "Quality Gain",
                value: qualityGain,
                color: Color(red: 1.0, green: 0.596, blue: 0.329)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.overlaySoft.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentWarm.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct QualityImpactView: View {
    let enhancementType: String
    
    private var impactLevel: Double {
        switch enhancementType {
        case "AI Upscale": return 0.9
        case "AI Denoise": return 0.7
        case "AI Auto Enhancement": return 0.8
        case "Stabilizer": return 0.6
        case "Frame Interpolation": return 0.85
        default: return 0.7
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Enhancement Impact")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.accentWarm.opacity(0.8))
                
                Spacer()
                
                Text("\(Int(impactLevel * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.accentWarm)
            }
            
            // Progress bar with gradient
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentWarm.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.596, blue: 0.329),
                                    Color(red: 1.0, green: 0.696, blue: 0.429)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * impactLevel, height: 6)
                        .animation(.easeInOut(duration: 1.0), value: impactLevel)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.overlaySoft.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentWarm.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct MetricItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.accentWarm.opacity(0.6))
            
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.accentWarm)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ZStack {
        Color.primarySoft
            .ignoresSafeArea()
        
        ScrollView {
            SpatialVideoPreview(
                videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
                enhancementType: "AI Upscale"
            )
            .frame(height: 400)
        }
    }
}