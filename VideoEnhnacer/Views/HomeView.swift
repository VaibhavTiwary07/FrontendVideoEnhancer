import SwiftUI

struct HomeView: View {
    @State private var showVideoPropertyList = false
    @State private var selectedVideoURL: URL?
    @ObservedObject var videoPlayerManager: VideoPlayerManager
    @State private var isHomeViewActive = false
    @State private var selectedEnhancement: Enhancement?

    struct Enhancement: Identifiable {
        let id = UUID()
        let type: String
        let icon: String
        let gradientType: GradientType
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            ScrollView {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        // Top Carousel Section (Full Width)
                        PageControlImageCarousel()
                        
                        // Spacing for overlap
//                        Spacer()
//                            .frame(height: 50)
                    }
                    
                    // Enhancement Cards Section (Overlapping)
                    VStack(spacing: 0) {
                        // Push enhancement section down to overlap carousel
                        Spacer()
                            .frame(height: 250)
                        
                        VStack(spacing: 16) {
                            VStack(spacing: 16) {
                                Text("Enhancement Options")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                
                                VStack(spacing: 16) {
                                    ImageComparisonCard(
                                        icon: "arrow.up.square",
                                        title: "AI Upscale",
                                        subtitle: "Enhance image resolution",
                                        gradientType: .cyanGray
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "AI Upscale",
                                            icon: "arrow.up.square",
                                            gradientType: .cyanGray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: "face.smiling",
                                        title: "Face & Object Enhancer",
                                        subtitle: "Improve facial features",
                                        gradientType: .yellowGray
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "Face & Object Enhancer",
                                            icon: "face.smiling",
                                            gradientType: .yellowGray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: "waveform.path",
                                        title: "AI Denoise",
                                        subtitle: "Remove grain and noise",
                                        gradientType: .purpleGray
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "AI Denoise",
                                            icon: "waveform.path",
                                            gradientType: .purpleGray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: "paintpalette.fill",
                                        title: "AI Color",
                                        subtitle: "Color correction",
                                        gradientType: .cyanGray
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "AI Color",
                                            icon: "paintpalette.fill",
                                            gradientType: .cyanGray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: "wand.and.stars",
                                        title: "AI Auto Enhancement",
                                        subtitle: "One-click improvements",
                                        gradientType: .pinkGray
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "AI Auto Enhancement",
                                            icon: "wand.and.stars",
                                            gradientType: .pinkGray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: "gyroscope",
                                        title: "Stabilizer",
                                        subtitle: "Reduce camera shake",
                                        gradientType: .gray
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "Stabilizer",
                                            icon: "gyroscope",
                                            gradientType: .gray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: "timer.circle.fill",
                                        title: "Frame Interpolation",
                                        subtitle: "Smooth motion",
                                        gradientType: .redPink
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "Frame Interpolation",
                                            icon: "timer.circle.fill",
                                            gradientType: .redPink
                                        )
                                    }
                                }
                                .padding(.bottom, 100)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color.appBackground)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                        )
                    }
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton {
                        showVideoPropertyList = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showVideoPropertyList) {
            VideoPropertyListView()
        }
        .fullScreenCover(item: $selectedEnhancement) { enhancement in
            VideoPickerView(
                enhancementType: enhancement.type,
                enhancementIcon: enhancement.icon,
                gradientType: enhancement.gradientType
            )
        }
        .onAppear {
            isHomeViewActive = true
        }
        .onDisappear {
            isHomeViewActive = false
        }
    }
}


#Preview {
    HomeView(videoPlayerManager: VideoPlayerManager())
}
