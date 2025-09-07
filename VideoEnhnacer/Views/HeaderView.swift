import SwiftUI

struct HeaderView: View {
    @Binding var isSidebarExpanded: Bool
    @Binding var isShowingPaywall: Bool
    @Binding var selectedCarouselSegment: Int
    
    var body: some View {
        HStack {
            // Hamburger Menu Button
            Button(action: {
                withAnimation(.easeOut) {
                    isSidebarExpanded.toggle()
                }
            }) {
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(Color.primaryText)
                        .frame(width: 18, height: 2)
                        .cornerRadius(1)
                    Rectangle()
                        .fill(Color.primaryText)
                        .frame(width: 18, height: 2)
                        .cornerRadius(1)
                    Rectangle()
                        .fill(Color.primaryText)
                        .frame(width: 18, height: 2)
                        .cornerRadius(1)
                }
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Carousel title placed to the right of hamburger
            Text(titleForIndex(selectedCarouselSegment))
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.leading, 8)
            
            Spacer()
            
            // Pro Button
            Button(action: {
                isShowingPaywall = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("Pro")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: 70, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient.primaryTheme)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.clear)
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
    VStack {
        HeaderView(
            isSidebarExpanded: .constant(false),
            isShowingPaywall: .constant(false),
            selectedCarouselSegment: .constant(0)
        )
        Spacer()
    }
    .background(Color.appBackground)
}
