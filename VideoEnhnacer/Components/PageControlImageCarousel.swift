import SwiftUI

struct PageControlImageCarousel: View {
    @State private var currentPage = 0
    @State private var sliderValues: [Double] = [0.5, 0.5, 0.5]
    @State private var animationTimers: [Timer?] = [nil, nil, nil]
    
    let imageData = [
        ("AI Upscale", "Enhance image resolution"),
        ("AI Denoise", "Remove noise and grain"),
        ("Color Enhancement", "Improve color quality")
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $currentPage) {
                ForEach(0..<3, id: \.self) { index in
                    CarouselCard(
                        title: imageData[index].0,
                        subtitle: imageData[index].1,
                        sliderValue: $sliderValues[index]
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 180)
            .onChange(of: currentPage) { newPage in
                startAutoSliding(for: newPage)
            }
            .onAppear {
                startAutoSliding(for: 0)
            }
            .onDisappear {
                stopAllAnimations()
            }
            
            // Custom Page Control
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? 
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.47, blue: 0.47),
                                    Color(red: 1.0, green: 0.596, blue: 0.329)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: index == currentPage ? 12 : 8, height: index == currentPage ? 12 : 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
    }
    
    private func startAutoSliding(for page: Int) {
        stopAnimation(for: page)
        
        animationTimers[page] = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.5)) {
                sliderValues[page] = sliderValues[page] < 0.3 ? 0.8 : 0.2
            }
        }
    }
    
    private func stopAnimation(for page: Int) {
        animationTimers[page]?.invalidate()
        animationTimers[page] = nil
    }
    
    private func stopAllAnimations() {
        for i in 0..<3 {
            stopAnimation(for: i)
        }
    }
}

struct CarouselCard: View {
    let title: String
    let subtitle: String
    @Binding var sliderValue: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Before/After Comparison with real images
            ImageComparisonSlider(
                beforeImageName: "test",
                afterImageName: "testEnhanced",
                sliderValue: $sliderValue
            )
            .frame(height: 80)
            .cornerRadius(12)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .neomorphicStyle(cornerRadius: 16, shadowRadius: 8)
        )
    }
}

#Preview {
    PageControlImageCarousel()
        .background(Color.appBackground)
        .padding()
}