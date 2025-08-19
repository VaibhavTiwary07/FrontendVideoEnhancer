import SwiftUI

struct ImageComparisonSlider: View {
    let beforeImageName: String
    let afterImageName: String
    @Binding var sliderValue: Double
    @State private var isDragging = false
    
    init(beforeImageName: String = "test.png", afterImageName: String = "testEnhanced.png", sliderValue: Binding<Double>) {
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self._sliderValue = sliderValue
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background container
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
                
                HStack(spacing: 0) {
                    // Before side (left)
                    ZStack {
                        Image(beforeImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                        
                        // Gradient overlay at the start of image
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.2),
                                Color.gray.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.3)
                        .position(x: geometry.size.width * 0.15, y: geometry.size.height * 0.5)
                        
                        VStack {
                            Spacer()
                            HStack {
                                Text("Before")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(6)
                                Spacer()
                            }
                            .padding(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .mask(
                        Rectangle()
                            .size(
                                width: geometry.size.width * sliderValue,
                                height: geometry.size.height
                            )
                            .position(
                                x: (geometry.size.width * sliderValue) * 0.5,
                                y: geometry.size.height * 0.5
                            )
                    )
                    
                    Spacer()
                }
                
                HStack(spacing: 0) {
                    Spacer()
                    
                    // After side (right)
                    ZStack {
                        Image(afterImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                        
                        // Enhanced gradient overlay at the start of enhanced image
                        LinearGradient(
                            colors: [
                                Color(red: 58/255, green: 207/255, blue: 255/255).opacity(0.25), // Cyan accent
                                Color(red: 120/255, green: 220/255, blue: 255/255).opacity(0.15),
                                Color(red: 180/255, green: 235/255, blue: 255/255).opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.4)
                        .position(x: geometry.size.width * sliderValue + geometry.size.width * 0.2, y: geometry.size.height * 0.5)
                        
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("After")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 58/255, green: 207/255, blue: 255/255).opacity(0.8),
                                                Color(red: 120/255, green: 220/255, blue: 255/255).opacity(0.6)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(6)
                            }
                            .padding(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .mask(
                        Rectangle()
                            .size(
                                width: geometry.size.width * (1 - sliderValue),
                                height: geometry.size.height
                            )
                            .position(
                                x: geometry.size.width * sliderValue + (geometry.size.width * (1 - sliderValue)) * 0.5,
                                y: geometry.size.height * 0.5
                            )
                    )
                }
                
                // Divider line
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 3)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 0)
                    .shadow(color: .white.opacity(0.8), radius: 2, x: -1, y: 0)
                    .position(
                        x: geometry.size.width * sliderValue,
                        y: geometry.size.height * 0.5
                    )
                
                // Invisible drag area
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let newValue = max(0, min(1, value.location.x / geometry.size.width))
                                sliderValue = newValue
                            }
                            .onEnded { _ in
                                isDragging = false
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
