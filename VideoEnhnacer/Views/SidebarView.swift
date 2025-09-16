import SwiftUI

struct SidebarView: View {
    @State private var showingFavorites = false
    @State private var showingSettings = false
    @State private var showingProjects = false
    @State private var showingHelp = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Menu")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Menu Items
            VStack(spacing: 16) {
                SidebarMenuItem(
                    icon: "gear",
                    title: "Settings"
                ) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showingSettings = true
                }
                
                SidebarMenuItem(
                    icon: "folder",
                    title: "Projects"
                ) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showingProjects = true
                }
                
//                SidebarMenuItem(
//                    icon: "heart",
//                    title: "Favorites"
//                ) {
//                    let impact = UIImpactFeedbackGenerator(style: .light)
//                    impact.impactOccurred()
//                    showingFavorites = true
//                }
                
                SidebarMenuItem(
                    icon: "questionmark.circle",
                    title: "Help"
                ) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showingHelp = true
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.cardBackground)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 10,
                    x: 2,
                    y: 0
                )
        )
        .fullScreenCover(isPresented: $showingFavorites) {
            FavoritesView()
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showingProjects) {
            ProjectsView()
        }
        .fullScreenCover(isPresented: $showingHelp) {
            HelpView()
        }
    }
}

struct SidebarMenuItem: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isPressed ? .white : .secondaryText)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isPressed ? .white : .primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPressed ? 
                          AnyShapeStyle(LinearGradient.primaryTheme.opacity(0.7)) : 
                          AnyShapeStyle(LinearGradient(
                            colors: [Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                          ))
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

struct NeomorphicHamburgerStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .background(
                Circle()
                    .fill(configuration.isPressed ? 
                          AnyShapeStyle(LinearGradient.primaryTheme.opacity(0.2)) : 
                          AnyShapeStyle(LinearGradient(
                            colors: [Color.cardBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                configuration.isPressed ? 
                                Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.3) : 
                                Color.clear, 
                                lineWidth: 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    HStack {
        SidebarView()
        
        Spacer()
    }
    .background(Color.appBackground)
}
