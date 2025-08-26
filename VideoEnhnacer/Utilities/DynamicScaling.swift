import SwiftUI
import UIKit

// MARK: - Device Size Categories
/// Comprehensive device size categories for granular responsive design
enum DeviceSize: CaseIterable {
    case compact    // iPod touch, iPhone SE (3.5" - 4.7")
    case standard   // iPhone 14, 15 (6.1")
    case large      // iPhone Pro Max (6.7")  
    case tablet     // iPad mini (8.3")
    case desktop    // iPad Pro 11", 13" (11" - 13")
    
    /// Screen width thresholds for device categorization
    static func from(screenWidth: CGFloat) -> DeviceSize {
        switch screenWidth {
        case 0..<375:       return .compact    // iPod touch, iPhone SE
        case 375..<414:     return .standard   // iPhone 14, 15
        case 414..<428:     return .large      // iPhone Pro Max  
        case 428..<834:     return .tablet     // iPad mini
        default:            return .desktop    // iPad Pro
        }
    }
    
    /// Human readable name
    var displayName: String {
        switch self {
        case .compact: return "Compact (iPod/iPhone SE)"
        case .standard: return "Standard iPhone"
        case .large: return "Large iPhone"
        case .tablet: return "iPad mini"
        case .desktop: return "iPad Pro"
        }
    }
}

// MARK: - Dynamic Scaling System
/// Comprehensive dynamic scaling system for responsive design across all iOS devices
struct DynamicScaling {
    
    // MARK: - Scaling Multipliers
    /// Base scaling multipliers for each device category
    private static let scaleMultipliers: [DeviceSize: CGFloat] = [
        .compact: 0.85,     // 15% smaller for iPod/iPhone SE
        .standard: 1.0,     // Baseline for iPhone
        .large: 1.12,       // 12% larger for Pro Max
        .tablet: 1.3,       // 30% larger for iPad mini
        .desktop: 1.5       // 50% larger for iPad Pro
    ]
    
    // MARK: - Font Scaling
    /// Dynamic font scaling based on device size
    static func font(_ baseSize: CGFloat, for deviceSize: DeviceSize) -> CGFloat {
        let multiplier = scaleMultipliers[deviceSize] ?? 1.0
        let scaledSize = baseSize * multiplier
        
        // Apply additional scaling based on accessibility settings
        let scaled = UIFontMetrics.default.scaledValue(for: scaledSize)
        
        // Ensure minimum readable size
        return max(scaled, deviceSize == .compact ? 10 : 12)
    }
    
    // MARK: - Size Scaling  
    /// Dynamic size scaling for frames, buttons, icons
    static func size(_ baseSize: CGFloat, for deviceSize: DeviceSize) -> CGFloat {
        let multiplier = scaleMultipliers[deviceSize] ?? 1.0
        return baseSize * multiplier
    }
    
    // MARK: - Padding Scaling
    /// Dynamic padding scaling maintaining visual hierarchy
    static func padding(_ baseSize: CGFloat, for deviceSize: DeviceSize) -> CGFloat {
        let multiplier = scaleMultipliers[deviceSize] ?? 1.0
        return baseSize * multiplier
    }
    
    // MARK: - Spacing Scaling
    /// Dynamic spacing scaling for consistent layouts
    static func spacing(_ baseSize: CGFloat, for deviceSize: DeviceSize) -> CGFloat {
        let multiplier = scaleMultipliers[deviceSize] ?? 1.0
        return baseSize * multiplier
    }
    
    // MARK: - Corner Radius Scaling
    /// Dynamic corner radius scaling
    static func cornerRadius(_ baseRadius: CGFloat, for deviceSize: DeviceSize) -> CGFloat {
        let multiplier = scaleMultipliers[deviceSize] ?? 1.0
        return baseRadius * multiplier
    }
    
    // MARK: - Icon Size Scaling
    /// Specific scaling for SF Symbol icons
    static func iconSize(_ baseSize: CGFloat, for deviceSize: DeviceSize) -> CGFloat {
        let multiplier = scaleMultipliers[deviceSize] ?? 1.0
        let scaled = baseSize * multiplier
        
        // Ensure icons remain crisp at standard sizes
        return round(scaled)
    }
    
    // MARK: - Touch Target Scaling
    /// Ensure minimum touch target sizes per Apple HIG
    static func touchTarget(_ baseSize: CGFloat, for deviceSize: DeviceSize) -> CGFloat {
        let multiplier = scaleMultipliers[deviceSize] ?? 1.0
        let scaled = baseSize * multiplier
        
        // Minimum 44pt touch target per Apple HIG
        return max(scaled, 44)
    }
    
    // MARK: - Layout Scaling
    /// Determine optimal number of columns for grid layouts
    static func columns(for deviceSize: DeviceSize, baseColumns: Int = 2) -> Int {
        switch deviceSize {
        case .compact:
            return max(1, baseColumns - 1)  // Reduce columns for compact
        case .standard:
            return baseColumns
        case .large:
            return baseColumns
        case .tablet:
            return baseColumns + 1          // Add column for tablet
        case .desktop:
            return baseColumns + 2          // Add more columns for desktop
        }
    }
    
    // MARK: - Device Detection Helpers
    /// Get current device size from screen dimensions
    static func currentDeviceSize() -> DeviceSize {
        let screenWidth = UIScreen.main.bounds.width
        return DeviceSize.from(screenWidth: screenWidth)
    }
    
    /// Check if current device is compact
    static var isCompactDevice: Bool {
        currentDeviceSize() == .compact
    }
    
    /// Check if current device is tablet or larger
    static var isTabletOrLarger: Bool {
        let size = currentDeviceSize()
        return size == .tablet || size == .desktop
    }
    
    // MARK: - Video-Specific Scaling
    /// Video content optimized sizing for different device categories
    static func videoHeight(for deviceSize: DeviceSize, aspectRatio: CGFloat = 16.0/9.0) -> CGFloat {
        let baseHeight: CGFloat
        
        switch deviceSize {
        case .compact:    baseHeight = 200  // iPhone SE, iPod touch
        case .standard:   baseHeight = 250  // iPhone 14, 15
        case .large:      baseHeight = 280  // iPhone Pro Max
        case .tablet:     baseHeight = 400  // iPad mini
        case .desktop:    baseHeight = 500  // iPad Pro
        }
        
        return baseHeight
    }
    
    /// Calculate optimal video width based on height and aspect ratio
    static func videoWidth(height: CGFloat, aspectRatio: CGFloat) -> CGFloat {
        return height * aspectRatio
    }
    
    /// Get safe video dimensions that fit within screen bounds
    static func safeVideoDimensions(aspectRatio: CGFloat = 16.0/9.0, maxWidthPercentage: CGFloat = 0.9) -> CGSize {
        let deviceSize = currentDeviceSize()
        let screenWidth = UIScreen.main.bounds.width
        let maxWidth = screenWidth * maxWidthPercentage
        
        let optimalHeight = videoHeight(for: deviceSize, aspectRatio: aspectRatio)
        let optimalWidth = videoWidth(height: optimalHeight, aspectRatio: aspectRatio)
        
        // Ensure width doesn't exceed screen bounds
        if optimalWidth > maxWidth {
            let constrainedHeight = maxWidth / aspectRatio
            return CGSize(width: maxWidth, height: constrainedHeight)
        }
        
        return CGSize(width: optimalWidth, height: optimalHeight)
    }
}

// MARK: - SwiftUI View Extensions
extension View {
    
    /// Apply dynamic font scaling
    func dynamicFont(_ baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        let deviceSize = DynamicScaling.currentDeviceSize()
        let scaledSize = DynamicScaling.font(baseSize, for: deviceSize)
        return self.font(.system(size: scaledSize, weight: weight, design: design))
    }
    
    /// Apply dynamic padding
    func dynamicPadding(_ baseSize: CGFloat) -> some View {
        let deviceSize = DynamicScaling.currentDeviceSize()
        let scaledPadding = DynamicScaling.padding(baseSize, for: deviceSize)
        return self.padding(scaledPadding)
    }
    
    /// Apply dynamic horizontal padding
    func dynamicHorizontalPadding(_ baseSize: CGFloat) -> some View {
        let deviceSize = DynamicScaling.currentDeviceSize()
        let scaledPadding = DynamicScaling.padding(baseSize, for: deviceSize)
        return self.padding(.horizontal, scaledPadding)
    }
    
    /// Apply dynamic vertical padding
    func dynamicVerticalPadding(_ baseSize: CGFloat) -> some View {
        let deviceSize = DynamicScaling.currentDeviceSize()
        let scaledPadding = DynamicScaling.padding(baseSize, for: deviceSize)
        return self.padding(.vertical, scaledPadding)
    }
    
    /// Apply dynamic frame size
    func dynamicFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        let deviceSize = DynamicScaling.currentDeviceSize()
        let scaledWidth = width.map { DynamicScaling.size($0, for: deviceSize) }
        let scaledHeight = height.map { DynamicScaling.size($0, for: deviceSize) }
        return self.frame(width: scaledWidth, height: scaledHeight)
    }
    
    /// Apply dynamic corner radius
    func dynamicCornerRadius(_ baseRadius: CGFloat) -> some View {
        let deviceSize = DynamicScaling.currentDeviceSize()
        let scaledRadius = DynamicScaling.cornerRadius(baseRadius, for: deviceSize)
        return self.cornerRadius(scaledRadius)
    }
    
    /// Scale relative to screen width
    func scaleToScreenWidth(_ percentage: CGFloat) -> some View {
        GeometryReader { geometry in
            self.frame(width: geometry.size.width * percentage)
        }
    }
    
    /// Scale relative to screen height  
    func scaleToScreenHeight(_ percentage: CGFloat) -> some View {
        GeometryReader { geometry in
            self.frame(height: geometry.size.height * percentage)
        }
    }
    
    /// Apply intelligent video sizing based on aspect ratio and device
    func intelligentVideoSize(aspectRatio: CGFloat = 16.0/9.0, maxWidthPercentage: CGFloat = 0.9) -> some View {
        let dimensions = DynamicScaling.safeVideoDimensions(aspectRatio: aspectRatio, maxWidthPercentage: maxWidthPercentage)
        return self.frame(width: dimensions.width, height: dimensions.height)
    }
    
    /// Apply device-optimized video height
    func deviceOptimizedVideoHeight(aspectRatio: CGFloat = 16.0/9.0) -> some View {
        let deviceSize = DynamicScaling.currentDeviceSize()
        let height = DynamicScaling.videoHeight(for: deviceSize, aspectRatio: aspectRatio)
        return self.frame(height: height)
    }
}

// MARK: - Responsive Grid Helpers
struct ResponsiveGrid {
    
    /// Create adaptive grid columns based on device size
    static func columns(baseColumns: Int = 2, spacing: CGFloat = 16) -> [GridItem] {
        let deviceSize = DynamicScaling.currentDeviceSize()
        let columnCount = DynamicScaling.columns(for: deviceSize, baseColumns: baseColumns)
        let scaledSpacing = DynamicScaling.spacing(spacing, for: deviceSize)
        
        return Array(repeating: GridItem(.flexible(), spacing: scaledSpacing), count: columnCount)
    }
    
    /// Get optimal spacing for current device
    static func spacing(_ baseSpacing: CGFloat) -> CGFloat {
        let deviceSize = DynamicScaling.currentDeviceSize()
        return DynamicScaling.spacing(baseSpacing, for: deviceSize)
    }
}

#if DEBUG
// MARK: - Preview Helpers
struct DynamicScaling_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Dynamic Scaling Demo")
                .dynamicFont(24, weight: .bold)
            
            Text("Font sizes scale automatically")
                .dynamicFont(16)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue)
                .dynamicFrame(width: 100, height: 50)
            
            Text("Padding scales too")
                .dynamicPadding(20)
                .background(Color.gray.opacity(0.2))
                .dynamicCornerRadius(8)
        }
        .dynamicPadding(20)
        .previewDevice("iPhone SE (3rd generation)")
        .previewDisplayName("Compact")
        
        VStack(spacing: 20) {
            Text("Dynamic Scaling Demo")
                .dynamicFont(24, weight: .bold)
            
            Text("Font sizes scale automatically")
                .dynamicFont(16)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue)
                .dynamicFrame(width: 100, height: 50)
            
            Text("Padding scales too")
                .dynamicPadding(20)
                .background(Color.gray.opacity(0.2))
                .dynamicCornerRadius(8)
        }
        .dynamicPadding(20)
        .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        .previewDisplayName("Desktop")
    }
}
#endif