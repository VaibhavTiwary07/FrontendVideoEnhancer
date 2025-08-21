import SwiftUI
import UIKit

struct MagneticSelectionGrid: View {
    let options: [EnhancementOption]
    @Binding var selectedOption: String
    let onSelectionChange: (String) -> Void
    
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var particlePositions: [CGPoint] = []
    @State private var showParticles = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private let magneticRadius: CGFloat = 100
    private let attractionStrength: CGFloat = 0.3
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Magnetic Selection Cards
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: isIPad ? 2 : 1), spacing: 20) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        MagneticOptionCard(
                            option: option,
                            isSelected: selectedOption == option.id,
                            dragLocation: dragLocation,
                            isDragging: isDragging,
                            magneticRadius: magneticRadius,
                            attractionStrength: attractionStrength,
                            onTap: {
                                selectOption(option.id, at: cardPosition(for: index, in: geometry))
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                // Particle Effects Overlay
                if showParticles {
                    ForEach(Array(particlePositions.enumerated()), id: \.offset) { index, position in
                        ParticleView()
                            .position(position)
                            .opacity(showParticles ? 1 : 0)
                            .animation(.easeOut(duration: 0.8).delay(Double(index) * 0.05), value: showParticles)
                    }
                }
            }
        }
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    isDragging = true
                    dragLocation = value.location
                    
                    // Add subtle haptic feedback for magnetic field
                    if let nearestOption = findNearestOption(to: value.location) {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred(intensity: 0.3)
                    }
                }
                .onEnded { value in
                    isDragging = false
                    
                    // Check if we're near an option for magnetic selection
                    if let nearestOption = findNearestOption(to: value.location) {
                        selectOption(nearestOption.id, at: value.location)
                    }
                }
        )
    }
    
    private func cardPosition(for index: Int, in geometry: GeometryProxy) -> CGPoint {
        let columns = isIPad ? 2 : 1
        let row = index / columns
        let column = index % columns
        
        let cardWidth = (geometry.size.width - 60) / CGFloat(columns)
        let cardHeight: CGFloat = 120
        
        let x = 20 + (cardWidth + 16) * CGFloat(column) + cardWidth / 2
        let y = 20 + (cardHeight + 20) * CGFloat(row) + cardHeight / 2
        
        return CGPoint(x: x, y: y)
    }
    
    private func findNearestOption(to location: CGPoint) -> EnhancementOption? {
        // Implementation would calculate nearest option based on location
        // For now, return first option as placeholder
        return options.first
    }
    
    private func selectOption(_ optionId: String, at position: CGPoint) {
        // Trigger particle burst effect
        generateParticles(at: position)
        
        // Haptic feedback with unique pattern
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        // Selection feedback
        selectedOption = optionId
        onSelectionChange(optionId)
        
        // Animate particles
        showParticles = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showParticles = false
            particlePositions.removeAll()
        }
    }
    
    private func generateParticles(at position: CGPoint) {
        particlePositions = (0..<12).map { i in
            let angle = Double(i) * .pi * 2 / 12
            let radius = Double.random(in: 20...60)
            return CGPoint(
                x: position.x + cos(angle) * radius,
                y: position.y + sin(angle) * radius
            )
        }
    }
}

struct MagneticOptionCard: View {
    let option: EnhancementOption
    let isSelected: Bool
    let dragLocation: CGPoint
    let isDragging: Bool
    let magneticRadius: CGFloat
    let attractionStrength: CGFloat
    let onTap: () -> Void
    
    @State private var cardOffset: CGSize = .zero
    @State private var isBeingAttracted = false
    @State private var glowIntensity: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Icon with enhanced styling
                    ZStack {
                        Circle()
                            .fill(
                                isSelected 
                                ? Color.accentWarm.opacity(0.2)
                                : Color.accentWarm.opacity(0.1)
                            )
                            .frame(width: 54, height: 54)
                            .overlay(
                                Circle()
                                    .stroke(
                                        isSelected 
                                        ? Color.accentWarm.opacity(0.6)
                                        : Color.accentWarm.opacity(0.3),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .shadow(
                                color: Color.accentWarm.opacity(glowIntensity * 0.3),
                                radius: glowIntensity * 8,
                                x: 0,
                                y: 0
                            )
                        
                        Image(systemName: option.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.accentWarm)
                    }
                    
                    // Content
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
                    
                    // Selection indicator with enhanced animation
                    ZStack {
                        Circle()
                            .stroke(Color.accentWarm.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.accentWarm)
                                .frame(width: 16, height: 16)
                                .scaleEffect(isSelected ? 1.0 : 0.1)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.cardSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isSelected 
                                    ? Color.accentWarm.opacity(0.4)
                                    : Color.accentWarm.opacity(0.1),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .shadow(
                            color: Color.primarySoft.opacity(0.4),
                            radius: isSelected ? 12 : 6,
                            x: 0,
                            y: isSelected ? 6 : 3
                        )
                )
                .scaleEffect(isSelected ? 1.02 : (isBeingAttracted ? 1.01 : 1.0))
                .offset(cardOffset)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: isSelected)
                .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.7), value: cardOffset)
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                calculateMagneticEffect(in: geometry)
            }
            .onChange(of: dragLocation) { _, _ in
                calculateMagneticEffect(in: geometry)
            }
            .onChange(of: isDragging) { _, _ in
                if !isDragging {
                    cardOffset = .zero
                    isBeingAttracted = false
                    glowIntensity = 0
                }
            }
        }
        .frame(height: 100)
    }
    
    private func calculateMagneticEffect(in geometry: GeometryProxy) {
        guard isDragging else { return }
        
        let cardCenter = CGPoint(
            x: geometry.frame(in: .global).midX,
            y: geometry.frame(in: .global).midY
        )
        
        let distance = sqrt(
            pow(dragLocation.x - cardCenter.x, 2) + 
            pow(dragLocation.y - cardCenter.y, 2)
        )
        
        if distance < magneticRadius {
            isBeingAttracted = true
            
            // Calculate attraction vector
            let attractionVector = CGPoint(
                x: (dragLocation.x - cardCenter.x) * attractionStrength,
                y: (dragLocation.y - cardCenter.y) * attractionStrength
            )
            
            cardOffset = CGSize(width: attractionVector.x, height: attractionVector.y)
            glowIntensity = 1.0 - (distance / magneticRadius)
        } else {
            isBeingAttracted = false
            cardOffset = .zero
            glowIntensity = 0
        }
    }
}

struct ParticleView: View {
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .fill(Color.accentWarm)
            .frame(width: 4, height: 4)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    scale = 2.0
                    opacity = 0.0
                }
            }
    }
}


#Preview {
    ZStack {
        Color.primarySoft
            .ignoresSafeArea()
        
        MagneticSelectionGrid(
            options: [
                EnhancementOption(id: "2x", title: "2x Enhancement", description: "Double the resolution", icon: "2.square.fill", isRecommended: true),
                EnhancementOption(id: "3x", title: "3x Enhancement", description: "Triple the resolution", icon: "3.square.fill"),
                EnhancementOption(id: "4x", title: "4x Enhancement", description: "Quadruple the resolution", icon: "4.square.fill")
            ],
            selectedOption: .constant("2x"),
            onSelectionChange: { _ in }
        )
    }
}