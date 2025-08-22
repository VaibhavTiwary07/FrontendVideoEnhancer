import SwiftUI
import UIKit

final class RevealImageView: UIImageView {
    var leftImage: UIImage? {
        didSet {
            if let img = leftImage {
                leftImageLayer.contents = img.cgImage
            }
        }
    }

    var rightImage: UIImage? {
        didSet {
            if let img = rightImage {
                self.image = img
            }
        }
    }

    var pct: CGFloat = 0.5 {
        didSet { updateView() }
    }

    var pctChanged: ((CGFloat) -> Void)?
    var onInteractionStart: (() -> Void)?
    var onInteractionEnd: (() -> Void)?

    private let leftImageLayer = CALayer()
    private let maskLayer = CAGradientLayer()
    private let topFadeLayer = CAGradientLayer()
    private let lineView = UIView()
    private var autoSlideTimer: Timer?
    private var autoSlideDirection: CGFloat = 1.0
    private var isUserInteracting = false
    private var resumeTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        contentMode = .scaleAspectFill
        clipsToBounds = true

        // Setup enhanced multi-zone gradient mask for seamless opacity transition
        maskLayer.colors = [
            UIColor.black.cgColor,                           // Solid left
            UIColor.black.cgColor,                           // Solid zone
            UIColor.black.withAlphaComponent(0.8).cgColor,   // Primary fade
            UIColor.black.withAlphaComponent(0.4).cgColor,   // Light fade
            UIColor.clear.cgColor                            // Transparent right
        ]
        maskLayer.startPoint = CGPoint(x: 0, y: 0)
        maskLayer.endPoint = CGPoint(x: 1, y: 0)
        
        // Setup top fade layer for premium visual effect
        topFadeLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.cgColor
        ]
        topFadeLayer.startPoint = CGPoint(x: 0, y: 0)
        topFadeLayer.endPoint = CGPoint(x: 0, y: 1)
        topFadeLayer.locations = [0.0, 0.15]
        
        // Combine masks for sophisticated blending
        let combinedMask = CALayer()
        combinedMask.addSublayer(maskLayer)
        combinedMask.mask = topFadeLayer
        
        leftImageLayer.mask = combinedMask
        leftImageLayer.contentsGravity = .resizeAspectFill
        layer.addSublayer(leftImageLayer)

        // Setup enhanced white divider line
        lineView.backgroundColor = .white
        lineView.layer.cornerRadius = 1
        lineView.layer.shadowColor = UIColor.black.cgColor
        lineView.layer.shadowOffset = CGSize(width: 0, height: 0)
        lineView.layer.shadowOpacity = 0.4
        lineView.layer.shadowRadius = 3
        addSubview(lineView)

        isUserInteractionEnabled = true
        startAutoSliding()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        leftImageLayer.frame = bounds
        
        // Update mask layers to match bounds
        if let combinedMask = leftImageLayer.mask {
            combinedMask.frame = bounds
            maskLayer.frame = bounds
            topFadeLayer.frame = bounds
        }
        
        updateView()
    }

    private func updateView() {
        // Position white divider line
        lineView.frame = CGRect(x: bounds.width * pct - 1,
                                y: 0,
                                width: 2,
                                height: bounds.height)

        // Update gradient mask for clean before/after division
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Simple clean mask for before/after division
        let fadeWidth: CGFloat = 0.02 // Very small fade zone for sharp division
        let solidEnd = max(0, pct - fadeWidth)
        let fadeEnd = pct
        
        if fadeEnd <= 0 {
            // Completely transparent
            maskLayer.locations = [0.0, 0.0, 0.0, 0.0, 0.0]
        } else if solidEnd <= 0 {
            // Only fade zone visible
            maskLayer.locations = [0.0, NSNumber(value: fadeEnd), NSNumber(value: fadeEnd), NSNumber(value: fadeEnd), NSNumber(value: fadeEnd)]
        } else {
            // Clean division with minimal fade
            maskLayer.locations = [0.0, NSNumber(value: solidEnd), NSNumber(value: fadeEnd), NSNumber(value: fadeEnd), NSNumber(value: fadeEnd)]
        }
        
        CATransaction.commit()
        pctChanged?(pct)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isUserInteracting = true
        stopAutoSliding()
        onInteractionStart?()
        handle(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handle(touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isUserInteracting = false
        scheduleAutoSlideResume()
        onInteractionEnd?()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isUserInteracting = false
        scheduleAutoSlideResume()
        onInteractionEnd?()
    }

    private func handle(_ touches: Set<UITouch>) {
        guard let t = touches.first else { return }
        let loc = t.location(in: self)
        pct = max(0, min(1, loc.x / bounds.width))
    }
    
    // MARK: - Auto-Sliding System
    
    private func startAutoSliding() {
        guard autoSlideTimer == nil else { return }
        autoSlideTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.performAutoSlide()
        }
    }
    
    private func stopAutoSliding() {
        autoSlideTimer?.invalidate()
        autoSlideTimer = nil
        resumeTimer?.invalidate()
        resumeTimer = nil
    }
    
    private func scheduleAutoSlideResume() {
        resumeTimer?.invalidate()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.startAutoSliding()
        }
    }
    
    private func performAutoSlide() {
        guard !isUserInteracting else { return }
        
        let slideSpeed: CGFloat = 0.008
        pct += slideSpeed * autoSlideDirection
        
        // Reverse direction at boundaries with smooth transition
        if pct >= 1.0 {
            pct = 1.0
            autoSlideDirection = -1.0
        } else if pct <= 0.0 {
            pct = 0.0
            autoSlideDirection = 1.0
        }
    }
    
    deinit {
        stopAutoSliding()
    }
}

struct ImageComparisonSlider: UIViewRepresentable {
    let beforeImageName: String
    let afterImageName: String
    @Binding var sliderValue: Double
    let onInteractionStart: (() -> Void)?
    let onInteractionEnd: (() -> Void)?

    init(beforeImageName: String = "test", afterImageName: String = "testEnhanced", sliderValue: Binding<Double>, onInteractionStart: (() -> Void)? = nil, onInteractionEnd: (() -> Void)? = nil) {
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self._sliderValue = sliderValue
        self.onInteractionStart = onInteractionStart
        self.onInteractionEnd = onInteractionEnd
    }

    func makeUIView(context: Context) -> RevealImageView {
        let view = RevealImageView(frame: .zero)
        view.leftImage = UIImage(named: beforeImageName)
        view.rightImage = UIImage(named: afterImageName)
        view.pct = CGFloat(sliderValue)
        view.pctChanged = { pct in
            context.coordinator.update(value: Double(pct))
        }
        view.onInteractionStart = onInteractionStart
        view.onInteractionEnd = onInteractionEnd
        return view
    }

    func updateUIView(_ uiView: RevealImageView, context: Context) {
        uiView.leftImage = UIImage(named: beforeImageName)
        uiView.rightImage = UIImage(named: afterImageName)
        if abs(Double(uiView.pct) - sliderValue) > 0.001 {
            uiView.pct = CGFloat(sliderValue)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sliderValue: $sliderValue)
    }

    class Coordinator {
        var sliderValue: Binding<Double>

        init(sliderValue: Binding<Double>) {
            self.sliderValue = sliderValue
        }

        func update(value: Double) {
            if sliderValue.wrappedValue != value {
                sliderValue.wrappedValue = value
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ImageComparisonSlider(
            beforeImageName: "test",
            afterImageName: "testEnhanced",
            sliderValue: .constant(0.5)
        )
        .frame(height: 100)

        ImageComparisonSlider(
            sliderValue: .constant(0.3)
        )
        .frame(height: 100)
    }
    .padding()
    .background(Color.appBackground)
}

