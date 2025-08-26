import SwiftUI

struct ExportOptionsView: View {
    @Binding var isPresented: Bool
    @Binding var selectedResolution: String
    @Binding var selectedFrameRate: String
    @Binding var selectedFormat: String
    let onExport: () -> Void
    
    private let resolutionOptions = ["720p", "1080p"]
    private let frameRateOptions = ["30fps", "60fps"]
    private let formatOptions = ["MP4", "3GP", "AVI"]
    
    private var estimatedSize: String {
        let baseSize: Double
        let formatMultiplier: Double
        let resolutionMultiplier: Double
        let frameRateMultiplier: Double
        
        // Base size in MB for 1 minute of video
        baseSize = 50
        
        // Format multipliers
        switch selectedFormat {
        case "MP4": formatMultiplier = 1.0
        case "3GP": formatMultiplier = 0.4
        case "AVI": formatMultiplier = 1.5
        default: formatMultiplier = 1.0
        }
        
        // Resolution multipliers
        switch selectedResolution {
        case "720p": resolutionMultiplier = 0.6
        case "1080p": resolutionMultiplier = 1.0
        default: resolutionMultiplier = 1.0
        }
        
        // Frame rate multipliers
        switch selectedFrameRate {
        case "30fps": frameRateMultiplier = 1.0
        case "60fps": frameRateMultiplier = 1.6
        default: frameRateMultiplier = 1.0
        }
        
        let totalSize = baseSize * formatMultiplier * resolutionMultiplier * frameRateMultiplier
        
        if totalSize < 1024 {
            return String(format: "%.0f MB", totalSize)
        } else {
            return String(format: "%.1f GB", totalSize / 1024)
        }
    }
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
            
            VStack {
                HStack {
                    Spacer()
                    
                    // Export options panel
                    VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Export Options")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                    }
                    .padding(.bottom, 10)
                    
                    // Resolution Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resolution")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ForEach(resolutionOptions, id: \.self) { option in
                                optionButton(
                                    title: option,
                                    isSelected: selectedResolution == option,
                                    action: { selectedResolution = option }
                                )
                            }
                            Spacer()
                        }
                    }
                    
                    // Frame Rate Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Frame Rate")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ForEach(frameRateOptions, id: \.self) { option in
                                optionButton(
                                    title: option,
                                    isSelected: selectedFrameRate == option,
                                    action: { selectedFrameRate = option }
                                )
                            }
                            Spacer()
                        }
                    }
                    
                    // Format Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Format")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ForEach(formatOptions, id: \.self) { option in
                                optionButton(
                                    title: option,
                                    isSelected: selectedFormat == option,
                                    action: { selectedFormat = option }
                                )
                            }
                            Spacer()
                        }
                    }
                    
                    // Estimated Size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated Size")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(estimatedSize)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    
                    // Export Button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        onExport()
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Export")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient.primaryTheme)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
                }
                .padding(24)
                .frame(width: 280)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(LinearGradient.primaryTheme.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 20, x: -5, y: 0)
                .padding(.trailing, 16)
                .padding(.top, 60) // Position at top
                }
                Spacer()
            }
        }
    }
    
    private func optionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .background(buttonBackground(isSelected: isSelected))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func buttonBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient.primaryTheme)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

#Preview {
    ExportOptionsView(
        isPresented: .constant(true),
        selectedResolution: .constant("1080p"),
        selectedFrameRate: .constant("30fps"),
        selectedFormat: .constant("MP4"),
        onExport: {
            print("Export button tapped!")
        }
    )
}
