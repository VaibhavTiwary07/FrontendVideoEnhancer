import SwiftUI

struct HomeView: View {
    @State private var showVideoPropertyList = false
    @State private var selectedVideoURL: URL?
    @ObservedObject var videoPlayerManager: VideoPlayerManager
    @State private var isHomeViewActive = false
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Transform Your Videos")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primaryText)
                        
                        Text("AI-powered video enhancements made simple")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Top Carousel Section
                    PageControlImageCarousel()
                    
                    // Enhancement Cards Section
                    VStack(spacing: 16) {
                        Text("Enhancement Options")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 16) {
                            ImageComparisonCard(
                                icon: "arrow.up.square",
                                title: "AI Upscale",
                                subtitle: "Enhance image resolution",
                                gradientType: .redPink
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            ImageComparisonCard(
                                icon: "face.smiling",
                                title: "Face & Object Enhancer",
                                subtitle: "Improve facial features",
                                gradientType: .yellowGray
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            ImageComparisonCard(
                                icon: "waveform.path",
                                title: "AI Denoise",
                                subtitle: "Remove grain and noise",
                                gradientType: .purpleGray
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            ImageComparisonCard(
                                icon: "paintpalette.fill",
                                title: "AI Color",
                                subtitle: "Color correction",
                                gradientType: .cyanGray
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            ImageComparisonCard(
                                icon: "wand.and.stars",
                                title: "AI Auto Enhancement",
                                subtitle: "One-click improvements",
                                gradientType: .pinkGray
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            ImageComparisonCard(
                                icon: "gyroscope",
                                title: "Stabilizer",
                                subtitle: "Reduce camera shake",
                                gradientType: .gray
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            ImageComparisonCard(
                                icon: "timer.circle.fill",
                                title: "Frame Interpolation",
                                subtitle: "Smooth motion",
                                gradientType: .redPink
                            ) {
                                showVideoPropertyList = true
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
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