//
//  ContentView.swift
//  VideoEnhnacer
//
//  Created by Vaibhav Tiwary on 13/08/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var videoPlayerManager = VideoPlayerManager()
    @State private var selectedTab = 0
    @State private var isSidebarExpanded = false // Start collapsed by default
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            // Main Content - Full Width
            VStack(spacing: 0) {
                // Header with Hamburger Menu
                HeaderView(isSidebarExpanded: $isSidebarExpanded)
                
                // Content Area
                Group {
                    switch selectedTab {
                    case 0:
                        HomeView(videoPlayerManager: videoPlayerManager)
                    case 1:
                        MyCreationsView()
                    default:
                        HomeView(videoPlayerManager: videoPlayerManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
                
                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
            }
            .disabled(isSidebarExpanded) // Disable interaction when sidebar is open
            
            // Backdrop Overlay
            if isSidebarExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarExpanded = false
                        }
                    }
            }
            
            // Sidebar - Only show when hamburger is clicked
            if isSidebarExpanded {
                HStack {
                    SidebarView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    
                    Spacer()
                }
            }
        }
        .background(Color.appBackground)
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: isSidebarExpanded)
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                videoPlayerManager.pauseAllPlayers()
            case .active:
                videoPlayerManager.resumeActiveViewPlayers()
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
