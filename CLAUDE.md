# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
VideoEnhancer is an iOS SwiftUI application frontend for video editing and enhancement. The app targets a broad audience from tech-savvy users to non-technical users across all age groups, emphasizing simplicity and intuitive design.

## Development Commands
- **Build**: Open in Xcode and use Cmd+B or Product → Build
- **Run**: Cmd+R in Xcode or use the simulator
- **Clean**: Cmd+Shift+K or Product → Clean Build Folder

## Architecture
- **Platform**: iOS (SwiftUI)
- **Main App**: `VideoEnhnacerApp.swift` - Entry point
- **Root View**: `ContentView.swift` - Main interface container
- **Assets**: `Assets.xcassets/` - App icons, colors, and visual assets

## UI/UX Design Requirements

### Design Philosophy
- **Minimalistic Neomorphism**: Soft, subtle shadows and highlights creating depth without visual clutter
- **No Cognitive Overload**: Clean, intuitive interface suitable for all skill levels and age groups
- **Universal Accessibility**: Design that appeals to both technical and non-technical users

### Core UI Components

#### Navigation Structure
1. **App Header** (Top navigation):
   - Single hamburger button in top-left corner
   - App title centered in header
   - Consistent across all screens
   - Neomorphic button styling with tap feedback
   - Fixed position above all content

2. **Custom Tab Bar** (Bottom navigation):
   - Custom implementation with neomorphic styling
   - Full-width tab bar with gradient accent colors  
   - Tap feedback with subtle color changes and scale effects
   - Home and My Creations tabs

3. **On-Demand Sidebar** (Left panel):
   - Only appears when hamburger button is clicked
   - No layout overhead when not visible
   - Clean slide-in animation from left edge
   - ZStack overlay approach (doesn't compress main content)
   - Backdrop blur/dim dismisses sidebar when tapped
   - Fixed width (200pt) with full menu items visible
   - Menu items with gradient tap feedback
   - Sidebar contains: Settings, Projects, Favorites, Help

4. **Floating Action Button**:
   - Plus (+) button for primary actions
   - Positioned for easy thumb access
   - Neomorphic elevation effect with gradient styling

#### Home Screen Features

##### Video Enhancement Demonstrations
**Enhanced AI Upscale Card:**
- **VideoComparisonCard** component with real video demonstration
- **Interactive slider** showing before (normal.mp4) vs after (enhanced.mp4)
- **Synchronized video playback** with smooth masking transition
- **Neomorphic design** matching app theme with gradient accents
- **Touch-friendly controls** with haptic-style feedback

**Standard Enhancement Cards:**
- **Face and Object Enhancer** - Improve facial features and object details  
- **AI Denoise** - Remove grain and noise
- **AI Color** - Color correction and enhancement
- **AI Auto Enhancement** - One-click smart improvements
- **Stabilizer** - Reduce camera shake
- **Frame Interpolation** - Smooth motion and increase frame rate

##### VideoComparisonSlider Features
- **Dual AVPlayer setup** with synchronized playback and looping
- **Interactive drag control** to adjust before/after split position
- **Gradient slider track** using primary theme colors (#FF7878 → #FF9854 → #FCC06C)
- **White divider line** with shadow for clear visual separation
- **Auto-play on appear** with proper cleanup on disappear
- **Memory efficient** with proper player lifecycle management

##### VideoPropertyList Overlay
Overlay containing detailed video enhancement controls:
- **PropertySlider components** for fine-tuning enhancement parameters
- **Before/After preview** for each enhancement type
- **Smooth UI animations** with spring physics
- **Process and save functionality** for applying enhancements

### Neomorphic Design Elements
- **Soft shadows**: Use light backgrounds with subtle inner/outer shadows
- **Rounded corners**: 12-16px radius for modern feel
- **Subtle gradients**: Warm gradient tones for depth
- **Minimalist icons**: System SF Symbols
- **Typography**: San Francisco (system font) with appropriate weights
- **Tap Feedback**: All interactive elements show visual response
  - Gradient background on tap with warm colors
  - Scale effect (0.95-0.98) for pressed state
  - Color inversion for text during tap
  - Smooth animations (0.1-0.3 seconds)

### Color Palette & Theme
- **Primary Gradient**: Linear gradient from #FF7878 → #FF9854 → #FCC06C (coral to warm orange to golden)
- **Background**: #FEFEFE (Off-white) with subtle warm undertones
- **Cards/Buttons**: #FFFFFF with soft warm shadows using primary gradient at low opacity
- **Accent Elements**: Use primary gradient at 60-80% opacity for interactive states
- **Text Primary**: #2D2D2D (Dark gray)
- **Text Secondary**: #6B6B6B (Medium gray)
- **Subtle Tints**: Use primary colors at 5-15% opacity for background elements

### Gradient Usage Guidelines
- **Main Gradient**: Apply to primary CTAs, active states, and accent elements
- **Subtle Application**: Use at 10-20% opacity for card backgrounds and shadows
- **Interactive States**: Gradient at 60% opacity for hover/pressed states
- **Never Overwhelming**: Keep gradients subtle to maintain accessibility and readability

## Frontend Structure
```
VideoEnhnacer/
├── VideoEnhnacerApp.swift          # App entry point
├── ContentView.swift               # Main UI container with TabView
├── Views/                          # UI components
│   ├── HeaderView.swift           # App header with single hamburger button
│   ├── HomeView.swift             # Home tab content (clean, no navigation)
│   ├── MyCreationsView.swift      # My Creations tab content (clean, no navigation)
│   ├── SidebarView.swift          # On-demand sidebar (shows only when needed)
│   ├── VideoPropertyListView.swift # Enhancement options overlay
│   └── Components/                # Reusable UI components
│       ├── NeomorphicButton.swift # Neomorphic button with tap feedback
│       ├── PropertySlider.swift   # Before/after slider component
│       ├── FloatingActionButton.swift # FAB component with gradient
│       ├── CustomTabBar.swift     # Custom tab bar with neomorphic styling
│       ├── VideoComparisonSlider.swift # Interactive video before/after comparison
│       └── VideoComparisonCard.swift # Enhanced card with video demonstration
└── Assets.xcassets/               # Images, icons, colors (add gradient colors)
```

## Modern Swift Development Guidelines

### SwiftUI Best Practices
- **Property Wrappers**: Use appropriate property wrappers for state management
  - `@State` for local view state
  - `@StateObject` for observable object creation
  - `@ObservedObject` for observable object observation
  - `@EnvironmentObject` for shared app-wide state
  - `@Binding` for two-way data flow between parent/child views
- **ViewBuilder**: Use `@ViewBuilder` for conditional view composition
- **ViewModifier**: Create reusable modifiers for common styling patterns
- **PreferenceKeys**: Use for reverse data flow (child to parent communication)

### Swift Concurrency & Performance
- **MainActor**: Mark UI-updating methods with `@MainActor`
- **Async/Await**: Prepare architecture for future async operations
- **Task**: Use structured concurrency for background operations
- **AsyncImage**: Use for efficient image loading
- **Lazy Loading**: Implement `LazyVStack`, `LazyHStack`, and `LazyVGrid` for performance

### Code Architecture
- **MVVM Pattern**: Separate concerns using Model-View-ViewModel
- **Dependency Injection**: Use `@EnvironmentObject` for service injection
- **Protocol-Oriented Programming**: Define protocols for testable code
- **Value Types**: Prefer structs and enums over classes where appropriate

## Apple Human Interface Guidelines (HIG) Compliance

### Accessibility
- **Dynamic Type**: Support system font size preferences
  ```swift
  Text("Title").font(.title) // Automatically scales
  ```
- **VoiceOver**: Add accessibility labels and hints
  ```swift
  .accessibilityLabel("Video enhancement slider")
  .accessibilityHint("Adjust enhancement level")
  ```
- **Color Accessibility**: Ensure 4.5:1 contrast ratio minimum
- **Touch Targets**: Minimum 44pt x 44pt for interactive elements
- **Reduce Motion**: Respect user's motion preferences

### Device Adaptation
- **Safe Areas**: Always respect safe area insets
- **Size Classes**: Adapt layouts for different device orientations
- **Haptic Feedback**: Use appropriate haptic patterns
  ```swift
  let impact = UIImpactFeedbackGenerator(style: .medium)
  impact.impactOccurred()
  ```

### Visual Design
- **SF Symbols**: Use system icons for consistency
- **System Colors**: Use semantic colors that adapt to dark mode
- **Typography**: Follow iOS typography hierarchy
- **Spacing**: Use consistent spacing based on 8pt grid system

## Responsive Design (iPod touch to iPad Pro)

### Screen Size Support
- **iPhone SE (3rd gen)**: 375x667pt (4.7")
- **iPhone 16**: 393x852pt (6.1") 
- **iPhone 16 Pro Max**: 440x956pt (6.9")
- **iPad mini**: 744x1133pt (8.3")
- **iPad Pro 13"**: 1032x1376pt (13")

### Adaptive Layout Techniques
```swift
GeometryReader { geometry in
    if geometry.size.width < 768 {
        // iPhone layout
        VStack { /* compact layout */ }
    } else {
        // iPad layout  
        HStack { /* regular layout */ }
    }
}
```

### Size Class Handling
```swift
@Environment(\.horizontalSizeClass) var horizontalSizeClass

var isCompact: Bool {
    horizontalSizeClass == .compact
}
```

### Dynamic Spacing and Sizing
- Use relative sizing: `.frame(minWidth: geometry.size.width * 0.8)`
- Adaptive padding: `.padding(isCompact ? 16 : 32)`
- Responsive typography: Scale font sizes based on screen size
- Flexible grids: Adjust column counts based on available width

## Lightweight App Architecture

### State Management & Memory Management

#### SwiftUI View Lifecycle and State Persistence
SwiftUI recreates views during navigation (tab switching, navigation changes), which can cause state loss for components with expensive resources like video players.

**Problem**: Video players disappear when switching tabs because SwiftUI deallocates `@State` properties when views are recreated.

**Solution**: Use `@StateObject` with ObservableObject for persistent state across view recreations.

```swift
// ❌ Wrong: @State gets deallocated on view recreation
@State private var normalPlayer: AVPlayer?
@State private var enhancedPlayer: AVPlayer?

// ✅ Correct: @StateObject persists across view lifecycle
@StateObject private var playerManager = VideoPlayerManager()
```

#### VideoPlayerManager Pattern
```swift
class VideoPlayerManager: ObservableObject {
    @Published var normalPlayer: AVPlayer?
    @Published var enhancedPlayer: AVPlayer?
    @Published var isLoaded = false
    
    private var loopObservers: [NSObjectProtocol] = []
    
    func setupVideoPlayers(normalVideoName: String, enhancedVideoName: String) {
        // Setup logic with proper cleanup and memory management
    }
    
    deinit {
        // Always cleanup observers and resources
        cleanupObservers()
        normalPlayer?.pause()
        enhancedPlayer?.pause()
    }
}
```

#### Best Practices for State Management
1. **Use appropriate property wrappers**:
   - `@State`: Local view state (primitive types, simple structs)
   - `@StateObject`: Create and own observable objects (expensive resources)
   - `@ObservedObject`: Reference existing observable objects
   - `@EnvironmentObject`: App-wide shared state

2. **Resource Management**:
   - Always implement proper cleanup in `deinit`
   - Use weak references in closures to avoid retain cycles
   - Pause/cleanup expensive resources when views disappear

3. **Memory Efficiency**:
   - Use `@StateObject` for expensive resources that should persist
   - Implement lazy loading for heavy components
   - Clean up NotificationCenter observers properly

### Memory Management
- **Weak References**: Avoid retain cycles in closures
- **Lazy Properties**: Load expensive resources on demand
- **Image Optimization**: Use appropriate image formats and sizes
- **View Recycling**: Let SwiftUI handle view recycling automatically
- **Resource Cleanup**: Always implement proper cleanup in deinit methods

### Performance Optimization
- **EquatableView**: Implement `Equatable` for complex views
- **PreferenceKey**: Minimize view updates with efficient data flow
- **BatchUpdates**: Group state changes together
- **Offscreen Rendering**: Use `drawingGroup()` for complex shapes

### Efficient State Management
```swift
// Good: Single source of truth
@StateObject private var viewModel = HomeViewModel()

// Good: Minimal state granularity  
@State private var isExpanded = false
@State private var selectedTab = 0

// Avoid: Large nested state objects
```

### Code Organization
- **Feature Modules**: Organize by feature, not layer
- **Extensions**: Group related functionality
- **Protocols**: Define clear interfaces
- **Constants**: Centralize magic numbers and strings

## Development Focus
- Pure SwiftUI frontend implementation using modern Swift techniques
- Apple HIG compliant design with full accessibility support
- Lightweight, performant architecture optimized for all iOS devices
- Responsive design supporting iPod touch (3.5") to iPad Pro (13")
- ZStack-based layout architecture for optimal layout flexibility
- On-demand UI components (sidebar only loads when needed)
- Custom component library with comprehensive tap feedback
- MVVM architecture ready for future backend integration
- Efficient memory management and lazy loading patterns
- Clean separation of concerns with simplified state management