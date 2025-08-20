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

    private let leftImageLayer = CALayer()
    private let maskLayer = CALayer()
    private let lineView = UIView()

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

        maskLayer.backgroundColor = UIColor.black.cgColor
        leftImageLayer.mask = maskLayer
        leftImageLayer.contentsGravity = .resizeAspectFill
        layer.addSublayer(leftImageLayer)

        lineView.backgroundColor = .white
        addSubview(lineView)

        isUserInteractionEnabled = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        leftImageLayer.frame = bounds
        updateView()
    }

    private func updateView() {
        lineView.frame = CGRect(x: bounds.width * pct,
                                y: 0,
                                width: 2,
                                height: bounds.height)

        var r = bounds
        r.size.width = bounds.width * pct

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = r
        CATransaction.commit()

        pctChanged?(pct)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handle(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handle(touches)
    }

    private func handle(_ touches: Set<UITouch>) {
        guard let t = touches.first else { return }
        let loc = t.location(in: self)
        pct = max(0, min(1, loc.x / bounds.width))
    }
}

struct ImageComparisonSlider: UIViewRepresentable {
    let beforeImageName: String
    let afterImageName: String
    @Binding var sliderValue: Double

    init(beforeImageName: String = "test", afterImageName: String = "testEnhanced", sliderValue: Binding<Double>) {
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self._sliderValue = sliderValue
    }

    func makeUIView(context: Context) -> RevealImageView {
        let view = RevealImageView(frame: .zero)
        view.leftImage = UIImage(named: beforeImageName)
        view.rightImage = UIImage(named: afterImageName)
        view.pct = CGFloat(sliderValue)
        view.pctChanged = { pct in
            context.coordinator.update(value: Double(pct))
        }
        view.layer.cornerRadius = 12
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

