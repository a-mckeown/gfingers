import SwiftUI

struct FretboardView: View {
    @Bindable var state: FretboardState

    /// Kept for call-site compatibility; zoom is applied by ContentView.
    var scale: CGFloat = 1

    private let cellWidth: CGFloat = 52
    private let cellHeight: CGFloat = 42
    private let labelWidth: CGFloat = 40
    private let nutBarWidth: CGFloat = 8
    private let markerFrets: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]
    private let doubleMarkers: Set<Int> = [12, 24]

    private var boardWidth: CGFloat {
        labelWidth + nutBarWidth + CGFloat(Tuning.fretCount) * cellWidth
    }

    private var boardHeight: CGFloat {
        CGFloat(Tuning.stringCount) * cellHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 0) {
                muteColumn
                nutBar
                fretGrid
            }
            fretNumbers
        }
        .padding(8)
        .background(wood, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(scale, anchor: .topLeading)
        .frame(
            width: (boardWidth + 16) * scale,
            height: (boardHeight + 34) * scale,
            alignment: .topLeading
        )
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

    /// String names live left of the nut. ○ / ✕ is open vs muted.
    private var muteColumn: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< Tuning.stringCount, id: \.self) { string in
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
                }
                .buttonStyle(.plain)
                .accessibilityLabel("String \(Tuning.stringNames[string])")
            }
        }
    }

    /// The nut is the thick bone/metal bar *before* fret 1.
    private var nutBar: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.95), Color(white: 0.7), Color(white: 0.92)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: nutBarWidth, height: boardHeight)
            .shadow(color: .black.opacity(0.35), radius: 1, x: 1)
    }

    private var fretGrid: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< Tuning.stringCount, id: \.self) { string in
                ZStack {
                    stringWire(thickness: max(1.0, 3.1 - CGFloat(string) * 0.34))
                    HStack(spacing: 0) {
                        ForEach(1 ... Tuning.fretCount, id: \.self) { fret in
                            fretCell(string: string, fret: fret)
                        }
                    }
                }
                .frame(height: cellHeight)
            }
        }
    }

    private func stringWire(thickness: CGFloat) -> some View {
        Rectangle()
            .fill(Color(white: 0.8))
            .frame(height: thickness)
            .frame(maxWidth: .infinity)
    }

    private func fretCell(string: Int, fret: Int) -> some View {
        Button {
            state.tap(string: string, fret: fret)
        } label: {
            ZStack {
                if string == 2 {
                    marker(for: fret)
                }
                Color.clear
                if let finger = displayedFinger(string: string, fret: fret) {
                    Circle()
                        .fill(Color(red: 0.96, green: 0.74, blue: 0.28))
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                    Text("\(state.fingerNumber(for: finger))")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Color(red: 0.22, green: 0.12, blue: 0.05))
                }
                // Fret wire is the *right* edge of this fret (after the finger).
                Rectangle()
                    .fill(fretWire)
                    .frame(width: doubleMarkers.contains(fret) ? 3 : 1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            .frame(width: cellWidth, height: cellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("String \(Tuning.stringNames[string]), fret \(fret)")
    }

    private func marker(for fret: Int) -> some View {
        Group {
            if doubleMarkers.contains(fret) || markerFrets.contains(fret) {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private var fretWire: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.9), Color(white: 0.55), Color(white: 0.9)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var fretNumbers: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: labelWidth + nutBarWidth, height: 16)
            ForEach(1 ... Tuning.fretCount, id: \.self) { fret in
                Text("\(fret)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: cellWidth, height: 16)
            }
        }
    }

    private func displayedFinger(string: Int, fret: Int) -> Finger? {
        state.fingers.first { $0.fret == fret && $0.covers(string: string) }
    }

    private func nutGlyph(for string: Int) -> String {
        if state.muted[string] { return "✕" }
        if state.covers(string: string) != nil { return "●" }
        return "○"
    }
}
