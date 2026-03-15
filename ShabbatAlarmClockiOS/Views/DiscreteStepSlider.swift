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
                stepPositions: stepPositions,
                selectedStep: value
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
        slider.updateAccessibilityValue(with: clampedStep(for: value))
        slider.setValue(sliderValue(for: value), animated: false)
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

        context.coordinator.lastStepIndex = stepIndex(for: value)
        slider.reportStepPositions()
        return slider
    }

    func updateUIView(_ uiView: StepTrackingSlider, context: Context) {
        context.coordinator.parent = self
        uiView.steps = steps
        uiView.accessibilityLabel = accessibilityLabel

        let snappedValue = clampedStep(for: value)
        let snappedSliderValue = sliderValue(for: snappedValue)
        uiView.updateAccessibilityValue(with: snappedValue)

        if uiView.value != snappedSliderValue {
            uiView.setValue(snappedSliderValue, animated: false)
        }

        context.coordinator.lastStepIndex = stepIndex(for: snappedValue)
        uiView.reportStepPositions()
    }

    private func clampedStep(for rawValue: Int) -> Int {
        steps.min {
            let lhs = (abs($0 - rawValue), $0)
            let rhs = (abs($1 - rawValue), $1)
            return lhs < rhs
        } ?? rawValue
    }

    private func stepIndex(for stepValue: Int) -> Int {
        guard let index = steps.firstIndex(of: clampedStep(for: stepValue)) else { return 0 }
        return index
    }

    private func stepIndex(forSliderValue sliderValue: Float) -> Int {
        let roundedIndex = Int(sliderValue.rounded())
        return min(max(roundedIndex, 0), max(steps.count - 1, 0))
    }

    private func sliderValue(for stepValue: Int) -> Float {
        Float(stepIndex(for: stepValue))
    }

    final class Coordinator: NSObject {
        var parent: NativeDiscreteSlider
        var lastStepIndex: Int?

        private let haptics = SnapHapticController()

        init(parent: NativeDiscreteSlider) {
            self.parent = parent
        }

        @objc func prepareHaptics() {
            haptics.prepare()
        }

        @objc func handleValueChanged(_ slider: StepTrackingSlider) {
            let snappedIndex = parent.stepIndex(forSliderValue: slider.value)
            let snappedValue = parent.steps[snappedIndex]
            let snappedSliderValue = slider.sliderValue(forStepIndex: snappedIndex)

            if slider.value != snappedSliderValue {
                slider.setValue(snappedSliderValue, animated: false)
            }

            slider.updateAccessibilityValue(with: snappedValue)

            if lastStepIndex != snappedIndex {
                if lastStepIndex != nil {
                    haptics.emit()
                } else {
                    haptics.prepare()
                }

                lastStepIndex = snappedIndex
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
    private let endpointStepPadding: Float = 0.001

    var steps: [Int] = [0] {
        didSet {
            updateRange()
        }
    }

    var onStepPositionsChanged: (([CGFloat]) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        updateRange()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        updateRange()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportStepPositions()
    }
    func sliderValue(forStepIndex index: Int) -> Float {
        Float(min(max(index, 0), max(steps.count - 1, 0)))
    }

    func updateAccessibilityValue(with stepValue: Int) {
        accessibilityValue = "\(stepValue) seconds"
    }

    func reportStepPositions() {
        let track = trackRect(forBounds: bounds)
        let positions = steps.indices.map { index in
            thumbRect(
                forBounds: bounds,
                trackRect: track,
                value: sliderValue(forStepIndex: index)
            ).midX
        }

        onStepPositionsChanged?(positions)
    }

    private func updateRange() {
        guard steps.count > 1 else {
            minimumValue = 0
            maximumValue = 0
            return
        }

        minimumValue = -endpointStepPadding
        maximumValue = Float(steps.count - 1) + endpointStepPadding
    }
}

private struct TickMarkRow: View {
    let steps: [Int]
    let stepPositions: [CGFloat]
    let selectedStep: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    let isReached = step <= selectedStep

                    VStack(spacing: 4) {
                        Capsule()
                            .fill(isReached ? Color.accentColor : Color.secondary.opacity(0.28))
                            .frame(width: 3, height: 10)

                        Text("\(step)s")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(isReached ? Color.accentColor : Color.secondary)
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
