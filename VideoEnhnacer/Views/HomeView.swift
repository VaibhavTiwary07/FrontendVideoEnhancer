import SwiftUI

struct HomeView: View {
    @State private var showVideoPropertyList = false
    @State private var selectedVideoURL: URL?
    @StateObject private var videoPlayerManager = VideoPlayerManager()
    
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
                    
                    // Video Enhancements
                    VStack(spacing: 16) {
                        Text("Video Enhancements")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            VideoComparisonCard(
                                title: "AI Upscale",
                                subtitle: "See the difference in real-time",
                                normalVideo: "normal",
                                enhancedVideo: "enhanced",
                                videoPlayerManager: videoPlayerManager
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            QuickActionCard(
                                icon: "face.smiling",
                                title: "Face & Object Enhancer",
                                subtitle: "Improve facial features and objects"
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            QuickActionCard(
                                icon: "waveform.path",
                                title: "AI Denoise",
                                subtitle: "Remove grain and noise"
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            QuickActionCard(
                                icon: "paintpalette.fill",
                                title: "AI Color",
                                subtitle: "Color correction and enhancement"
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            QuickActionCard(
                                icon: "wand.and.stars",
                                title: "AI Auto Enhancement",
                                subtitle: "One-click smart improvements"
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            QuickActionCard(
                                icon: "gyroscope",
                                title: "Stabilizer",
                                subtitle: "Reduce camera shake"
                            ) {
                                showVideoPropertyList = true
                            }
                            
                            QuickActionCard(
                                icon: "timer.circle.fill",
                                title: "Frame Interpolation",
                                subtitle: "Smooth motion and increase frame rate"
                            ) {
                                showVideoPropertyList = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
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
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .primaryGradient()
                    )
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .buttonStyle(PlainButtonStyle())
        .neomorphicCard()
    }
}

#Preview {
    HomeView()
}