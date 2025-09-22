import SwiftUI

struct SplashView: View {
    @State private var appear = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            HStack(spacing: 16) {
                ZStack {
                    Image("splashIcon")
//                    RoundedRectangle(cornerRadius: 16, style: .continuous)
//                        .fill(LinearGradient.primaryTheme)
//                        .frame(width: 96, height: 96)
//                        .shadow(color: .white.opacity(0.05), radius: 8, x: 0, y: 0)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 16, style: .continuous)
//                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
//                        )
//
//                    Text("AI")
//                        .font(.system(size: 44, weight: .black, design: .default))
//                        .kerning(1)
//                        .foregroundColor(.white)
//                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                }
                
                VStack(alignment: .leading, spacing: -2) {
                    Text(" AI Video")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("Enhancer")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .scaleEffect(appear ? 1 : 0.92)
            .opacity(appear ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.9).delay(0.05), value: appear)
        }
        .onAppear { appear = true }
    }
}

#Preview {
    SplashView()
}
