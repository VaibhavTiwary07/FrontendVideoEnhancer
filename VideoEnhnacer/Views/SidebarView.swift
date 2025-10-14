import SwiftUI
import StoreKit

struct SidebarView: View {
    @State private var showingRestoreConfirmationAlert = false
    @State private var showingRestoreResultAlert = false
    @State private var restoreResultMessage = ""
    
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
                // Write Review (triggers in-app review prompt)
                SidebarMenuItem(
                    icon: "square.and.pencil",
                    title: "Write Review"
                ) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showRateUsPanel()
                }
                .accessibilityLabel("Write a review")
                
                // Website (clickable link)
                Link(destination: URL(string: "https://metis.company")!) {
                    SidebarMenuItemContent(icon: "globe", title: "Website", isPressed: false)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                })
                .accessibilityLabel("Visit Metis website")
                
                // Restore Purchase (triggers confirmation alert)
                SidebarMenuItem(
                    icon: "cart.circle",
                    title: "Restore Purchase"
                ) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showingRestoreConfirmationAlert = true
                }
                .accessibilityLabel("Restore purchases")
                
                // Privacy Policy (clickable link)
                Link(destination: URL(string: "https://www.outthinkingindia.com/privacy-policy/")!) {
                    SidebarMenuItemContent(icon: "lock.shield", title: "Privacy Policy", isPressed: false)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                })
                .accessibilityLabel("View Privacy Policy")
                
                // Terms of Use (clickable link with iOS 15.0 fallback)
                Link(destination: URL(string: "https://www.outthinkingindia.com/terms-of-use/")!) {
                    SidebarMenuItemContent(
                        icon: "doc.text",
                        title: "Terms of Use",
                        isPressed: false
                    )
                }
                .simultaneousGesture(TapGesture().onEnded {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                })
                .accessibilityLabel("View Terms of Use")
            }
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .frame(width: 225)
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
        // Confirmation alert for Restore Purchase
        .alert("Restore Purchases", isPresented: $showingRestoreConfirmationAlert) {
            Button("Restore") {
                SubscriptionManager.shared.restorePurchases { success, error in
                    DispatchQueue.main.async {
                        if success {
                            restoreResultMessage = "Purchases restored successfully!"
                        } else if let skError = error as? SKError {
                            switch skError.code {
                            case .paymentCancelled:
                                restoreResultMessage = "Restore cancelled."
                            case .clientInvalid:
                                restoreResultMessage = "Purchases are disabled on this device."
                            case .paymentNotAllowed:
                                restoreResultMessage = "Purchases are not allowed on this device."
                            default:
                                restoreResultMessage = "Failed to restore purchases: \(skError.localizedDescription)"
                            }
                        } else {
                            restoreResultMessage = error?.localizedDescription ?? "No purchases to restore."
                        }
                        showingRestoreResultAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Would you like to restore your previous purchases?")
        }
        // Result alert for Restore Purchase
        .alert("Restore Purchases", isPresented: $showingRestoreResultAlert) {
            Button("OK") {
                restoreResultMessage = "" // Reset message after dismissal
            }
        } message: {
            Text(restoreResultMessage)
        }
    }
    
    private func showRateUsPanel() {
        print("Showing rate us panel")
        // Ensure UI-related code runs on the main thread
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.windows.first?.windowScene {
                if #available(iOS 14.0, *) {
                    SKStoreReviewController.requestReview(in: windowScene)
                } else {
                    SKStoreReviewController.requestReview()
                }
            } else {
                print("Error: UIWindowScene is unavailable")
            }
        }
    }
    
    // Helper for iOS 15.1+ icon compatibility
    private func ifAvailableiOS15dot1(_ preferred: String, fallback: String) -> String {
        if #available(iOS 15.1, *) {
            return preferred
        } else {
            return fallback
        }
    }
}

// Helper view for SidebarMenuItem content
struct SidebarMenuItemContent: View {
    let icon: String
    let title: String
    let isPressed: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isPressed ? .white : .secondaryText)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isPressed ? .white : .primaryText)
                .lineLimit(1) // Prevent text wrapping
                .truncationMode(.tail) // Truncate with ellipsis if too long
                .accessibilityLabel(title) // Full text for VoiceOver
            
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
    }
}

// SidebarMenuItem for non-link actions
struct SidebarMenuItem: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            SidebarMenuItemContent(icon: icon, title: title, isPressed: isPressed)
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

// NeomorphicHamburgerStyle remains unchanged
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

