import SwiftUI

struct PaywallView: View {
    @Binding var isPresented: Bool
    @State private var selectedPlan: Plan = .yearly
    
    enum Plan { case yearly, weekly }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top hero gradient
                ZStack(alignment: .topTrailing) {
                    LinearGradient.primaryTheme
                        .frame(height: 220)
                        .overlay(
                            VStack(spacing: 8) {
                                Text("Video Enhancer")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                ProBadge()
                            }
                        )
                    
                    // Close button
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.25))
                            .clipShape(Circle())
                            .padding(16)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                // Content container (white theme)
                VStack(alignment: .leading, spacing: 20) {
                    FeatureList()
                    
                    VStack(spacing: 14) {
                        planCard(
                            title: "₹ 1,549/year",
                            subtitle: "7-day free trial",
                            badge: "Save more than 80%",
                            isSelected: selectedPlan == .yearly,
                            action: { selectedPlan = .yearly }
                        )
                        
                        planCard(
                            title: "₹ 249/week",
                            subtitle: "",
                            badge: nil,
                            isSelected: selectedPlan == .weekly,
                            action: { selectedPlan = .weekly }
                        )
                    }
                    
                    Button(action: { /* TODO: hook to purchase */ }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient.primaryTheme
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            )
                    }
                    
                    Text("Auto‑renews. Cancel anytime in Settings.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: -4)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }
    
    @ViewBuilder
    private func planCard(title: String, subtitle: String, badge: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                    if !subtitle.isEmpty { Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary) }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentWarm : .gray)
                    .font(.system(size: 22, weight: .semibold))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AnyShapeStyle(LinearGradient.primaryTheme) : AnyShapeStyle(Color.black.opacity(0.1)), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
            )
            .overlay(alignment: .topTrailing) {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient.primaryTheme
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        )
                        .padding(6)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ProBadge: View {
    var body: some View {
        Text("Pro")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(LinearGradient.primaryTheme, lineWidth: 1)
                    )
            )
    }
}

private struct FeatureList: View {
    private let items = [
        "Access all premium templates",
        "Higher quality video output",
        "No ads or watermarks",
        "All voice variations unlocked"
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items, id: \.self) { text in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentWarm)
                    Text(text)
                        .foregroundColor(.primary)
                        .font(.system(size: 15))
                }
            }
        }
    }
}

#if DEBUG
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView(isPresented: .constant(true))
            .background(Color.appBackground)
            .preferredColorScheme(.light)
    }
}
#endif
