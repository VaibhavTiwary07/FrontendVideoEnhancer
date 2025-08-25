import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var content: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "gear")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primaryText)
                    
                    Text("Configure app preferences and enhance your video editing experience.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    dismiss()
                }
                .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329))
            }
        }
    }
}

struct ProjectsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var content: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "folder")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("Projects")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primaryText)
                    
                    Text("Your video enhancement projects and saved work will appear here.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    dismiss()
                }
                .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329))
            }
        }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var content: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("Help & Support")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primaryText)
                    
                    Text("Get help with using VideoEnhancer, tutorials, and contact support.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    dismiss()
                }
                .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329))
            }
        }
    }
}

#Preview {
    SettingsView()
}