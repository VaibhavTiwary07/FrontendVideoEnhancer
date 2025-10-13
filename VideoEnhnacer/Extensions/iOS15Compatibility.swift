import SwiftUI
import Foundation

// MARK: - iOS 15 Compatibility Extension
extension View {
    /// Returns an iOS 15 compatible SF Symbol, falling back to a compatible alternative
    func compatibleSymbol(_ preferredSymbol: String, fallback: String = "") -> String {
        if #available(iOS 16.0, *) {
            return preferredSymbol
        } else {
            return iOS15SymbolMap.getCompatibleSymbol(for: preferredSymbol, fallback: fallback)
        }
    }
    
    /// Applies iOS 15 compatible frame constraints
    func safeFrame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        let safeWidth = width.map { max(0, $0.isFinite ? $0 : 100) }
        let safeHeight = height.map { max(0, $0.isFinite ? $0 : 100) }
        return self.frame(width: safeWidth, height: safeHeight, alignment: alignment)
    }
}

// MARK: - iOS 15 SF Symbol Compatibility Map
struct iOS15SymbolMap {
    static func getCompatibleSymbol(for symbol: String, fallback: String = "") -> String {
        let compatibleSymbols: [String: String] = [
            // iOS 16+ symbols that don't exist in iOS 15
            "timer.circle.fill": "timer",
            "wand.and.stars.fill": "wand.and.stars",
            "face.smiling": "person.crop.circle",
            "face.dashed": "person.crop.circle",
            
            // Additional potential issues
            "square.and.arrow.up.circle.fill": "square.and.arrow.up",
            "video.circle.fill": "video",
            "photo.circle.fill": "photo"
        ]
        
        return compatibleSymbols[symbol] ?? (fallback.isEmpty ? symbol : fallback)
    }
}

// MARK: - Global iOS 15 Compatibility Helper
func getIOSCompatibleSymbol(_ preferredSymbol: String, fallback: String = "") -> String {
    return iOS15SymbolMap.getCompatibleSymbol(for: preferredSymbol, fallback: fallback)
}

// MARK: - Safe Geometry Calculations
extension CGFloat {
    var safeValue: CGFloat {
        guard self.isFinite && !self.isNaN else { return 0 }
        return Swift.max(0, self)
    }
}

extension CGSize {
    var isSafe: Bool {
        return width.isFinite && height.isFinite && 
               !width.isNaN && !height.isNaN && 
               width > 0 && height > 0
    }
    
    var safeClamped: CGSize {
        return CGSize(
            width: Swift.max(0, width.isFinite ? width : 100),
            height: Swift.max(0, height.isFinite ? height : 100)
        )
    }
}