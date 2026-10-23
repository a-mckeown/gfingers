import SwiftUI

struct ContentView: View {
    @State private var board = FretboardState()
    @State private var scale: CGFloat = 1.15
    @State private var pinchBase: CGFloat = 1.15

    private var reading: ChordReading {
        ChordDetector.read(from: board)
    }

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.07, blue: 0.05).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                chordHUD
                controls
                fretboardScroll
                hint
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("gfingers")
                    .font(.title2.weight(.bold))
                Text("Place a shape. Hear its name.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button("Clear") {
                board.clear()
                board.barreMode = false
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.08), in: Capsule())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var chordHUD: some View {
        VStack(spacing: 6) {
            Text(reading.symbol)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            if !reading.qualityName.isEmpty {
                Text(reading.qualityName)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            if !reading.shape.isEmpty {
                Text(reading.shape)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.22), in: Capsule())
            }
            if !reading.notes.isEmpty {
                Text(reading.notes)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.white.opacity(0.55))
            }
            if let status = board.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Toggle(isOn: $board.barreMode) {
                Text("Barre")
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.button)
            .tint(.orange)

            Text("\(board.fingers.count)/4 fingers")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))

            Spacer()

            Button {
                scale = 1.15
                pinchBase = 1.15
            } label: {
                Text("Reset zoom")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var fretboardScroll: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            FretboardView(state: board, scale: scale)
                .padding(16)
        }
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    scale = min(3.2, max(0.7, pinchBase * value.magnification))
                }
                .onEnded { _ in
                    pinchBase = scale
                }
        )
    }

    private var hint: some View {
        Text("Barre once (tap a fret), then tap extra notes as single fingers. F major: Barre on fret 1 of low E, then A3, D3, G2. Open D: mute E and A, then 2–3–2 on G/B/e.")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
}
