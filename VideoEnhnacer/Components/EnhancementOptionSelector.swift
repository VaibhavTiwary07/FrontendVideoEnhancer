import SwiftUI

struct EnhancementOptionSelector: View {
    let enhancementType: String
    @State private var selectedOption: String = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var options: [EnhancementOption] {
        switch enhancementType {
        case "AI Upscale":
            return [
                EnhancementOption(id: "2x", title: "2x Enhancement", description: "Double the resolution", icon: "2.square.fill", isRecommended: true),
                EnhancementOption(id: "3x", title: "3x Enhancement", description: "Triple the resolution", icon: "3.square.fill"),
                EnhancementOption(id: "4x", title: "4x Enhancement", description: "Quadruple the resolution", icon: "4.square.fill"),
                EnhancementOption(id: "1080p", title: "Standard 1080p", description: "Upscale to Full HD", icon: "tv.fill")
            ]
        case "AI Denoise":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Gentle noise reduction", icon: "1.circle.fill"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced reduction", icon: "2.circle.fill", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive removal", icon: "3.circle.fill")
            ]
        case "AI Auto Enhancement":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Subtle improvements", icon: "1.circle.fill"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced enhancement", icon: "2.circle.fill", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Maximum enhancement", icon: "3.circle.fill")
            ]
        case "Stabilizer":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Gentle stabilization", icon: "1.circle.fill"),
                EnhancementOption(id: "medium", title: "Medium", description: "Standard stabilization", icon: "2.circle.fill", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive stabilization", icon: "3.circle.fill")
            ]
        case "AI Frame Interpolation":
            return [
                EnhancementOption(id: "smooth", title: "Smooth", description: "Enhanced motion smoothness", icon: "waveform.path", isRecommended: true),
                EnhancementOption(id: "fluid", title: "Fluid", description: "Ultra-smooth motion", icon: "waveform.path.ecg")
            ]
        default:
            return []
        }
    }
    
    var body: some View {
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
                    OptionCard(
                        option: option,
                        isSelected: selectedOption == option.id,
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
                // Navigate to processing screen
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

//struct OptionCard: View {
//    let option: EnhancementOption
//    let isSelected: Bool
//    let onTap: () -> Void
//    
//    var body: some View {
//        Button(action: onTap) {
//            HStack(spacing: 16) {
//                // Icon
//                ZStack {
//                    Circle()
//                        .fill(isSelected ? LinearGradient.primaryTheme : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
//                        .frame(width: 50, height: 50)
//                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
//                    
//                    Image(systemName: option.icon)
//                        .font(.system(size: 20, weight: .medium))
//                        .foregroundColor(.white)
//                }
//                
//                // Content
//                VStack(alignment: .leading, spacing: 6) {
//                    HStack {
//                        Text(option.title)
//                            .font(.system(size: 18, weight: .bold))
//                            .foregroundColor(.white)
//                        
//                        if option.isRecommended {
//                            Text("RECOMMENDED")
//                                .font(.system(size: 10, weight: .bold))
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 8)
//                                .padding(.vertical, 4)
//                                .background(
//                                    Capsule()
//                                        .fill(LinearGradient.primaryTheme)
//                                )
//                        }
//                        
//                        Spacer()
//                    }
//                    
//                    Text(option.description)
//                        .font(.system(size: 14, weight: .medium))
//                        .foregroundColor(.white.opacity(0.8))
//                        .multilineTextAlignment(.leading)
//                }
//                
//                Spacer()
//                
//                // Selection indicator
//                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
//                    .font(.system(size: 20, weight: .medium))
//                    .foregroundColor(isSelected ? .white : .white.opacity(0.4))
//            }
//            .padding(20)
//            .background(
//                RoundedRectangle(cornerRadius: 16)
//                    .fill(Color.white.opacity(isSelected ? 0.15 : 0.08))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 16)
//                            .stroke(isSelected ? LinearGradient.primaryTheme : LinearGradient(colors: [Color.white.opacity(0.2)], startPoint: .leading, endPoint: .trailing), lineWidth: isSelected ? 2 : 1)
//                    )
//            )
//            .shadow(color: .black.opacity(isSelected ? 0.3 : 0.1), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
//            .scaleEffect(isSelected ? 1.02 : 1.0)
//            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}

struct EnhancementOption {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isRecommended: Bool
    
    init(id: String, title: String, description: String, icon: String, isRecommended: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.isRecommended = isRecommended
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        EnhancementOptionSelector(enhancementType: "AI Upscale")
    }
}
