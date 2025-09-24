import SwiftUI

struct VideoPropertyListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProperty: VideoProperty?
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var content: some View {
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
                        
                        Text("Customize your video enhancement settings")
                            .font(.system(size: 16))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Properties List
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 1), spacing: 16) {
                        ForEach(videoProperties, id: \.id) { property in
                            VideoPropertyCard(
                                property: property,
                                isSelected: selectedProperty?.id == property.id,
                                onTap: {
                                    selectedProperty = property
                                })
                        }
                    }
                    .padding(.horizontal)
                    
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
