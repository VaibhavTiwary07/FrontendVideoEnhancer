import SwiftUI

struct PaywallView: View {
    @Binding var isPresented: Bool
    @State private var selectedPlan: Plan = .yearly
    
    enum Plan { case yearly, weekly }
    
    // MARK: - Dynamic Content
    private var priceTitle: String {
        switch selectedPlan {
        case .yearly: return "₹ 1,549/year"
        case .weekly: return "₹ 249/week"
        }
    }
    private var priceSubtitle: String {
        switch selectedPlan {
        case .yearly: return "7‑day free trial • then ₹ 1,549/yr"
        case .weekly: return "Billed weekly"
        }
    }
    private var badgeText: String? {
        switch selectedPlan {
        case .yearly: return "Best Value"
        case .weekly: return nil
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top hero with parallax background image
                ZStack(alignment: .topTrailing) {
                    ParallaxHeader(imageName: "PaywalImage", height: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            VStack(spacing: 8) {
                                Text("VideoEnhacement")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                ProBadge()
                            }
//                            .padding(, 24)
                        )
                }
                
                // Content container (dark gradient) — overlaps header slightly and fills to bottom
                VStack(alignment: .leading, spacing: 18) {
                    FeatureList(foreground: .white)

                    planCard(
                        title: "₹ 1,549/year",
                        subtitle: nil,
                        trialText: "7‑Days Free Trial",
                        showBadge: true,
                        isSelected: selectedPlan == .yearly,
                        action: { selectedPlan = .yearly }
                    )

                    planCard(
                        title: "₹ 249/week",
                        subtitle: nil,
                        trialText: nil,
                        showBadge: false,
                        isSelected: selectedPlan == .weekly,
                        action: { selectedPlan = .weekly }
                    )

                    Button(action: { /* TODO: hook to purchase */ }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient.primaryTheme
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            )
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 6)
                    }

                    Text("Auto Renews 1,549/year. You can cancel anytime.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.2),
                            Color.black.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, -28) // overlap into the header
                .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
        }
        // Global close button overlay: always on top and tappable
        .overlay(alignment: .topTrailing) {
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .zIndex(1000)
        }
    }
    
    // MARK: - Segmented Plan Toggle
    @ViewBuilder
    private func planToggle() -> some View {
        HStack(spacing: 8) {
            planPill(title: "Yearly", subtitle: "7‑day trial", isSelected: selectedPlan == .yearly) {
                selectedPlan = .yearly
            }
            planPill(title: "Weekly", subtitle: nil, isSelected: selectedPlan == .weekly) {
                selectedPlan = .weekly
            }
        }
    }

    @ViewBuilder
    private func planPill(title: String, subtitle: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.clear)
                            .overlay(
                                LinearGradient.primaryTheme
                                    .mask(
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                    )
                            )
                    }
                }
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isSelected {
                        LinearGradient.primaryTheme
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Color.white
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            )
            .foregroundColor(isSelected ? .black : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.black.opacity(0.08) : .clear, radius: 6, x: 0, y: 3)
            .overlay(alignment: .topTrailing) {
                if isSelected && title == "Yearly", let badge = badgeText {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient.primaryTheme
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        )
                        .offset(x: 8, y: -12)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Price Highlight
    @ViewBuilder
    private func priceHighlight() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(priceTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            Text(priceSubtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(LinearGradient.primaryTheme, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    @ViewBuilder
    private func planCard(title: String, subtitle: String?, trialText: String?, showBadge: Bool, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    if let trialText = trialText {
                        Text(trialText)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.75))
                    } else if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                Spacer()
                if isSelected {
                    // Gradient tick using app's primary orange gradient
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient.primaryTheme
                                .mask(
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                )
                        )
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 22, weight: .semibold))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AnyShapeStyle(LinearGradient.primaryTheme) : AnyShapeStyle(Color.white.opacity(0.15)), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if showBadge {
                    Text("Save more than 80%")
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

private struct ParallaxHeader: View {
    let imageName: String
    let height: CGFloat
    private let speed: CGFloat = 20 // px/sec
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let width = max(geo.size.width, 1)
                let tileWidth = width * 1.5
                // Compute horizontal offset looping every (tileWidth) at given speed
                let travel = CGFloat(t) * speed
                let offset = -CGFloat(travel.truncatingRemainder(dividingBy: tileWidth))
                
                ZStack {
                    HStack(spacing: 0) {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: tileWidth, height: height)
                            .clipped()
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: tileWidth, height: height)
                            .clipped()
                    }
                    .offset(x: offset)
                    .frame(width: width, height: height, alignment: .leading)
                    .clipped()
                    
                    // Subtle top→bottom shading for readability
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: width, height: height)
            }
        }
        .frame(height: height)
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
    var foreground: Color = .primary
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
                    // Gradient checkmark to match app theme
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient.primaryTheme
                                .mask(
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                )
                        )
                    Text(text)
                        .foregroundColor(foreground)
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
