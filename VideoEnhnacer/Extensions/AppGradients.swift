import SwiftUI

struct AppGradients {
    
    // MARK: - Primary Theme (Coral to Orange)
    static let primaryTheme = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.47, blue: 0.47),    // #FF7878 - Coral
            Color(red: 1.0, green: 0.596, blue: 0.329)   // #FF9854 - Orange
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let primaryThemeLight = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.7, blue: 0.7),      // Lighter coral
            Color(red: 1.0, green: 0.75, blue: 0.5)      // Lighter orange
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let primaryThemeDark = LinearGradient(
        colors: [
            Color(red: 0.9, green: 0.35, blue: 0.35),    // Darker coral
            Color(red: 0.9, green: 0.45, blue: 0.2)      // Darker orange
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Red Pink Variants
    static let redPink = LinearGradient(
        colors: [
            Color(red: 255/255, green: 16/255, blue: 0/255).opacity(0.91),      // Strong red start
            Color(red: 255/255, green: 110/255, blue: 99/255).opacity(0.3),     // Muted coral
            /*Color(red: 255/255, green: 200/255, blue: 180/255).opacity(0.15),*/   // Very light
            Color(red: 255/255, green: 245/255, blue: 245/255).opacity(0.0)     // Transparent end
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let redPinkLight = LinearGradient(
        colors: [
            Color(red: 252/255, green: 180/255, blue: 180/255),  // Lighter
            Color(red: 253/255, green: 230/255, blue: 230/255),  // Much lighter
            Color(red: 255/255, green: 250/255, blue: 250/255)   // Almost white
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let redPinkDark = LinearGradient(
        colors: [
            Color(red: 230/255, green: 90/255, blue: 90/255),    // Darker
            Color(red: 240/255, green: 180/255, blue: 180/255),  // Medium
            Color(red: 248/255, green: 211/255, blue: 211/255)   // Original light
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Gray Variants
    static let gray = LinearGradient(
        colors: [
            Color(red: 100/255, green: 100/255, blue: 100/255).opacity(0.7),    // Charcoal
            Color(red: 160/255, green: 160/255, blue: 160/255).opacity(0.4),    // Silver
            Color(red: 220/255, green: 220/255, blue: 220/255).opacity(0.15),   // Light gray
            Color(red: 245/255, green: 245/255, blue: 245/255).opacity(0.0)     // Transparent
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let grayLight = LinearGradient(
        colors: [
            Color(red: 210/255, green: 210/255, blue: 210/255),  // Lighter
            Color(red: 235/255, green: 235/255, blue: 235/255),  // Much lighter
            Color(red: 250/255, green: 250/255, blue: 250/255)   // Almost white
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let grayDark = LinearGradient(
        colors: [
            Color(red: 160/255, green: 160/255, blue: 160/255),  // Darker
            Color(red: 200/255, green: 200/255, blue: 200/255),  // Medium
            Color(red: 224/255, green: 224/255, blue: 224/255)   // Original light
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Yellow Gray Variants
    static let yellowGray = LinearGradient(
        colors: [
            Color(red: 255/255, green: 170/255, blue: 0/255).opacity(0.8),      // Warm amber
            Color(red: 255/255, green: 200/255, blue: 80/255).opacity(0.4),     // Golden
            Color(red: 255/255, green: 240/255, blue: 180/255).opacity(0.15),   // Cream
            Color(red: 255/255, green: 250/255, blue: 240/255).opacity(0.0)     // Transparent
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let yellowGrayLight = LinearGradient(
        colors: [
            Color(red: 255/255, green: 220/255, blue: 140/255),  // Lighter yellow
            Color(red: 240/255, green: 240/255, blue: 240/255),  // Much lighter
            Color(red: 255/255, green: 255/255, blue: 250/255)   // Almost white with yellow tint
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let yellowGrayDark = LinearGradient(
        colors: [
            Color(red: 240/255, green: 180/255, blue: 40/255),   // Darker yellow
            Color(red: 250/255, green: 210/255, blue: 100/255),  // Medium
            Color(red: 217/255, green: 217/255, blue: 217/255)   // Original light
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Purple Gray Variants
    static let purpleGray = LinearGradient(
        colors: [
            Color(red: 120/255, green: 80/255, blue: 200/255).opacity(0.6),     // Deep lavender
            Color(red: 160/255, green: 130/255, blue: 220/255).opacity(0.35),   // Lilac
            Color(red: 200/255, green: 180/255, blue: 240/255).opacity(0.15),   // Light purple
            Color(red: 245/255, green: 240/255, blue: 255/255).opacity(0.0)     // Transparent
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let purpleGrayLight = LinearGradient(
        colors: [
            Color(red: 180/255, green: 170/255, blue: 255/255),  // Lighter purple
            Color(red: 240/255, green: 240/255, blue: 245/255),  // Much lighter
            Color(red: 250/255, green: 250/255, blue: 255/255)   // Almost white with purple tint
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let purpleGrayDark = LinearGradient(
        colors: [
            Color(red: 100/255, green: 80/255, blue: 220/255),   // Darker purple
            Color(red: 150/255, green: 140/255, blue: 240/255),  // Medium
            Color(red: 217/255, green: 217/255, blue: 217/255)   // Original light
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Cyan Gray Variants
    static let cyanGray = LinearGradient(
        colors: [
            Color(red: 0/255, green: 132/255, blue: 255/255).opacity(0.45),     // Ocean blue
            Color(red: 46/255, green: 154/255, blue: 255/255).opacity(0.45),    // Sky blue
            Color(red: 166/255, green: 204/255, blue: 239/255).opacity(0.45),   // Powder blue
            Color(red: 207/255, green: 232/255, blue: 255/255).opacity(0.0)     // Transparent
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let cyanGrayLight = LinearGradient(
        colors: [
            Color(red: 120/255, green: 220/255, blue: 255/255),  // Lighter cyan
            Color(red: 240/255, green: 245/255, blue: 250/255),  // Much lighter
            Color(red: 250/255, green: 255/255, blue: 255/255)   // Almost white with cyan tint
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let cyanGrayDark = LinearGradient(
        colors: [
            Color(red: 30/255, green: 180/255, blue: 230/255),   // Darker cyan
            Color(red: 80/255, green: 200/255, blue: 250/255),   // Medium
            Color(red: 217/255, green: 217/255, blue: 217/255)   // Original light
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Pink Gray Variants
    static let pinkGray = LinearGradient(
        colors: [
            Color(red: 220/255, green: 100/255, blue: 150/255).opacity(0.7),    // Rose
            Color(red: 240/255, green: 150/255, blue: 180/255).opacity(0.35),   // Blush
            Color(red: 250/255, green: 200/255, blue: 220/255).opacity(0.15),   // Light pink
            Color(red: 255/255, green: 245/255, blue: 250/255).opacity(0.0)     // Transparent
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let pinkGrayLight = LinearGradient(
        colors: [
            Color(red: 252/255, green: 190/255, blue: 220/255),  // Lighter pink
            Color(red: 245/255, green: 240/255, blue: 245/255),  // Much lighter
            Color(red: 255/255, green: 250/255, blue: 253/255)   // Almost white with pink tint
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let pinkGrayDark = LinearGradient(
        colors: [
            Color(red: 230/255, green: 100/255, blue: 170/255),  // Darker pink
            Color(red: 245/255, green: 150/255, blue: 190/255),  // Medium
            Color(red: 217/255, green: 217/255, blue: 217/255)   // Original light
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Extension for easy access
extension LinearGradient {
    // Primary theme
    static var primaryTheme: LinearGradient { AppGradients.primaryTheme }
    static var primaryThemeLight: LinearGradient { AppGradients.primaryThemeLight }
    static var primaryThemeDark: LinearGradient { AppGradients.primaryThemeDark }
    
    // Base gradients
    static var redPink: LinearGradient { AppGradients.redPink }
    static var gray: LinearGradient { AppGradients.gray }
    static var yellowGray: LinearGradient { AppGradients.yellowGray }
    static var purpleGray: LinearGradient { AppGradients.purpleGray }
    static var cyanGray: LinearGradient { AppGradients.cyanGray }
    static var pinkGray: LinearGradient { AppGradients.pinkGray }
    
    // Light variants
    static var redPinkLight: LinearGradient { AppGradients.redPinkLight }
    static var grayLight: LinearGradient { AppGradients.grayLight }
    static var yellowGrayLight: LinearGradient { AppGradients.yellowGrayLight }
    static var purpleGrayLight: LinearGradient { AppGradients.purpleGrayLight }
    static var cyanGrayLight: LinearGradient { AppGradients.cyanGrayLight }
    static var pinkGrayLight: LinearGradient { AppGradients.pinkGrayLight }
    
    // Dark variants
    static var redPinkDark: LinearGradient { AppGradients.redPinkDark }
    static var grayDark: LinearGradient { AppGradients.grayDark }
    static var yellowGrayDark: LinearGradient { AppGradients.yellowGrayDark }
    static var purpleGrayDark: LinearGradient { AppGradients.purpleGrayDark }
    static var cyanGrayDark: LinearGradient { AppGradients.cyanGrayDark }
    static var pinkGrayDark: LinearGradient { AppGradients.pinkGrayDark }
}

// MARK: - Gradient Morphing Helper
enum GradientType: CaseIterable {
    case redPink, gray, yellowGray, purpleGray, cyanGray, pinkGray
    
    var base: LinearGradient {
        switch self {
        case .redPink: return AppGradients.redPink
        case .gray: return AppGradients.gray
        case .yellowGray: return AppGradients.yellowGray
        case .purpleGray: return AppGradients.purpleGray
        case .cyanGray: return AppGradients.cyanGray
        case .pinkGray: return AppGradients.pinkGray
        }
    }
    
    var light: LinearGradient {
        switch self {
        case .redPink: return AppGradients.redPinkLight
        case .gray: return AppGradients.grayLight
        case .yellowGray: return AppGradients.yellowGrayLight
        case .purpleGray: return AppGradients.purpleGrayLight
        case .cyanGray: return AppGradients.cyanGrayLight
        case .pinkGray: return AppGradients.pinkGrayLight
        }
    }
    
    var dark: LinearGradient {
        switch self {
        case .redPink: return AppGradients.redPinkDark
        case .gray: return AppGradients.grayDark
        case .yellowGray: return AppGradients.yellowGrayDark
        case .purpleGray: return AppGradients.purpleGrayDark
        case .cyanGray: return AppGradients.cyanGrayDark
        case .pinkGray: return AppGradients.pinkGrayDark
        }
    }
    
    func getVariant(intensity: Double) -> LinearGradient {
        // intensity: 0.0 = dark, 0.5 = base, 1.0 = light
        return intensity > 0.66 ? light : intensity < 0.33 ? dark : base
    }
}
