import SwiftUI

struct EnhancementOptionSelector: View {
    let enhancementType: String
    @State private var selectedOption: String = ""
    @State private var isProcessing = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var options: [EnhancementOption] {
        switch enhancementType {
        case "AI Upscale":
            return [
                EnhancementOption(id: "2x", title: "", description: "", icon: "arrow.up.right.square", isRecommended: true),
                EnhancementOption(id: "3x", title: "", description: "", icon: "plus.magnifyingglass"),
                EnhancementOption(id: "4x", title: "", description: "", icon: "rectangle.expand.vertical"),
                EnhancementOption(id: "1080p", title: "", description: "", icon: "tv.and.hifispeaker.fill")
            ]
        case "AI Denoise":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Gentle noise reduction", icon: "waveform.path"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced reduction", icon: "sparkles", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive removal", icon: "slider.horizontal.3")
            ]
        case "AI Auto Enhancement":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Subtle improvements", icon: "dial.low"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced enhancement", icon: "wand.and.stars", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Maximum enhancement", icon: "dial.high.fill")
            ]
        case "Stabilizer":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Gentle stabilization", icon: "level"),
                EnhancementOption(id: "medium", title: "Medium", description: "Standard stabilization", icon: "gyroscope", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive stabilization", icon: "arrow.triangle.2.circlepath")
            ]
        case "AI Frame Interpolation":
            return [
                EnhancementOption(id: "smooth", title: "Smooth", description: "Enhanced motion smoothness", icon: "play.rectangle.fill", isRecommended: true),
                EnhancementOption(id: "fluid", title: "Fluid", description: "Ultra-smooth motion", icon: "forward.frame.fill")
            ]
        default:
            return []
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Choose \(enhancementType) Level")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                    Text("Select the enhancement level that best fits your video")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 20)

                // Options Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: isIPad ? 2 : 1), spacing: 16) {
                    ForEach(options, id: \.id) { option in
                        EnhancementOptionCard(
                            option: option,
                            isSelected: selectedOption == option.id,
                            isAnalyzing: false,
                            onTap: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                selectedOption = option.id
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Continue Button
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    isProcessing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isProcessing = false
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 18, weight: .medium))

                        Text("Process Video")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(selectedOption.isEmpty)
                .opacity(selectedOption.isEmpty ? 0.6 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }

            if isProcessing {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            // Select recommended option by default
            if let recommended = options.first(where: { $0.isRecommended }) {
                selectedOption = recommended.id
            } else if let first = options.first {
                selectedOption = first.id
            }
        }
    }
}

// MARK: - Duplicate OptionCard component was removed
// Using shared EnhancementOptionCard from Components/Shared/ instead


// EnhancementOption is now defined in EnhancementServiceProtocol.swift to avoid conflicts

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        EnhancementOptionSelector(enhancementType: "AI Upscale")
    }
}
