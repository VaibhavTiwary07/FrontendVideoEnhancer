import SwiftUI
import UIKit

struct PageControlImageCarousel: View {
    @Binding var currentPage: Int
    var dotsBottomLift: CGFloat = 0 // lift dots upward to avoid overlap
    private let banners = ["Banner1", "Banner2", "Banner3"]
    @State private var currentAspectRatio: CGFloat = 16.0/9.0 // width:height

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let height = screenWidth / max(currentAspectRatio, 0.1)

        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(Array(banners.enumerated()), id: \.offset) { idx, name in
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: screenWidth)
                        .tag(idx)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

            // Custom page dots lifted upward by dotsBottomLift
            HStack(spacing: 6) {
                ForEach(0..<banners.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.white : Color.white.opacity(0.5))
                        .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Capsule().fill(Color.black.opacity(0.2)))
            .padding(.bottom, min(10 + max(0, dotsBottomLift), max(0, height - 20)))
        }
        .frame(width: screenWidth, height: height, alignment: .top)
        .onAppear { updateAspectRatio() }
        .onChange(of: currentPage) { _ in updateAspectRatio() }
    }

    private func titleForIndex(_ index: Int) -> String {
        switch index {
        case 0: return "Face Enhancer"
        case 1: return "Upscaler"
        case 2: return "Auto Adjustment"
        default: return ""
        }
    }

    private func updateAspectRatio() {
        let name = banners[currentPage]
        if let img = UIImage(named: name) {
            let w = img.size.width
            let h = img.size.height
            if w > 0, h > 0 {
                currentAspectRatio = w / h
            }
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
