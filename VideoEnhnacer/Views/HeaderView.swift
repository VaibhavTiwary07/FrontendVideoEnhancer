import SwiftUI

struct HeaderView: View {
    @Binding var isSidebarExpanded: Bool
    
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
                        .fill(Color.cardBackground)
                        .neomorphicStyle(cornerRadius: 18, shadowRadius: 4)
                )
            }
            .buttonStyle(NeomorphicHamburgerStyle())
            
            Spacer()
            
            // App Title (Optional)
            Text("Video Enhancer")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primaryText)
            
            Spacer()
            
            // Right side placeholder for future actions
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.cardBackground)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
    }
}

#Preview {
    VStack {
        HeaderView(isSidebarExpanded: .constant(false))
        Spacer()
    }
    .background(Color.appBackground)
}
