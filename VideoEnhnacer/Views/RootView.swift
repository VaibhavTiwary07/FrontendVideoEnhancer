import SwiftUI

struct RootView: View {
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            ContentView()
                .opacity(showSplash ? 0 : 1)
            
            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Keep splash for a brief, polished intro
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    RootView()
}

