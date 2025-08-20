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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                ZStack {
                    // Static gradient background without moving effect
                    ZStack {
                        // Static gradient background
                        LinearGradient(
                            gradient: Gradient(stops: getGradientStops(for: gradientType)),
                            startPoint: .leading,
                            endPoint: .trailing
                        )

                        // Background SF Symbols (static)
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
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    
                    // Content overlay with precise positioning
                    HStack(spacing: 0) {
                        // Left side - Precisely centered text content
                        textContentView(availableWidth: textAreaWidth(totalWidth: geometry.size.width))
                        
//                        Spacer()
                        
                        // Right side - Image comparison slider with proper containment
                        sliderView(containerHeight: geometry.size.height)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
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
        .frame(minHeight: 110, maxHeight: 130)
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
    
    // MARK: - Modern Layout Calculation Methods
    
    private func textAreaWidth(totalWidth: CGFloat) -> CGFloat {
        let sliderAreaWidth: CGFloat = 116 + 16 // slider width + trailing padding
        let leadingPadding: CGFloat = 16
        return totalWidth - sliderAreaWidth - leadingPadding
    }
    
    @ViewBuilder
    private func textContentView(availableWidth: CGFloat) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                // Icon with background
                Image(systemName: icon)
                    .font(.system(size: isIPad ? 32 : 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: isIPad ? 64 : 48, height: isIPad ? 64 : 48)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.15))
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    )
                
                // Title and subtitle with left alignment
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: isIPad ? 18 : 14, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.system(size: isIPad ? 14 : 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .frame(width: availableWidth)
        .padding(.leading, 16)
    }
    
    @ViewBuilder
    private func sliderView(containerHeight: CGFloat) -> some View {
       
        
        ImageComparisonSlider(
            beforeImageName: "test",
            afterImageName: "testEnhanced",
            sliderValue: $sliderValue
        )

        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
       
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
    
    private func getGradientStops(for gradientType: GradientType) -> [Gradient.Stop] {
        switch gradientType {
        case .redPink:
            return [
                .init(color: Color(red: 255/255, green: 16/255, blue: 0/255).opacity(0.91), location: 0.0),

                .init(color: Color(red: 255/255, green: 110/255, blue: 99/255).opacity(0.3), location: 0.7),

            ]
        case .gray:
            return [
                .init(color: Color(red: 100/255, green: 100/255, blue: 100/255).opacity(0.7), location: 0.0),
                .init(color: Color(red: 160/255, green: 160/255, blue: 160/255).opacity(0.4), location: 0.3),
//                .init(color: Color(red: 245/255, green: 245/255, blue: 245/255).opacity(0.0), location: 0.6)
            ]
        case .yellowGray:
            return [
                .init(color: Color(red: 255/255, green: 170/255, blue: 0/255).opacity(0.8), location: 0.0),
                .init(color: Color(red: 255/255, green: 200/255, blue: 80/255).opacity(0.4), location: 0.3),
                .init(color: Color(red: 255/255, green: 250/255, blue: 240/255).opacity(0.0), location: 0.6)
            ]
        case .purpleGray:
            return [
                .init(color: Color(red: 120/255, green: 80/255, blue: 200/255).opacity(0.6), location: 0.0),
                .init(color: Color(red: 160/255, green: 130/255, blue: 220/255).opacity(0.35), location: 0.3),
//                .init(color: Color(red: 245/255, green: 240/255, blue: 255/255).opacity(0.0), location: 0.6)
            ]
        case .cyanGray:
            return [
                .init(color: Color(red: 0/255, green: 132/255, blue: 255/255).opacity(0.45), location: 0.0),
                .init(color: Color(red: 46/255, green: 154/255, blue: 255/255).opacity(0.45), location: 0.3),
                .init(color: Color(red: 207/255, green: 232/255, blue: 255/255).opacity(0.0), location: 0.6)
            ]
        case .pinkGray:
            return [
                .init(color: Color(red: 220/255, green: 100/255, blue: 150/255).opacity(0.7), location: 0.0),
                .init(color: Color(red: 240/255, green: 150/255, blue: 180/255).opacity(0.35), location: 0.3),
                .init(color: Color(red: 255/255, green: 245/255, blue: 250/255).opacity(0.0), location: 0.6)
            ]
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
