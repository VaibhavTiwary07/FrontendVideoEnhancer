import SwiftUI

struct VideoResultsView: View {
    let originalVideoURL: URL
    let processedVideoURL: URL
    let enhancementType: String
    let enhancementIcon: String
    let gradientType: GradientType
    
    @Environment(\.dismiss) private var dismiss
    @State private var saveSuccess = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ResultsHeaderSection(
                        enhancementType: enhancementType,
                        saveSuccess: saveSuccess
                    )
                    .padding(.top, 40)
                
                    VideoComparisonView(
                        originalVideoURL: originalVideoURL,
                        processedVideoURL: processedVideoURL,
                        saveSuccess: $saveSuccess
                    )
                    .padding(.top, 30)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button("Back to Trimming") {
                        dismiss()
                    }
                    
                    Button("Back to Home") {
                        dismissToHome()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func dismissToHome() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let presentingVC = window.rootViewController?.presentedViewController {
                presentingVC.dismiss(animated: true)
            }
        }
    }
}

struct ResultsHeaderSection: View {
    let enhancementType: String
    let saveSuccess: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient.primaryTheme)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(saveSuccess ? 1.1 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: saveSuccess)
            
            VStack(spacing: 8) {
                Text("Enhancement Complete!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text("Your video has been enhanced with \(enhancementType)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { step in
                    Circle()
                        .fill(Color.white)
                        .frame(width: step == 4 ? 10 : 8, height: step == 4 ? 10 : 8)
                }
            }
            .padding(.top, 10)
        }
    }
}


struct ActionButtonsSection: View {
    let processedVideoURL: URL
    let isSaving: Bool
    let saveToPhotoLibrary: () -> Void
    let dismissToHome: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    saveToPhotoLibrary()
                }) {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 18, weight: .medium))
                        }
                        
                        Text(isSaving ? "Saving..." : "Save")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(isSaving)
                
                ShareLink(item: processedVideoURL) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 18, weight: .medium))
                        
                        Text("Share")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 20)
            
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                dismissToHome()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Process Another Video")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    NavigationView {
        VideoResultsView(
            originalVideoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            processedVideoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            enhancementType: "AI Upscale",
            enhancementIcon: "arrow.up.square",
            gradientType: .redPink
        )
    }
}