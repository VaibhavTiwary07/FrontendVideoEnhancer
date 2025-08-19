import SwiftUI

struct ImageComparisonCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradientType: GradientType
    let action: () -> Void
    
    @State private var sliderValue: Double = 0.5
    @State private var isPressed = false
    @State private var animationTimer: Timer?
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Single left-to-right gradient background with masked SF symbols
                ZStack {
                    gradientType.base

                    // Background SF Symbols with gradient mask
                    GeometryReader { geometry in
                        ZStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 60, weight: .ultraLight))
                                .position(x: geometry.size.width * 0.25,
                                          y: geometry.size.height * 0.3)

                            Image(systemName: getBackgroundSymbol())
                                .font(.system(size: 100, weight: .ultraLight))
                                .position(x: geometry.size.width * 0.6,
                                          y: geometry.size.height * 0.7)

                            Image(systemName: "circle.grid.2x2.fill")
                                .font(.system(size: 80, weight: .ultraLight))
                                .position(x: geometry.size.width * 0.85,
                                          y: geometry.size.height * 0.4)
                        }
                        .foregroundColor(.white.opacity(0.06))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .mask(
                            LinearGradient(
                                colors: [Color.white.opacity(0.9), Color.white.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }

                    // Simple fade leading into the comparison slider
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 60)
                    .offset(x: -120)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                
                // Content overlay
                HStack(spacing: 0) {
                    // Left side - Icon and text over gradient
                    VStack(spacing: 12) {
                        // Icon with background
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.15))
                                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                            )
                        
                        // Title and subtitle
                        VStack(spacing: 4) {
                            Text(title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text(subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 16)
                
                    Spacer()
                    
                    // Right side - Image comparison overlay
                    ImageComparisonSlider(
                        beforeImageName: "test.png",
                        afterImageName: "testEnhanced.png",
                        sliderValue: $sliderValue
                    )
                    .frame(width: 120, height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                    )
                    .padding(.trailing, 16)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
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
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .padding(.horizontal, 20)
    }
    
    private func startAnimations() {
        // Auto-sliding animation for demo
        animationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 2.0)) {
                sliderValue = sliderValue < 0.3 ? 0.8 : 0.2
            }
        }
    }
    
    private func stopAnimations() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func getBackgroundSymbol() -> String {
        switch icon {
        case "arrow.up.square": return "arrow.up.circle.fill"
        case "face.smiling": return "person.crop.circle.fill"
        case "waveform.path": return "waveform.circle.fill"
        case "paintpalette.fill": return "paintpalette.fill"
        case "wand.and.stars": return "wand.and.stars.fill"
        case "gyroscope": return "gyroscope"
        case "timer.circle.fill": return "timer.circle.fill"
        default: return "circle.fill"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ImageComparisonCard(
            icon: "arrow.up.square",
            title: "AI Upscale",
            subtitle: "Enhance image resolution",
            gradientType: .redPink
        ) {
            print("Tapped AI Upscale")
        }
        
        ImageComparisonCard(
            icon: "waveform.path",
            title: "AI Denoise",
            subtitle: "Remove grain and noise",
            gradientType: .purpleGray
        ) {
            print("Tapped AI Denoise")
        }
    }
    .background(Color.appBackground)
    .padding()
}
