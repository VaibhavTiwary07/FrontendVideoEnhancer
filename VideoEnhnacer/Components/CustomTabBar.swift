import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @State private var tappedTab: Int? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(
                icon: "house",
                title: "Home",
                isSelected: selectedTab == 0,
                isTapped: tappedTab == 0
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    tappedTab = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedTab = 0
                    tappedTab = nil
                }
            }
            
            TabBarItem(
                icon: "folder",
                title: "My Creations",
                isSelected: selectedTab == 1,
                isTapped: tappedTab == 1
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    tappedTab = 1
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedTab = 1
                    tappedTab = nil
                }
            }
        }
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.cardBackground)
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: -2
                )
        )
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let isTapped: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                backgroundFill
                    .scaleEffect(isTapped ? 0.95 : 1.0)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.1), value: isTapped)
    }
    
    private var iconColor: Color {
        if isTapped {
            return .white
        } else if isSelected {
            return Color(red: 1.0, green: 0.596, blue: 0.329)
        } else {
            return .secondaryText
        }
    }
    
    private var textColor: Color {
        if isTapped {
            return .white
        } else if isSelected {
            return .primaryText
        } else {
            return .secondaryText
        }
    }
    
    @ViewBuilder
    private var backgroundFill: some View {
        if isTapped {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.47, blue: 0.47),
                            Color(red: 1.0, green: 0.596, blue: 0.329),
                            Color(red: 0.988, green: 0.753, blue: 0.424)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else if isSelected {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.47, blue: 0.47).opacity(0.1),
                            Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.1),
                            Color(red: 0.988, green: 0.753, blue: 0.424).opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        CustomTabBar(selectedTab: .constant(0))
    }
    .background(Color.appBackground)
}