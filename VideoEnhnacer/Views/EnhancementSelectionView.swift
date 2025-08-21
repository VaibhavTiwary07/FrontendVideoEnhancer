import SwiftUI
import AVFoundation

struct EnhancementSelectionView: View {
    let videoURL: URL
    let enhancementType: String
    let enhancementIcon: String
    let gradientType: GradientType
    
    @State private var selectedOption: String = ""
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
    
    // Enhancement options are provided by EnhancementOptionSelector
    
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
                        .frame(height: isIPad ? 420 : 360)
                        .padding(.top, 30)
                        
                        // Enhancement options section
                        VStack(spacing: 24) {
                            SectionHeader(
                                title: "Choose Enhancement Level",
                                subtitle: "Select the level that best fits your video and processing preferences"
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 40)
                            
                            // Centralized enhancement option selector
                            EnhancementOptionSelector(
                                enhancementType: enhancementType,
                                selectedOption: $selectedOption
                            )
                            
                            // Intelligent performance indicator
                            if !selectedOption.isEmpty {
                                IntelligentPerformanceIndicator(
                                    enhancementType: enhancementType,
                                    selectedOption: selectedOption,
                                    videoURL: videoURL
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
                                    removal: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top))
                                ))
                            }
                            
                            // Process button
                            ProcessButton(
                                isProcessing: isProcessing,
                                processingProgress: processingProgress,
                                enhancementType: enhancementType,
                                enhancementIcon: enhancementIcon,
                                selectedOption: selectedOption,
                                onProcess: {
                                    processVideo()
                                }
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                            .padding(.bottom, 50)
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
    }
    
    private func processVideo() {
        isProcessing = true
        processingProgress = 0.0
        
        // Simulate processing with progress updates
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
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
        VStack(spacing: 16) {
            // Enhancement icon
            ZStack {
                Circle()
                    .fill(Color.cardSoft)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                
                Image(systemName: enhancementIcon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.accentWarm)
            }
            
            // Title and description
            VStack(spacing: 8) {
                Text(enhancementType)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.accentWarm)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text("Choose your enhancement level")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentWarm.opacity(0.7))
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
    let isProcessing: Bool
    let processingProgress: Double
    let enhancementType: String
    let enhancementIcon: String
    let selectedOption: String
    let onProcess: () -> Void
    
    var body: some View {
        Button(action: onProcess) {
            HStack(spacing: 12) {
                if isProcessing {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.accentWarm.opacity(0.3), lineWidth: 3)
                                .frame(width: 24, height: 24)
                            
                            Circle()
                                .trim(from: 0, to: processingProgress)
                                .stroke(Color.accentWarm, lineWidth: 3)
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut, value: processingProgress)
                        }
                        
                        if processingProgress > 0 {
                            Text("\(Int(processingProgress * 100))%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.accentWarm)
                        }
                    }
                } else {
                    Image(systemName: enhancementIcon)
                        .font(.system(size: 20, weight: .medium))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isProcessing ? "Processing Video..." : "Process with \(enhancementType)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentWarm)
                    
                    if !isProcessing && !selectedOption.isEmpty {
                        Text("Using \(selectedOption.capitalized) setting")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.accentWarm.opacity(0.8))
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentWarm.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(isProcessing ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isProcessing)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isProcessing || selectedOption.isEmpty)
        .opacity((isProcessing || selectedOption.isEmpty) ? 0.7 : 1.0)
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
