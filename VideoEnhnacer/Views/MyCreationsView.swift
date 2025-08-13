import SwiftUI

struct MyCreationsView: View {
    @State private var selectedFilter: CreationFilter = .all
    
    enum CreationFilter: String, CaseIterable {
        case all = "All"
        case recent = "Recent"
        case favorites = "Favorites"
        case processing = "Processing"
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 20) {
                    Text("My Creations")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Filter Tabs
                    HStack(spacing: 12) {
                        ForEach(CreationFilter.allCases, id: \.self) { filter in
                            FilterTab(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Content
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(mockCreations, id: \.id) { creation in
                            CreationCard(creation: creation)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
    }
}

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? 
                              LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.47, blue: 0.47),
                                    Color(red: 1.0, green: 0.596, blue: 0.329)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                              ) : 
                              LinearGradient(
                                colors: [Color.cardBackground],
                                startPoint: .leading,
                                endPoint: .trailing
                              )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.2), lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CreationCard: View {
    let creation: MockCreation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.2),
                            Color.gray.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .overlay(
                    VStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 48, height: 48)
                            )
                        
                        Text("Video Preview")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(creation.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(creation.date)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondaryText)
                
                HStack {
                    StatusBadge(status: creation.status)
                    Spacer()
                    
                    Button(action: {
                        print("More options for \(creation.title)")
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .neomorphicStyle()
        .onTapGesture {
            print("Selected \(creation.title)")
        }
    }
}

struct StatusBadge: View {
    let status: CreationStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(status.color.opacity(0.1))
            )
    }
}

// MARK: - Mock Data
struct MockCreation {
    let id = UUID()
    let title: String
    let date: String
    let status: CreationStatus
}

enum CreationStatus: String, CaseIterable {
    case completed = "Completed"
    case processing = "Processing"
    case failed = "Failed"
    
    var color: Color {
        switch self {
        case .completed:
            return .green
        case .processing:
            return Color(red: 1.0, green: 0.596, blue: 0.329)
        case .failed:
            return .red
        }
    }
}

let mockCreations = [
    MockCreation(title: "Enhanced Video 1", date: "Today", status: .completed),
    MockCreation(title: "AI Upscaled Video", date: "Yesterday", status: .processing),
    MockCreation(title: "Color Corrected", date: "2 days ago", status: .completed),
    MockCreation(title: "Stabilized Footage", date: "3 days ago", status: .failed),
    MockCreation(title: "Denoised Video", date: "1 week ago", status: .completed),
    MockCreation(title: "Frame Interpolated", date: "1 week ago", status: .completed)
]

#Preview {
    MyCreationsView()
}