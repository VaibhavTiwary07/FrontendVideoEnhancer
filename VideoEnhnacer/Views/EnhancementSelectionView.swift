import SwiftUI
import AVFoundation

struct EnhancementSelectionView: View {
    let videoURL: URL
    let enhancementType: String
    let enhancementIcon: String
    let gradientType: GradientType
    
    @StateObject private var selectionState = EnhancementSelectionState()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var scrollOffset: CGFloat = 0
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var processedVideoURL: URL?
    @State private var showingResults = false
    @State private var processingError: String?
    @State private var showingError = false
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var dynamicSubtitle: String {
        switch enhancementType {
        case "AI Upscale":
            return "Select upscaler level that best fits your video"
        case "AI Denoise":
            return "Select denoise level that best fits your video"
        case "AI Auto Enhancement":
            return "Select auto enhancement level that best fits your video"
        case "Stabilizer":
            return "Select stabilization level that best fits your video"
        case "Frame Interpolation":
            return "Select interpolation level that best fits your video"
        default:
            return "Select the level that best fits your video"
        }
    }
    
    private var enhancementOptions: [EnhancementOption] {
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
                EnhancementOption(id: "low", title: "Low", description: "Gentle noise reduction", icon: "1.square.fill"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced reduction", icon: "2.square.fill", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive removal", icon: "3.square.fill")
            ]
        case "AI Auto Enhancement":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Subtle improvements", icon: "1.square.fill"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced enhancement", icon: "2.square.fill", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Maximum enhancement", icon: "3.square.fill")
            ]
        case "Stabilizer":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Gentle stabilization", icon: "1.square.fill"),
                EnhancementOption(id: "medium", title: "Medium", description: "Standard stabilization", icon: "2.square.fill", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive stabilization", icon: "3.square.fill")
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
        ZStack {
            Color.primarySoft
                .ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header with spatial video preview
                        HeaderSection(
                            enhancementType: enhancementType,
                            enhancementIcon: enhancementIcon
                        )
                        .id("header")
                        .padding(.top, 20)
                        
                        // Spatial video preview
                        SpatialVideoPreview(
                            videoURL: videoURL,
                            enhancementType: enhancementType
                        )
                        .frame(height: isIPad ? 280 : 240)
                        .padding(.top, 20)
                        
                        // Enhancement options section
                        VStack(spacing: 16) {
                            SectionHeader(
                                title: "Choose Enhancement Level",
                                subtitle: dynamicSubtitle
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            // Enhancement options single row
                            HStack(spacing: 12) {
                                ForEach(enhancementOptions, id: \.id) { option in
                                    OptionCard(
                                        option: option,
                                        isSelected: selectionState.selectedOption == option.id,
                                        onTap: {
                                            selectionState.updateSelection(option.id)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            
                            // Process button
                            ProcessButton(
                                enhancementType: enhancementType,
                                selectedOption: selectionState.selectedOption,
                                onProcess: {
                                    processVideo()
                                }
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                )
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
            
            // Full-screen processing overlay
            if isProcessing {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Processing Video...")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(Int(processingProgress * 100))%")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                        Text("Back")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.accentWarm)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentWarm.opacity(0.1))
                    )
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Enhanced step indicator
                    VStack(spacing: 4) {
                        // Progress dots with connecting lines
                        HStack(spacing: 8) {
                            ForEach(1...4, id: \.self) { step in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(step <= 3 ? Color.accentWarm : Color.accentWarm.opacity(0.3))
                                        .frame(width: step == 3 ? 10 : 8, height: step == 3 ? 10 : 8)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.accentWarm, lineWidth: step == 3 ? 2 : 1)
                                                .opacity(step == 3 ? 1 : 0.5)
                                        )
                                    
                                    // Connecting line (except for last step)
                                    if step < 4 {
                                        Rectangle()
                                            .fill(step < 3 ? Color.accentWarm : Color.accentWarm.opacity(0.3))
                                            .frame(width: 12, height: 2)
                                            .cornerRadius(1)
                                    }
                                }
                            }
                        }
                        
                        Text("Step 3 of 4")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentWarm)
                    }
                    
                    // Close button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentWarm)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.accentWarm.opacity(0.15))
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .onAppear {
            // Set default selection to recommended option
            if let recommended = enhancementOptions.first(where: { $0.isRecommended }) {
                selectionState.selectedOption = recommended.id
            } else if let first = enhancementOptions.first {
                selectionState.selectedOption = first.id
            }
        }
        .fullScreenCover(isPresented: $showingResults) {
            if let processedURL = processedVideoURL {
                VideoResultsView(
                    originalVideoURL: videoURL,
                    processedVideoURL: processedURL,
                    enhancementType: enhancementType,
                    enhancementIcon: enhancementIcon,
                    gradientType: gradientType
                )
            }
        }
        .alert("Processing Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(processingError ?? "Unknown error occurred")
        }
        .onChange(of: showingResults) { _, newValue in
            if !newValue {
                isProcessing = false
                processingProgress = 0.0
            }
        }
    }
    
    private func processVideo() {
        isProcessing = true
        processingProgress = 0.0
        
        // Simulate processing with progress updates
        let _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            processingProgress += 0.02
            
            if processingProgress >= 1.0 {
                timer.invalidate()
                
                // Simulate processing completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    processedVideoURL = videoURL // For demo purposes
                    isProcessing = false
                    showingResults = true
                }
            }
        }
        
        // Add haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
    }
}

struct HeaderSection: View {
    let enhancementType: String
    let enhancementIcon: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Clean minimal header with gradient accent
            VStack(spacing: 8) {
                Text(enhancementType)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.accentWarm)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                // Decorative gradient line
                Rectangle()
                    .fill(LinearGradient.primaryTheme)
                    .frame(width: 40, height: 2)
                    .cornerRadius(1)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                
                Text("Choose your enhancement level")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentWarm.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.accentWarm)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentWarm.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProcessButton: View {
    let enhancementType: String
    let selectedOption: String
    let onProcess: () -> Void
    
    var body: some View {
        Button(action: onProcess) {
            VStack(alignment: .center, spacing: 2) {
                Text("Process with \(enhancementType)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                if !selectedOption.isEmpty {
                    Text("Using \(selectedOption.capitalized) setting")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient.primaryTheme)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(selectedOption.isEmpty)
        .opacity(selectedOption.isEmpty ? 0.7 : 1.0)
    }
}

// MARK: - State Management

class EnhancementSelectionState: ObservableObject {
    @Published var selectedOption: String = ""
    @Published var isAnalyzing: Bool = false
    
    func updateSelection(_ option: String) {
        selectedOption = option
        
        // Simulate analysis
        isAnalyzing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isAnalyzing = false
        }
    }
}

// MARK: - Option Card Component

struct OptionCard: View {
    let option: EnhancementOption
    let isSelected: Bool
    let onTap: () -> Void
    
    private var titleColor: Color {
        isSelected ? .white : Color.accentWarm
    }
    
    private var recommendedTextColor: Color {
        isSelected ? .white.opacity(0.9) : Color.accentWarm.opacity(0.7)
    }
    
    private var recommendedBackground: LinearGradient {
        if isSelected {
            return LinearGradient(colors: [Color.white.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.47, blue: 0.47).opacity(0.3),
                    Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.3)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private var cardBackground: LinearGradient {
        if isSelected {
            return LinearGradient.primaryTheme
        } else {
            return LinearGradient(colors: [Color.cardSoft], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var strokeColor: Color {
        isSelected ? Color.white.opacity(0.2) : Color.accentWarm.opacity(0.3)
    }

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 4) {
                Text(option.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.center)
                
                if option.isRecommended {
                    Text("RECOMMENDED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(recommendedTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(recommendedBackground)
                        )
                }
            }
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 6 : 3, x: 0, y: isSelected ? 3 : 2)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preference Keys

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationView {
        EnhancementSelectionView(
            videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            enhancementType: "AI Upscale",
            enhancementIcon: "arrow.up.square",
            gradientType: .redPink
        )
    }
}
