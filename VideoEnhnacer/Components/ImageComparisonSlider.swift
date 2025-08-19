import SwiftUI

struct ImageComparisonSlider: View {
    let beforeImageName: String
    let afterImageName: String
    @Binding var sliderValue: Double

    init(beforeImageName: String = "test.png", afterImageName: String = "testEnhanced.png", sliderValue: Binding<Double>) {
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self._sliderValue = sliderValue
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(afterImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                Image(beforeImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .mask(
                        Rectangle()
                            .frame(width: geometry.size.width * sliderValue)
                    )

                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .position(x: geometry.size.width * sliderValue,
                              y: geometry.size.height * 0.5)

                // Before/After labels
                HStack {
                    Text("Before")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .padding(.leading, 8)
                        .padding(.bottom, 4)
                    
                    Spacer()
                    
                    Text("After")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .padding(.trailing, 8)
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newValue = max(0, min(1, value.location.x / geometry.size.width))
                                sliderValue = newValue
                            }
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 20) {
        ImageComparisonSlider(
            beforeImageName: "test.png",
            afterImageName: "testEnhanced.png",
            sliderValue: .constant(0.5)
        )
        .frame(height: 100)
        
        ImageComparisonSlider(
            sliderValue: .constant(0.3)
        )
        .frame(height: 100)
    }
    .padding()
    .background(Color.appBackground)
}
