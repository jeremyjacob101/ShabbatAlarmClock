import SwiftUI
import UIKit

struct DiscreteStepSlider: View {
    @Binding private var value: Int

    private let steps: [Int]
    private let accessibilityLabel: String

    @State private var stepPositions: [CGFloat] = []

    init(
        value: Binding<Int>,
        steps: [Int],
        accessibilityLabel: String
    ) {
        _value = value

        let normalizedSteps = Array(Set(steps)).sorted()
        self.steps = normalizedSteps.isEmpty ? [0] : normalizedSteps
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NativeDiscreteSlider(
                value: $value,
                steps: steps,
                accessibilityLabel: accessibilityLabel,
                stepPositions: $stepPositions
            )
            .frame(height: 31)

            TickMarkRow(
                steps: steps,
                stepPositions: stepPositions
            )
            .frame(height: 36)
        }
        .onAppear {
            value = clampedStep(for: value)
        }
        .onChange(of: value) { _, newValue in
            let snappedValue = clampedStep(for: newValue)
            if snappedValue != newValue {
                value = snappedValue
            }
        }
    }

    private func clampedStep(for rawValue: Int) -> Int {
        steps.min {
            let lhs = (abs($0 - rawValue), $0)
            let rhs = (abs($1 - rawValue), $1)
            return lhs < rhs
        } ?? rawValue
    }
}

private struct NativeDiscreteSlider: UIViewRepresentable {
    @Binding var value: Int

    let steps: [Int]
    let accessibilityLabel: String

    @Binding var stepPositions: [CGFloat]

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> StepTrackingSlider {
        let slider = StepTrackingSlider()
        slider.steps = steps
        slider.isContinuous = true
        slider.accessibilityLabel = accessibilityLabel
        slider.setValue(Float(clampedStep(for: value)), animated: false)
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.prepareHaptics),
            for: [.touchDown, .touchDragEnter]
        )
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleValueChanged(_:)),
            for: .valueChanged
        )
        slider.onStepPositionsChanged = { positions in
            context.coordinator.updateStepPositions(positions)
        }

        context.coordinator.lastStep = clampedStep(for: value)
        slider.reportStepPositions()
        return slider
    }

    func updateUIView(_ uiView: StepTrackingSlider, context: Context) {
        context.coordinator.parent = self
        uiView.steps = steps
        uiView.accessibilityLabel = accessibilityLabel

        let snappedValue = clampedStep(for: value)
        if uiView.value != Float(snappedValue) {
            uiView.setValue(Float(snappedValue), animated: false)
        }

        context.coordinator.lastStep = snappedValue
        uiView.reportStepPositions()
    }

    private func clampedStep(for rawValue: Int) -> Int {
        steps.min {
            let lhs = (abs($0 - rawValue), $0)
            let rhs = (abs($1 - rawValue), $1)
            return lhs < rhs
        } ?? rawValue
    }

    final class Coordinator: NSObject {
        var parent: NativeDiscreteSlider
        var lastStep: Int?

        private let haptics = SnapHapticController()

        init(parent: NativeDiscreteSlider) {
            self.parent = parent
        }

        @objc func prepareHaptics() {
            haptics.prepare()
        }

        @objc func handleValueChanged(_ slider: StepTrackingSlider) {
            let snappedValue = parent.clampedStep(for: Int(slider.value.rounded()))

            if slider.value != Float(snappedValue) {
                slider.setValue(Float(snappedValue), animated: false)
            }

            if lastStep != snappedValue {
                if lastStep != nil {
                    haptics.emit()
                } else {
                    haptics.prepare()
                }

                lastStep = snappedValue
            }

            if parent.value != snappedValue {
                parent.value = snappedValue
            }

            slider.reportStepPositions()
        }

        func updateStepPositions(_ positions: [CGFloat]) {
            guard parent.stepPositions != positions else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.parent.stepPositions != positions else { return }
                self.parent.stepPositions = positions
            }
        }
    }
}

private final class StepTrackingSlider: UISlider {
    var steps: [Int] = [0] {
        didSet {
            minimumValue = Float(steps.first ?? 0)
            maximumValue = Float(steps.last ?? 0)
        }
    }

    var onStepPositionsChanged: (([CGFloat]) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumValue = 0
        maximumValue = 0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportStepPositions()
    }

    func reportStepPositions() {
        let track = trackRect(forBounds: bounds)
        let positions = steps.map { step in
            thumbRect(forBounds: bounds, trackRect: track, value: Float(step)).midX
        }

        onStepPositionsChanged?(positions)
    }
}

private struct TickMarkRow: View {
    let steps: [Int]
    let stepPositions: [CGFloat]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 10)

                        Text("\(step)s")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .position(
                        x: position(for: index, width: geometry.size.width),
                        y: geometry.size.height / 2
                    )
                }
            }
        }
    }

    private func position(for index: Int, width: CGFloat) -> CGFloat {
        guard stepPositions.count == steps.count else {
            guard steps.count > 1 else { return width / 2 }
            return width * CGFloat(index) / CGFloat(steps.count - 1)
        }

        return stepPositions[index]
    }
}

private final class SnapHapticController {
    private let generator = UIImpactFeedbackGenerator(style: .soft)

    func prepare() {
        generator.prepare()
    }

    func emit() {
        generator.impactOccurred(intensity: 0.85)
        generator.prepare()
    }
}
