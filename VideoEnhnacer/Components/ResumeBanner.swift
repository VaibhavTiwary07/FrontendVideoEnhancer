//import SwiftUI
//
//struct ResumeBanner: View {
//    var onResume: () -> Void
//
//    var body: some View {
//        HStack(spacing: 12) {
//            Image(systemName: "play.circle")
//                .font(.system(size: 20, weight: .medium))
//                .foregroundColor(.white.opacity(0.8))
//
//            Text("Resume")
//                .font(.system(size: 16, weight: .semibold))
//                .foregroundColor(.white)
//
//            Spacer()
//
//            Button(action: onResume) {
//                Text("Continue")
//                    .font(.system(size: 15, weight: .bold))
//                    .padding(.horizontal, 14)
//                    .padding(.vertical, 8)
//                    .background(
//                        Capsule().fill(LinearGradient.primaryTheme)
//                    )
//                    .foregroundColor(.white)
//            }
//        }
//        .padding(14)
//        .background(
//            RoundedRectangle(cornerRadius: 16)
//                .fill(Color.black.opacity(0.72))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 16)
//                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
//                )
//                .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 6)
//        )
//    }
//}
//
//#Preview {
//    ResumeBanner { }
//        .padding()
//        .background(Color.gray.opacity(0.3))
//}
//
