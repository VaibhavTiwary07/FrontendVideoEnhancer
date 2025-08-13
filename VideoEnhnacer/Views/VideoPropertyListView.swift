import SwiftUI

struct VideoPropertyListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProperty: VideoProperty?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Video Enhancement")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primaryText)
                            
                            Text("Choose enhancement properties for your video")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Video Properties
                        ForEach(videoProperties, id: \.id) { property in
                            PropertySlider(
                                title: property.title,
                                beforeImage: property.beforeIcon,
                                afterImage: property.afterIcon
                            )
                        }
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            // Process Button
                            Button(action: {
                                processVideo()
                            }) {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Text("Process Video")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .primaryGradient()
                                        .shadow(
                                            color: Color.black.opacity(0.15),
                                            radius: 8,
                                            x: 0,
                                            y: 4
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Save Preset Button
                            NeomorphicButton(
                                title: "Save as Preset",
                                systemImage: "bookmark"
                            ) {
                                savePreset()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        resetAllProperties()
                    }
                    .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329))
                }
            }
        }
    }
    
    private func processVideo() {
        print("Processing video with current settings...")
        dismiss()
    }
    
    private func savePreset() {
        print("Saving current settings as preset...")
    }
    
    private func resetAllProperties() {
        print("Resetting all properties to default...")
    }
}

// MARK: - Video Property Model
struct VideoProperty {
    let id = UUID()
    let title: String
    let beforeIcon: String
    let afterIcon: String
    let description: String
}

let videoProperties = [
    VideoProperty(
        title: "AI Upscale",
        beforeIcon: "rectangle.dashed",
        afterIcon: "rectangle.fill",
        description: "Enhance resolution and clarity"
    ),
    VideoProperty(
        title: "Face and Object Enhancer",
        beforeIcon: "face.dashed",
        afterIcon: "face.smiling",
        description: "Improve facial features and object details"
    ),
    VideoProperty(
        title: "AI Denoise",
        beforeIcon: "waveform",
        afterIcon: "waveform.path",
        description: "Remove grain and noise"
    ),
    VideoProperty(
        title: "AI Color",
        beforeIcon: "paintpalette",
        afterIcon: "paintpalette.fill",
        description: "Color correction and enhancement"
    ),
    VideoProperty(
        title: "AI Auto Enhancement",
        beforeIcon: "wand.and.rays",
        afterIcon: "wand.and.stars",
        description: "One-click smart improvements"
    ),
    VideoProperty(
        title: "Stabilizer",
        beforeIcon: "gyroscope",
        afterIcon: "checkmark.seal.fill",
        description: "Reduce camera shake"
    ),
    VideoProperty(
        title: "Frame Interpolation",
        beforeIcon: "timer",
        afterIcon: "timer.circle.fill",
        description: "Smooth motion and increase frame rate"
    )
]

#Preview {
    VideoPropertyListView()
}