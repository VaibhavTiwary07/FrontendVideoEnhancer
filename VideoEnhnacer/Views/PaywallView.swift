import SwiftUI
import StoreKit

struct PaywallView: View {
    @Binding var isPresented: Bool
    @State private var selectedPlan: String? // Optional to handle initial state
    @State private var products: [SKProduct] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showErrorAlert: Bool = false // For alert-based error display

    // MARK: - Dynamic Content
    private func priceTitle(for productId: String) -> String {
        SubscriptionManager.shared.getPrice(for: productId)
    }

    private func priceSubtitle(for productId: String) -> String {
        let trialDays = SubscriptionManager.shared.getTrialPeriodDays(for: productId)
        let price = SubscriptionManager.shared.getPrice(for: productId)
        if trialDays > 0 {
            return "\(trialDays)-day free trial • then \(price)"
        }
        return "Billed \(productId.contains("yearly") ? "yearly" : productId.contains("monthly") ? "monthly" : "weekly")"
    }

    private func badgeText(for productId: String) -> String? {
        productId.contains("yearly") ? "Best Value" : nil
    }

    private func trialText(for productId: String) -> String? {
        let trialDays = SubscriptionManager.shared.getTrialPeriodDays(for: productId)
        return trialDays > 0 ? "\(trialDays)-Days Free Trial" : nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Top hero with parallax background image
                    ZStack(alignment: .topTrailing) {
                        ParallaxHeader(imageName: "PaywalImage", height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                VStack(spacing: 8) {
                                    Text("VideoEnhancement")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    ProBadge()
                                }
                            )
                    }

                    // Content container (dark gradient)
                    VStack(alignment: .leading, spacing: 18) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else if products.isEmpty {
                            Text("No subscription plans available")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            FeatureList(foreground: .white)

                            ForEach(products, id: \.productIdentifier) { product in
                                planCard(
                                    title: priceTitle(for: product.productIdentifier),
                                    subtitle: nil,
                                    trialText: trialText(for: product.productIdentifier),
                                    showBadge: badgeText(for: product.productIdentifier) != nil,
                                    isSelected: selectedPlan == product.productIdentifier,
                                    action: { selectedPlan = product.productIdentifier }
                                )
                            }

                            // Continue button and text pinned to the bottom of the scroll content
                            Button(action: {
                                guard let selectedPlan = selectedPlan,
                                      let product = products.first(where: { $0.productIdentifier == selectedPlan }) else {
                                    errorMessage = "Please select a valid plan"
                                    showErrorAlert = true
                                    return
                                }
                                isLoading = true
                                SubscriptionManager.shared.purchaseProduct(product) { success, error in
                                    isLoading = false
                                    if success {
                                        print("✅ Purchase successful for \(product.productIdentifier)")
                                        isPresented = false // Close paywall on success
                                    } else if let error = error {
                                        print("❌ Purchase failed: \(error.localizedDescription)")
                                        errorMessage = error.localizedDescription
                                        showErrorAlert = true
                                        // Clear error after 3 seconds
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                            errorMessage = nil
                                            showErrorAlert = false
                                        }
                                    }
                                }
                            }) {
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
                            .disabled(selectedPlan == nil || products.isEmpty)
                            .padding(.top, 10)

                            if let selectedPlan = selectedPlan {
                                Text("Auto Renews \(priceTitle(for: selectedPlan)). You can cancel anytime.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .top)
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
                    .padding(.top, -28) // Overlap into the header
                }
                .frame(maxWidth: .infinity)
                // Add bottom padding to ensure the content is not cut off
                .padding(.bottom, 50)
            }
            .ignoresSafeArea(edges: .top)
        }
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
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Purchase Error"),
                message: Text(errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK")) {
                    errorMessage = nil
                    showErrorAlert = false
                }
            )
        }
        .onAppear {
            isLoading = true
            SubscriptionManager.shared.fetchProducts { products, error in
                isLoading = false
                if let error = error {
                    print("❌ Failed to fetch products: \(error.localizedDescription)")
                    errorMessage = "Failed to load subscription plans"
                    showErrorAlert = true
                    return
                }
                if let products = products, !products.isEmpty {
                    self.products = products.sorted { product1, product2 in
                        if product1.productIdentifier.contains("yearly") {
                            return true
                        } else if product2.productIdentifier.contains("yearly") {
                            return false
                        }
                        return product1.productIdentifier < product2.productIdentifier
                    }
                    selectedPlan = self.products.first { $0.productIdentifier.contains("yearly") }?.productIdentifier ?? self.products.first?.productIdentifier
                    print("Selected plan set to: \(selectedPlan ?? "none")")
                } else {
                    errorMessage = "No subscription plans available"
                    showErrorAlert = true
                }
            }
        }
    }

    // MARK: - Plan Card
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
                        .offset(x: 1, y: -1) // Fine-tune to align with the top-right corner
                        .padding(0) // Remove extra padding to ensure flush alignment
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Other supporting views (ParallaxHeader, ProBadge, FeatureList) remain unchanged
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
            .background(Color.gray.opacity(0.1))
            .preferredColorScheme(.light)
    }
}
#endif
