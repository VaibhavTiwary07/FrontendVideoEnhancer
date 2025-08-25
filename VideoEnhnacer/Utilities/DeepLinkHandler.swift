import Foundation
import SwiftUI

// MARK: - Deep Link Handler
/// Handles deep links and URL schemes for the VideoEnhancer app
struct DeepLinkHandler: DeepLinkHandling {
    
    // MARK: - URL Scheme Constants
    private enum URLScheme {
        static let app = "videoenhancer"
        static let https = "https"
        static let http = "http"
    }
    
    private enum Host {
        static let app = "app"
        static let enhancement = "enhancement"
        static let video = "video"
    }
    
    private enum Path {
        static let home = "/home"
        static let settings = "/settings"
        static let favorites = "/favorites"
        static let myCreations = "/my-creations"
        static let enhance = "/enhance"
        static let picker = "/picker"
        static let trimming = "/trimming"
        static let results = "/results"
    }
    
    // MARK: - DeepLinkHandling Implementation
    func canHandle(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        
        switch scheme {
        case URLScheme.app:
            return url.host == Host.app
        case URLScheme.https, URLScheme.http:
            return url.host?.contains("videoenhancer") == true
        default:
            return false
        }
    }
    
    func handle(url: URL) -> NavigationDestination? {
        guard canHandle(url: url) else { return nil }
        
        let path = url.path.lowercased()
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        // Parse path-based routing
        switch path {
        case Path.home:
            return .home
            
        case Path.settings:
            return .settings
            
        case Path.favorites:
            return .favorites
            
        case Path.myCreations:
            return .myCreations
            
        case Path.enhance:
            return handleEnhancementDeepLink(queryItems: queryItems)
            
        case Path.picker:
            return handlePickerDeepLink(queryItems: queryItems)
            
        case Path.trimming:
            return handleTrimmingDeepLink(queryItems: queryItems, url: url)
            
        case Path.results:
            return handleResultsDeepLink(queryItems: queryItems, url: url)
            
        default:
            return parseCustomPath(path: path, queryItems: queryItems)
        }
    }
    
    // MARK: - Convenience Method for AppCoordinator
    @MainActor
    func handle(url: URL, coordinator: NavigationCoordinatorProtocol) -> Bool {
        guard let destination = handle(url: url) else { return false }
        
        // Handle different destination types
        switch destination {
        case .home:
            coordinator.goToHome()
        case .settings, .favorites, .myCreations:
            // These would be handled by presenting appropriate modals or navigation
            break
        case .videoPicker(let enhancementType):
            coordinator.startEnhancementFlow(with: enhancementType)
        default:
            // For more complex flows, we'd need additional coordination
            break
        }
        
        return true
    }
    
    // MARK: - Private Deep Link Handlers
    private func handleEnhancementDeepLink(queryItems: [URLQueryItem]) -> NavigationDestination? {
        guard let enhancementTypeId = queryItems.first(where: { $0.name == "type" })?.value else {
            return .home
        }
        
        // Create enhancement type based on the ID
        let enhancementType = createEnhancementType(from: enhancementTypeId)
        return .videoPicker(enhancementType)
    }
    
    private func handlePickerDeepLink(queryItems: [URLQueryItem]) -> NavigationDestination? {
        guard let enhancementTypeId = queryItems.first(where: { $0.name == "enhancement" })?.value else {
            // Return default enhancement type if none specified
            return .videoPicker(createEnhancementType(from: "ai-upscale"))
        }
        
        let enhancementType = createEnhancementType(from: enhancementTypeId)
        return .videoPicker(enhancementType)
    }
    
    private func handleTrimmingDeepLink(queryItems: [URLQueryItem], url: URL) -> NavigationDestination? {
        guard let videoURLString = queryItems.first(where: { $0.name == "video" })?.value,
              let videoURL = URL(string: videoURLString),
              let enhancementTypeId = queryItems.first(where: { $0.name == "enhancement" })?.value else {
            return .home
        }
        
        let enhancementType = createEnhancementType(from: enhancementTypeId)
        let flowData = VideoTrimmingFlowData(videoURL: videoURL, enhancementType: enhancementType)
        return .videoTrimming(flowData)
    }
    
    private func handleResultsDeepLink(queryItems: [URLQueryItem], url: URL) -> NavigationDestination? {
        guard let originalURLString = queryItems.first(where: { $0.name == "original" })?.value,
              let processedURLString = queryItems.first(where: { $0.name == "processed" })?.value,
              let originalURL = URL(string: originalURLString),
              let processedURL = URL(string: processedURLString),
              let enhancementTypeId = queryItems.first(where: { $0.name == "enhancement" })?.value else {
            return .home
        }
        
        let enhancementType = createEnhancementType(from: enhancementTypeId)
        let result = EnhancementResult(
            originalURL: originalURL,
            processedURL: processedURL,
            enhancementType: enhancementType,
            processingTime: 0.0,
            metadata: EnhancementMetadata(
                processingTime: 0,
                enhancementStrength: 0.5,
                qualityScore: 0.8,
                fileSize: 0
            )
        )
        return .videoResults(result)
    }
    
    private func parseCustomPath(path: String, queryItems: [URLQueryItem]) -> NavigationDestination? {
        // Handle custom routing patterns
        let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        guard !pathComponents.isEmpty else { return .home }
        
        switch pathComponents[0] {
        case "enhancement":
            if pathComponents.count > 1 {
                let enhancementType = createEnhancementType(from: pathComponents[1])
                return .videoPicker(enhancementType)
            }
        case "video":
            return .home // Could extend for video-specific routing
        default:
            break
        }
        
        return .home
    }
    
    // MARK: - Enhancement Type Creation
    private func createEnhancementType(from identifier: String) -> EnhancementType {
        let id = identifier.lowercased()
        
        switch id {
        case "ai-upscale", "upscale":
            return EnhancementType(
                id: "ai-upscale",
                name: "AI Upscale",
                description: "Enhance image resolution using AI",
                icon: "arrow.up.square",
                category: .enhancement,
                processingTime: 30.0,
                qualityImpact: 0.9,
                gradientType: .redPink
            )
            
        case "face-enhancer", "face":
            return EnhancementType(
                id: "face-enhancer",
                name: "Face & Object Enhancer",
                description: "Improve facial features and object details",
                icon: "face.smiling",
                category: .enhancement,
                processingTime: 25.0,
                qualityImpact: 0.8,
                gradientType: .yellowGray
            )
            
        case "ai-denoise", "denoise":
            return EnhancementType(
                id: "ai-denoise",
                name: "AI Denoise",
                description: "Remove grain and noise using AI",
                icon: "waveform.path",
                category: .cleanup,
                processingTime: 20.0,
                qualityImpact: 0.7,
                gradientType: .purpleGray
            )
            
        case "ai-color", "color":
            return EnhancementType(
                id: "ai-color",
                name: "AI Color",
                description: "Color correction and enhancement",
                icon: "paintpalette.fill",
                category: .color,
                processingTime: 15.0,
                qualityImpact: 0.6,
                gradientType: .cyanGray
            )
            
        case "stabilizer", "stabilize":
            return EnhancementType(
                id: "stabilizer",
                name: "Stabilizer",
                description: "Reduce camera shake",
                icon: "gyroscope",
                category: .stabilization,
                processingTime: 35.0,
                qualityImpact: 0.8,
                gradientType: .gray
            )
            
        case "frame-interpolation", "interpolation":
            return EnhancementType(
                id: "frame-interpolation",
                name: "Frame Interpolation",
                description: "Smooth motion and increase frame rate",
                icon: "timer.circle.fill",
                category: .enhancement,
                processingTime: 45.0,
                qualityImpact: 0.9,
                gradientType: .redPink
            )
            
        default:
            // Default to AI Auto Enhancement
            return EnhancementType(
                id: "ai-auto",
                name: "AI Auto Enhancement",
                description: "One-click smart improvements",
                icon: "wand.and.stars",
                category: .enhancement,
                processingTime: 30.0,
                qualityImpact: 0.8,
                gradientType: .pinkGray
            )
        }
    }
}

// MARK: - Deep Link URL Builder
extension DeepLinkHandler {
    
    // MARK: - URL Generation
    static func createURL(for destination: NavigationDestination) -> URL? {
        var components = URLComponents()
        components.scheme = URLScheme.app
        components.host = Host.app
        
        switch destination {
        case .home:
            components.path = Path.home
            
        case .settings:
            components.path = Path.settings
            
        case .favorites:
            components.path = Path.favorites
            
        case .myCreations:
            components.path = Path.myCreations
            
        case .videoPicker(let enhancementType):
            components.path = Path.picker
            components.queryItems = [
                URLQueryItem(name: "enhancement", value: enhancementType.id)
            ]
            
        case .videoTrimming(let flowData):
            components.path = Path.trimming
            components.queryItems = [
                URLQueryItem(name: "video", value: flowData.videoURL.absoluteString),
                URLQueryItem(name: "enhancement", value: flowData.enhancementType.id)
            ]
            
        case .enhancementSelection(let flowData):
            components.path = Path.enhance
            components.queryItems = [
                URLQueryItem(name: "video", value: flowData.videoURL.absoluteString),
                URLQueryItem(name: "enhancement", value: flowData.enhancementType.id)
            ]
            
        case .videoResults(let result):
            components.path = Path.results
            components.queryItems = [
                URLQueryItem(name: "original", value: result.originalURL.absoluteString),
                URLQueryItem(name: "processed", value: result.processedURL.absoluteString),
                URLQueryItem(name: "enhancement", value: result.enhancementType.id)
            ]
        }
        
        return components.url
    }
    
    // MARK: - Share URL Generation
    static func createShareableURL(for result: EnhancementResult) -> URL? {
        var components = URLComponents()
        components.scheme = URLScheme.https
        components.host = "videoenhancer.app"
        components.path = "/shared"
        
        components.queryItems = [
            URLQueryItem(name: "video", value: result.processedURL.absoluteString),
            URLQueryItem(name: "enhancement", value: result.enhancementType.id),
            URLQueryItem(name: "quality", value: String(result.metadata.qualityScore))
        ]
        
        return components.url
    }
}

#Preview {
    Text("Deep Link Handler Preview")
        .onAppear {
            let handler = DeepLinkHandler()
            
            // Test URLs
            let testURLs = [
                "videoenhancer://app/home",
                "videoenhancer://app/enhance?type=ai-upscale",
                "videoenhancer://app/picker?enhancement=face-enhancer",
            ]
            
            for urlString in testURLs {
                if let url = URL(string: urlString) {
                    print("Can handle \(urlString): \(handler.canHandle(url: url))")
                    if let destination = handler.handle(url: url) {
                        print("Destination: \(destination)")
                    }
                }
            }
        }
}