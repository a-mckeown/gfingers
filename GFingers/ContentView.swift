import SwiftUI

struct ContentView: View {
    @StateObject private var board = FretboardState()
    @StateObject private var listener = AudioChordListener()
    @State private var scale: CGFloat = 1.15
    @State private var pinchBase: CGFloat = 1.15

    private var voicingTab: String {
        board.currentFrets().map { fret in
            guard let fret else { return "x" }
            return String(fret)
        }.joined(separator: " ")
    }

    private var reading: ChordReading {
        if listener.isListening {
            return listener.reading ?? ChordReading(
                symbol: "…",
                qualityName: listener.statusMessage ?? "Listening for a guitar…",
                shape: "Listen",
                notes: ""
            )
        }
        if board.fingers.isEmpty {
            return ChordReading(
                symbol: "…",
                qualityName: "Place a shape, or turn on Listen.",
                shape: "",
                notes: ""
            )
        }
        return ChordDetector.read(from: board)
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
        .onDisappear { listener.stop() }
        .onChange(of: listener.reading?.symbol) { symbol in
            guard listener.isListening, let symbol else { return }
            applyListenShape(symbol)
        }
    }

    private func applyListenShape(_ symbol: String) {
        guard let shape = GuitarShapes.voicing(for: symbol) else { return }
        board.apply(frets: shape.frets)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("G-Fingers")
                    .font(.title2.weight(.bold))
                Text("Place a shape. Hear its name.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Toggle(isOn: Binding(
                get: { listener.isListening },
                set: { on in
                    if on {
                        board.clear()
                        listener.start()
                    } else {
                        listener.stop()
                    }
                }
            )) {
                Text(listener.isListening ? "Listening" : "Listen")
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.button)
            .tint(.green)

            Button("Clear") {
                withAnimation(nil) {
                    board.clear()
                }
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
            if !listener.isListening, !board.fingers.isEmpty {
                Text("E A D G B e  \(voicingTab)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.4))
            }
            if listener.isListening, let listenStatus = listener.statusMessage {
                Text(listenStatus)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            if let status = board.statusMessage, !listener.isListening {
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
            Toggle(isOn: Binding(
                get: { board.barreMode },
                set: { board.barreMode = $0; if $0 { board.capoMode = false } }
            )) {
                Text("Barre")
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.button)
            .tint(.orange)

            Toggle(isOn: Binding(
                get: { board.capoMode },
                set: { board.capoMode = $0; if $0 { board.barreMode = false } }
            )) {
                Text(board.capoFret.map { "Capo \($0)" } ?? "Capo")
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.button)
            .tint(.red)

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
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                FretboardView(state: board, scale: scale, isListening: listener.isListening)
                    .padding(16)
                    .id("headstock")
            }
            .scrollDisabled(board.isDraggingCapo || board.isDraggingShape)
            .onAppear {
                proxy.scrollTo("headstock", anchor: UnitPoint(x: 0, y: 0))
            }
        }
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { magnification in
                    scale = min(3.2, max(0.7, pinchBase * magnification))
                }
                .onEnded { _ in
                    pinchBase = scale
                }
        )
    }

    private var hint: some View {
        Text("Listen hears a guitar in standard tuning and names the chord. Drag fingers to slide a shape. Capo drags on its own.")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
}
