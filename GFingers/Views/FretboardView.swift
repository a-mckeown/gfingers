import SwiftUI

struct FretboardView: View {
    @Bindable var state: FretboardState

    /// Kept for call-site compatibility; zoom is applied by ContentView.
    var scale: CGFloat = 1

    private let cellWidth: CGFloat = 52
    private let cellHeight: CGFloat = 42
    private let nutWidth: CGFloat = 48
    private let markerFrets: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]
    private let doubleMarkers: Set<Int> = [12, 24]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                nutColumn
                fretGrid
            }
            fretNumbers
        }
        .padding(8)
        .background(wood, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(scale, anchor: .topLeading)
        .frame(
            width: (nutWidth + CGFloat(Tuning.fretCount) * cellWidth + 16) * scale,
            height: (CGFloat(Tuning.stringCount) * cellHeight + 42) * scale,
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

    private var nutColumn: some View {
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
                    .frame(width: nutWidth, height: cellHeight)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("String \(Tuning.stringNames[string])")
            }
        }
        .background(Color.white.opacity(0.12))
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
                if string == 0 {
                    marker(for: fret)
                }
                Rectangle()
                    .fill(Color.clear)
                Rectangle()
                    .fill(fretWire)
                    .frame(width: fret == 1 ? 5 : 1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                if let finger = displayedFinger(string: string, fret: fret) {
                    Circle()
                        .fill(Color(red: 0.96, green: 0.74, blue: 0.28))
                        .frame(width: 28, height: 28)
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

    private func marker(for fret: Int) -> some View {
        Group {
            if doubleMarkers.contains(fret) || markerFrets.contains(fret) {
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 9, height: 9)
                    .offset(y: cellHeight * 2.5)
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
            Color.clear.frame(width: nutWidth, height: 18)
            ForEach(1 ... Tuning.fretCount, id: \.self) { fret in
                Text("\(fret)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: cellWidth, height: 18)
            }
        }
        .padding(.top, 4)
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
