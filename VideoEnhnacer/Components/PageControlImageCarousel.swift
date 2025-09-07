import SwiftUI

struct PageControlImageCarousel: View {
    @Binding var currentPage: Int
    private let banners = ["Banner1", "Banner2", "Banner3"]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                TabView(selection: $currentPage) {
                    ForEach(Array(banners.enumerated()), id: \.offset) { idx, name in
                        Image(name)
                            .resizable()
                            .scaledToFit() // Use full image without cropping
                            .frame(width: geo.size.width, height: geo.size.height)
                            .tag(idx)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func titleForIndex(_ index: Int) -> String {
        switch index {
        case 0: return "Face Enhancer"
        case 1: return "Upscaler"
        case 2: return "Auto Adjustment"
        default: return ""
        }
    }
}

#Preview {
    PageControlImageCarousel(currentPage: .constant(0))
        .frame(height: 300)
        .background(Color.black)
}

// MARK: - Segmented Control exposed by carousel component
struct CarouselSegmentedControl: View {
    @Binding var selectedIndex: Int
    
    var body: some View {
        Picker("Mode", selection: $selectedIndex) {
            Text("Face Enhancer").tag(0)
            Text("Upscaler").tag(1)
            Text("Auto Adjust").tag(2)
        }
        .pickerStyle(.segmented)
    }
}
