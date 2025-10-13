import SwiftUI

struct VideoPropertyCard: View {
    let property: VideoProperty
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Before/After Icons
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Image(systemName: property.beforeIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondaryText)
                        Text("Before")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondaryText)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentWarm)
                    
                    VStack(spacing: 4) {
                        Image(systemName: property.afterIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.accentWarm)
                        Text("After")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.accentWarm)
                    }
                }
                
                // Property Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(property.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.leading)
                    
                    Text(property.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .accentWarm : .secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.accentWarm.opacity(0.1) : Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color.accentWarm.opacity(0.3) : Color.black.opacity(0.1),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
            
            onTap()
        }
    }
}

#Preview {
    VideoPropertyCard(
        property: VideoProperty(
            title: "AI Upscale",
            beforeIcon: "rectangle.dashed",
            afterIcon: "rectangle.fill",
            description: "Enhance resolution and clarity"
        ),
        isSelected: false,
        onTap: {}
    )
    .padding()
    .background(Color.appBackground)
}