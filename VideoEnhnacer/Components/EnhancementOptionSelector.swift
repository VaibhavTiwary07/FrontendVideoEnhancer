import SwiftUI

struct EnhancementOptionSelector: View {
    let enhancementType: String
    @Binding var selectedOption: String
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
        case "Frame Interpolation":
            return [
                EnhancementOption(id: "smooth", title: "Smooth", description: "Enhanced motion smoothness", icon: "waveform.path", isRecommended: true),
                EnhancementOption(id: "fluid", title: "Fluid", description: "Ultra-smooth motion", icon: "waveform.path.ecg")
            ]
        default:
            return []
        }
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: isIPad ? 2 : 1), spacing: 16) {
            ForEach(options, id: \.id) { option in
                OptionCard(
                    option: option,
                    isSelected: selectedOption == option.id
                ) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    selectedOption = option.id
                }
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            if selectedOption.isEmpty {
                if let recommended = options.first(where: { $0.isRecommended }) {
                    selectedOption = recommended.id
                } else if let first = options.first {
                    selectedOption = first.id
                }
            }
        }
    }
}

struct OptionCard: View {
    let option: EnhancementOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentWarm.opacity(0.2) : Color.accentWarm.opacity(0.1))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.accentWarm.opacity(0.6) : Color.accentWarm.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                        )

                    Image(systemName: option.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.accentWarm)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(option.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.accentWarm)

                        if option.isRecommended {
                            Text("●")
                                .font(.system(size: 8))
                                .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329))
                        }

                        Spacer()
                    }

                    Text(option.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.accentWarm.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .accentWarm : Color.accentWarm.opacity(0.4))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.accentWarm.opacity(0.4) : Color.accentWarm.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: Color.primarySoft.opacity(0.4), radius: isSelected ? 12 : 6, x: 0, y: isSelected ? 6 : 3)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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
    EnhancementOptionSelector(enhancementType: "AI Upscale", selectedOption: .constant("2x"))
}
