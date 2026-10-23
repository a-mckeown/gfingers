import SwiftUI

struct FretboardView: View {
    @ObservedObject var state: FretboardState

    /// Kept for call-site compatibility; zoom is applied by ContentView.
    var scale: CGFloat = 1

    private let cellWidth: CGFloat = 44
    private let cellHeight: CGFloat = 42
    private let labelWidth: CGFloat = 36
    private let nutBarWidth: CGFloat = 7
    private let markerFrets: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]
    private let doubleMarkers: Set<Int> = [12, 24]

    private var neckWidth: CGFloat {
        nutBarWidth + CGFloat(Tuning.fretCount) * cellWidth
    }

    private var neckHeight: CGFloat {
        CGFloat(Tuning.stringCount) * cellHeight
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            muteColumn
            VStack(alignment: .leading, spacing: 4) {
                neck
                fretNumbers
            }
        }
        .padding(8)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(
            width: (labelWidth + 6 + neckWidth + 16) * scale,
            height: (neckHeight + 28) * scale,
            alignment: .topLeading
        )
    }

    /// Nut/head on the left; fret 1, then 2 to its right, toward the body.
    private func fretCellMinX(_ fret: Int) -> CGFloat {
        nutBarWidth + CGFloat(fret - 1) * cellWidth
    }

    /// High e at the top of the screen, low E at the bottom.
    private var stringsTopToBottom: [Int] {
        Array((0 ..< Tuning.stringCount).reversed())
    }

    /// Labels sit off the wood so they are not mistaken for extra fret space.
    private var muteColumn: some View {
        VStack(spacing: 0) {
            ForEach(stringsTopToBottom, id: \.self) { string in
                Button {
                    state.toggleMute(string: string)
                } label: {
                    VStack(spacing: 1) {
                        Text(Tuning.stringNames[string])
                            .font(.caption.weight(.bold))
                        Text(nutGlyph(for: string))
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(state.muted[string] ? Color.red.opacity(0.95) : Color.white)
                    .frame(width: labelWidth, height: cellHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("String \(Tuning.stringNames[string])")
            }
        }
    }

    private var neck: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(wood)

            fretMarkers

            stringWires

            // Equal-spaced metal: nut on the left, then a wire after every fret.
            nutAndFretWires

            capoBand

            fingerGrid
        }
        .frame(width: neckWidth, height: neckHeight)
        .clipped()
    }

    private var wood: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.45, green: 0.28, blue: 0.15),
                Color(red: 0.27, green: 0.15, blue: 0.07),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var nutAndFretWires: some View {
        Canvas { context, size in
            let nut = Path(CGRect(x: 0, y: 0, width: nutBarWidth, height: size.height))
            context.fill(
                nut,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(white: 0.96),
                        Color(white: 0.72),
                        Color(white: 0.9),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: nutBarWidth, y: 0)
                )
            )

            for fret in 1 ... Tuning.fretCount {
                let thickness: CGFloat = doubleMarkers.contains(fret) ? 3 : 2
                let x = fretCellMinX(fret) + cellWidth - thickness
                let wire = Path(CGRect(x: x, y: 0, width: thickness, height: size.height))
                context.fill(
                    wire,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(white: 0.92),
                            Color(white: 0.58),
                            Color(white: 0.88),
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var stringWires: some View {
        ForEach(0 ..< Tuning.stringCount, id: \.self) { string in
            let thickness = max(1.1, 3.0 - CGFloat(string) * 0.32)
            let row = CGFloat(Tuning.stringCount - 1 - string)
            Rectangle()
                .fill(Color(white: 0.82))
                .frame(width: neckWidth, height: thickness)
                .offset(y: row * cellHeight + cellHeight / 2 - thickness / 2)
        }
        .allowsHitTesting(false)
    }

    private var fretMarkers: some View {
        ForEach(1 ... Tuning.fretCount, id: \.self) { fret in
            if markerFrets.contains(fret) || doubleMarkers.contains(fret) {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 9, height: 9)
                    .offset(
                        x: fretCellMinX(fret) + cellWidth / 2 - 4.5,
                        y: neckHeight / 2 - 4.5
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var capoBand: some View {
        Group {
            if let capo = state.capoFret {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.08, blue: 0.08),
                                Color(red: 0.18, green: 0.05, blue: 0.05),
                                Color(red: 0.32, green: 0.09, blue: 0.09),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Text("CAPO")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.85))
                            .rotationEffect(.degrees(-90))
                    )
                    .frame(width: cellWidth - 4, height: neckHeight - 4)
                    .offset(x: fretCellMinX(capo) + 2, y: 2)
                    .allowsHitTesting(false)
            }
        }
    }

    private var fingerGrid: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: nutBarWidth)
            ForEach(1 ... Tuning.fretCount, id: \.self) { fret in
                VStack(spacing: 0) {
                    ForEach(stringsTopToBottom, id: \.self) { string in
                        Button {
                            state.tap(string: string, fret: fret)
                        } label: {
                            ZStack {
                                Color.clear
                                if let finger = displayedFinger(string: string, fret: fret) {
                                    Circle()
                                        .fill(Color(red: 0.96, green: 0.74, blue: 0.28))
                                        .frame(width: 26, height: 26)
                                        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                                    Text("\(state.fingerNumber(for: finger))")
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(Color(red: 0.22, green: 0.12, blue: 0.05))
                                }
                            }
                            .frame(width: cellWidth, height: cellHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("String \(Tuning.stringNames[string]), fret \(fret)")
                    }
                }
            }
        }
    }

    private var fretNumbers: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: nutBarWidth)
            ForEach(1 ... Tuning.fretCount, id: \.self) { fret in
                Text("\(fret)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(state.capoFret == fret ? Color.red.opacity(0.95) : Color.white.opacity(0.55))
                    .frame(width: cellWidth, height: 16)
            }
        }
    }

    private func displayedFinger(string: Int, fret: Int) -> Finger? {
        state.fingers.first { $0.fret == fret && $0.covers(string: string) }
    }

    private func nutGlyph(for string: Int) -> String {
        if state.muted[string] { return "✕" }
        let capo = state.capoFret ?? 0
        if let stopped = state.fingerFret(on: string), stopped > capo { return "●" }
        return "○"
    }
}
