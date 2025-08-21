import SwiftUI

struct PageControlImageCarousel: View {
    @State private var currentPage = 0
    @State private var sliderValues: [Double] = [0.5, 0.5, 0.5]
    @State private var animationTimers: [Timer?] = [nil, nil, nil]
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(0..<3, id: \.self) { index in
                    CarouselCard(
                        sliderValue: $sliderValues[index]
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 280)
            .onChange(of: currentPage) { _, newPage in
                startAutoSliding(for: newPage)
            }
            .onAppear {
                startAutoSliding(for: 0)
            }
            .onDisappear {
                stopAllAnimations()
            }
            
            // Custom Page Control positioned at bottom
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
                            LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: index == currentPage ? 12 : 8, height: index == currentPage ? 12 : 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.bottom, 20)
        }
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
    @Binding var sliderValue: Double
    
    var body: some View {
        ImageComparisonSlider(
            beforeImageName: "test",
            afterImageName: "testEnhanced",
            sliderValue: $sliderValue,
//            touchEnabled: false
        )
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.cardBackground)
                .neomorphicStyle(cornerRadius: 24, shadowRadius: 8)
        )
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
}

#Preview {
    PageControlImageCarousel()
        .background(Color.appBackground)
        .padding()
}
