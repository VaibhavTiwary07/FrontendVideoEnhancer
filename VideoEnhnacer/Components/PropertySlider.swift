import SwiftUI

struct PropertySlider: View {
    let title: String
    let beforeImage: String
    let afterImage: String
    @State private var sliderValue: Double = 0.5
    
    init(title: String, beforeImage: String = "photo", afterImage: String = "photo.fill") {
        self.title = title
        self.beforeImage = beforeImage
        self.afterImage = afterImage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primaryText)
            
            HStack(spacing: 16) {
                // Before/After Preview Container
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cardBackground)
                        .frame(height: 120)
                        .neomorphicStyle(cornerRadius: 12, shadowRadius: 6)
                    
                    HStack(spacing: 0) {
                        // Before Section
                        VStack {
                            Image(systemName: beforeImage)
                                .font(.system(size: 32))
                                .foregroundColor(.secondaryText)
                            Text("Before")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(1.0 - sliderValue + 0.3)
                        
                        // Divider
                        Rectangle()
                            .fill(Color.secondaryText.opacity(0.3))
                            .frame(width: 1)
                        
                        // After Section
                        VStack {
                            Image(systemName: afterImage)
                                .font(.system(size: 32))
                                .foregroundColor(.primaryText)
                            Text("After")
                                .font(.caption)
                                .foregroundColor(.primaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(sliderValue + 0.3)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                
                // Slider
                VStack {
                    Slider(value: $sliderValue, in: 0...1)
                        .accentColor(Color(red: 1.0, green: 0.596, blue: 0.329))
                        .frame(width: 80)
                        .rotationEffect(.degrees(-90))
                        .frame(height: 80)
                }
                .frame(width: 40)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .neomorphicStyle()
        )
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        PropertySlider(
            title: "AI Upscale",
            beforeImage: "square.dashed",
            afterImage: "square.fill"
        )
        
        PropertySlider(
            title: "Face Enhancer",
            beforeImage: getIOSCompatibleSymbol("face.dashed", fallback: "person.crop.circle"),
            afterImage: getIOSCompatibleSymbol("face.smiling", fallback: "person.crop.circle")
        )
        
        PropertySlider(
            title: "AI Denoise",
            beforeImage: "waveform",
            afterImage: "waveform.path"
        )
    }
    .background(Color.appBackground)
    .padding()
}