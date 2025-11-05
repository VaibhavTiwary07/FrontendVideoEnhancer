import SwiftUI

struct EnhancementOptionSelector: View {
    let enhancementType: String
    @State private var selectedOption: String = ""
    @State private var isProcessing = false
    @State private var isShowingPaywall = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var options: [EnhancementOption] {
        switch enhancementType {
        case "AI Upscale":
            return [
                EnhancementOption(id: "2x", title: "", description: "", icon: "arrow.up.right.square", isRecommended: true),
                EnhancementOption(id: "3x", title: "", description: "", icon: "plus.magnifyingglass"),
                EnhancementOption(id: "4x", title: "", description: "", icon: "rectangle.expand.vertical"),
                EnhancementOption(id: "1080p", title: "", description: "", icon: "tv.and.hifispeaker.fill")
            ]
        case "AI Denoise":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Gentle noise reduction", icon: "waveform.path"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced reduction", icon: "sparkles", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive removal", icon: "slider.horizontal.3")
            ]
        case "AI Auto Enhancement":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Subtle improvements", icon: "dial.low"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced enhancement", icon: "wand.and.stars", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Maximum enhancement", icon: "dial.high.fill")
            ]
        case "Stabilizer":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Gentle stabilization", icon: "level"),
                EnhancementOption(id: "medium", title: "Medium", description: "Standard stabilization", icon: "gyroscope", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive stabilization", icon: "arrow.triangle.2.circlepath")
            ]
        case "AI Frame Interpolation":
            return [
                EnhancementOption(id: "smooth", title: "Smooth", description: "Enhanced motion smoothness", icon: "play.rectangle.fill", isRecommended: true),
                EnhancementOption(id: "fluid", title: "Fluid", description: "Ultra-smooth motion", icon: "forward.frame.fill")
            ]
        default:
            return []
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Choose \(enhancementType) Level")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                    Text("Select the enhancement level that best fits your video")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 20)

                // Options Grid (centered for single, partial, and full rows)
                Group {
                    let columnsCount = isIPad ? max(1, min(2, options.count)) : 1
                    let rows: [[EnhancementOption]] = stride(from: 0, to: options.count, by: columnsCount).map { start in
                        let end = min(start + columnsCount, options.count)
                        return Array(options[start..<end])
                    }
                    VStack(spacing: 16) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            if row.count == columnsCount {
                                HStack(spacing: 16) {
                                    ForEach(row, id: \.id) { option in
                                        let pro = isProOption(for: enhancementType, optionId: option.id)
                                        OptionCard(
                                            option: option,
                                            isSelected: selectedOption == option.id,
                                            showsProBadge: false,//pro && !SubscriptionManager.shared.isAppSubscribed()
                                            onTap: {
                                                let impact = UIImpactFeedbackGenerator(style: .light)
                                                impact.impactOccurred()
//                                                if pro && !SubscriptionManager.shared.isAppSubscribed() {
//                                                    isShowingPaywall = true
//                                                } else {
                                                    selectedOption = option.id
                                               // }
                                            }
                                        )
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            } else {
                                HStack(spacing: 16) {
                                    Spacer(minLength: 0)
                                    ForEach(row, id: \.id) { option in
                                        let pro = isProOption(for: enhancementType, optionId: option.id)
                                        OptionCard(
                                            option: option,
                                            isSelected: selectedOption == option.id,
                                            showsProBadge: false ,//pro && !SubscriptionManager.shared.isAppSubscribed()
                                            onTap: {
                                                let impact = UIImpactFeedbackGenerator(style: .light)
                                                impact.impactOccurred()
//                                                if pro && !SubscriptionManager.shared.isAppSubscribed() {
//                                                    isShowingPaywall = true
//                                                } else {
                                                    selectedOption = option.id
                                               // }
                                            }
                                        )
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Continue Button
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    isProcessing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isProcessing = false
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 18, weight: .medium))

                        Text("Process Video")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(selectedOption.isEmpty)
                .opacity(selectedOption.isEmpty ? 0.6 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }

            if isProcessing {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(1.5)
            }
        }
        .fullScreenCover(isPresented: $isShowingPaywall) {
            PaywallView(isPresented: $isShowingPaywall)
        }
        .onAppear {
            // Check subscription expiry on app launch
            SubscriptionManager.shared.checkSubscriptionExpiry()
            
            // Select recommended option by default
            if let recommended = options.first(where: { $0.isRecommended }) {
                selectedOption = recommended.id
            } else if let first = options.first {
                selectedOption = first.id
            }
        }
    }
}

// MARK: - Option Card Component

struct OptionCard: View {
    let option: EnhancementOption
    let isSelected: Bool
    let showsProBadge: Bool
    let onTap: () -> Void

    private var titleColor: Color {
        isSelected ? .white : Color.accentWarm
    }

    private var recommendedTextColor: Color {
        isSelected ? .white.opacity(0.9) : Color.accentWarm.opacity(0.7)
    }

    private var recommendedBackground: LinearGradient {
        if isSelected {
            return LinearGradient(colors: [Color.white.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.47, blue: 0.47).opacity(0.3),
                    Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.3)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var cardBackground: LinearGradient {
        if isSelected {
            return LinearGradient.primaryTheme
        } else {
            return LinearGradient(colors: [Color.cardSoft], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var strokeColor: Color {
        isSelected ? Color.white.opacity(0.2) : Color.accentWarm.opacity(0.3)
    }

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.accentWarm)

                Text(option.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)

                if option.isRecommended {
                    Text("RECOMMENDED")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(recommendedTextColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(recommendedBackground)
                        )
                }
            }
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 6 : 3, x: 0, y: isSelected ? 3 : 2)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .overlay(alignment: .topTrailing) {
                if showsProBadge {
                    ProPill()
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Pro Pill Component

private struct ProPill: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient.primaryTheme)
            )
            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Helper Functions

private func isProOption(for enhancementType: String, optionId: String) -> Bool {
    switch enhancementType {
    case "AI Upscale":
        return optionId.lowercased() == "2x" || optionId.lowercased() == "4x" || optionId == "2K" || optionId == "4K"
    case "AI Denoise", "AI Auto Enhancement", "Stabilizer":
        return optionId == "medium" || optionId == "high"
    default:
        return false
    }
}

// EnhancementOption is now defined in EnhancementServiceProtocol.swift to avoid conflicts

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        EnhancementOptionSelector(enhancementType: "AI Upscale")
    }
}
