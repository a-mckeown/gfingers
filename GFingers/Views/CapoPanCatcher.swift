import SwiftUI
import UIKit

/// Pan that disables the enclosing scroll view so the neck does not move.
struct CapoPanCatcher: UIViewRepresentable {
    var cellWidth: CGFloat
    var currentFret: Int
    var onBegan: () -> Void
    /// Absolute fret from the value captured at `.began` (used by the capo).
    var onMoveToFret: ((Int) -> Void)? = nil
    /// Fret offset from the drag start (used by sliding a whole shape).
    var onFretDelta: ((Int) -> Void)? = nil
    var onEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
        pan.cancelsTouchesInView = true
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        context.coordinator.pan = pan
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.cellWidth = cellWidth
        context.coordinator.currentFret = currentFret
        context.coordinator.onBegan = onBegan
        context.coordinator.onMoveToFret = onMoveToFret
        context.coordinator.onFretDelta = onFretDelta
        context.coordinator.onEnded = onEnded
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var cellWidth: CGFloat = 44
        var currentFret: Int = 1
        var dragStartFret: Int = 1
        var onBegan: () -> Void = {}
        var onMoveToFret: ((Int) -> Void)?
        var onFretDelta: ((Int) -> Void)?
        var onEnded: () -> Void = {}
        weak var pan: UIPanGestureRecognizer?

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            false
        }

        @objc func handlePan(_ pan: UIPanGestureRecognizer) {
            let scroll = pan.view?.enclosingScrollView()
            switch pan.state {
            case .began:
                dragStartFret = currentFret
                scroll?.isScrollEnabled = false
                onBegan()
            case .changed:
                let dx = pan.translation(in: pan.view).x
                let delta = Int((dx / cellWidth).rounded())
                onFretDelta?(delta)
                onMoveToFret?(dragStartFret + delta)
            default:
                scroll?.isScrollEnabled = true
                onEnded()
            }
        }
    }
}

private extension UIView {
    func enclosingScrollView() -> UIScrollView? {
        var node: UIView? = self
        while let current = node {
            if let scroll = current as? UIScrollView { return scroll }
            node = current.superview
        }
        return nil
    }
}
