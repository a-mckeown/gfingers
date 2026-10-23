import AVFoundation
import Accelerate
import Combine
import Foundation

/// Listens to the microphone, builds a chromagram, and names guitar chords in standard tuning.
final class AudioChordListener: ObservableObject {
    @Published var isListening = false
    @Published var reading: ChordReading?
    @Published var statusMessage: String?

    private let engine = AVAudioEngine()
    private var fftSetup: FFTSetup?
    private let log2n: vDSP_Length = 12
    private var fftSize: Int { 1 << Int(log2n) }

    private var window: [Float] = []
    private var samples: [Float] = []
    private var smoothChroma = [Float](repeating: 0, count: 12)
    private var smoothBass = [Float](repeating: 0, count: 12)
    private var recentSymbols: [String] = []
    private let lock = NSLock()

    private static let qualities: [(suffix: String, label: String, intervals: [Int])] = [
        ("maj7", "major seventh", [0, 4, 7, 11]),
        ("m7", "minor seventh", [0, 3, 7, 10]),
        ("7", "dominant seventh", [0, 4, 7, 10]),
        ("sus4", "suspended four", [0, 5, 7]),
        ("sus2", "suspended two", [0, 2, 7]),
        ("dim", "diminished", [0, 3, 6]),
        ("aug", "augmented", [0, 4, 8]),
        ("m", "minor", [0, 3, 7]),
        ("", "major", [0, 4, 7]),
        ("5", "power chord", [0, 7]),
    ]

    func toggle() {
        if isListening { stop() } else { start() }
    }

    func start() {
        stop()
        statusMessage = "Allow the microphone, then play a chord."
        reading = nil
        recentSymbols = []
        smoothChroma = [Float](repeating: 0, count: 12)
        smoothBass = [Float](repeating: 0, count: 12)

        switch AVAudioSession.sharedInstance().recordPermission {
        case .denied:
            statusMessage = "Microphone access is off. Enable it in Settings."
            return
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.startEngine() }
                    else { self?.statusMessage = "Microphone access is off. Enable it in Settings." }
                }
            }
        default:
            startEngine()
        }
    }

    func stop() {
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isListening = false
        if fftSetup != nil {
            vDSP_destroy_fftsetup(fftSetup)
            fftSetup = nil
        }
    }

    deinit { stop() }

    private func startEngine() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(44_100)
            try session.setActive(true, options: [])

            engine.reset()
            let input = engine.inputNode
            let format = input.inputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                statusMessage = "No microphone on this device. Try a real iPhone."
                return
            }

            fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
            window = [Float](repeating: 0, count: fftSize)
            vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
            samples = []

            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                self?.append(buffer: buffer, sampleRate: format.sampleRate)
            }
            engine.prepare()
            try engine.start()
            isListening = true
            statusMessage = "Listening — play closer to the iPhone if needed."
        } catch {
            statusMessage = "Could not start the microphone: \(error.localizedDescription)"
            isListening = false
        }
    }

    private func append(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        lock.lock()
        samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: count))
        if samples.count > fftSize * 4 {
            samples.removeFirst(samples.count - fftSize * 2)
        }
        while samples.count >= fftSize {
            let frame = Array(samples.prefix(fftSize))
            samples.removeFirst(fftSize / 2)
            lock.unlock()
            analyze(frame: frame, sampleRate: sampleRate)
            lock.lock()
        }
        lock.unlock()
    }

    private func analyze(frame: [Float], sampleRate: Double) {
        guard let fftSetup else { return }

        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        var rms: Float = 0
        vDSP_rmsqv(windowed, 1, &rms, vDSP_Length(fftSize))
        // Quiet frames: keep the last chord instead of flashing "…"
        if rms < 0.0012 { return }

        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        for i in 0 ..< (fftSize / 2) {
            realp[i] = windowed[2 * i]
            imagp[i] = windowed[2 * i + 1]
        }
        realp.withUnsafeMutableBufferPointer { r in
            imagp.withUnsafeMutableBufferPointer { i in
                var split = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realp.withUnsafeMutableBufferPointer { r in
            imagp.withUnsafeMutableBufferPointer { i in
                var split = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        var chroma = [Float](repeating: 0, count: 12)
        var bass = [Float](repeating: 0, count: 12)
        let binHz = sampleRate / Double(fftSize)
        for bin in 2 ..< (fftSize / 2) {
            let freq = Double(bin) * binHz
            if freq < 75 || freq > 1200 { continue }
            let mag = sqrt(max(0, magnitudes[bin]))
            if mag < 1e-6 { continue }
            let midi = 69.0 + 12.0 * log2(freq / 440.0)
            if midi < 39 || midi > 86 { continue }
            // Do not bias pitch down — a -0.15 offset turned B7 into B♭7 on the iPhone mic.
            var pc = Int(midi.rounded(.toNearestOrAwayFromZero)) % 12
            if pc < 0 { pc += 12 }
            // Soften upper harmonics so the third of the chord can still be heard.
            let harmonicWeight = Float(1.0 / max(1.0, freq / 220.0))
            chroma[pc] += mag * (0.35 + 0.65 * harmonicWeight)
            if freq >= 75, freq <= 200 {
                bass[pc] += mag
            }
        }

        lock.lock()
        for i in 0 ..< 12 {
            smoothChroma[i] = smoothChroma[i] * 0.55 + chroma[i] * 0.45
            smoothBass[i] = smoothBass[i] * 0.6 + bass[i] * 0.4
        }
        let display = smoothChroma
        let bassDisplay = smoothBass
        lock.unlock()

        guard let match = bestChord(chroma: display, bass: bassDisplay) else {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isListening, self.reading == nil else { return }
                self.statusMessage = "Hearing the guitar — hold the chord."
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.isListening else { return }
            self.recentSymbols.append(match.symbol)
            if self.recentSymbols.count > 6 {
                self.recentSymbols.removeFirst()
            }
            var counts = Dictionary(self.recentSymbols.map { ($0, 1) }, uniquingKeysWith: +)
            // If both D and D5 appear, keep the triad.
            for (symbol, count) in counts {
                if symbol.hasSuffix("5"), !symbol.contains("♯"), !symbol.contains("♭") {
                    let triad = String(symbol.dropLast())
                    if let triadCount = counts[triad], triadCount > 0 {
                        counts[triad] = triadCount + count
                        counts[symbol] = 0
                    }
                }
                // Mic harmonics often look like a 7. If D and D7 both appear, keep D.
                if symbol.hasSuffix("7"), !symbol.hasSuffix("maj7") {
                    let triad = String(symbol.dropLast())
                    if let triadCount = counts[triad], triadCount > 0 {
                        counts[triad] = triadCount + count
                        counts[symbol] = 0
                    }
                }
            }
            let stable = counts.max(by: { $0.value < $1.value })
            if let stable, stable.value >= 2 {
                var shown = match
                shown.symbol = stable.key
                shown.qualityName = Self.qualityName(for: stable.key)
                shown.shape = "Listen"
                self.reading = shown
                self.statusMessage = nil
            } else if self.reading == nil {
                self.statusMessage = "Hearing the guitar — hold the chord."
            }
        }
    }

    private func bestChord(chroma: [Float], bass: [Float]) -> ChordReading? {
        var compressed = chroma
        for i in 0 ..< 12 {
            compressed[i] = log1p(chroma[i])
        }
        var maxVal: Float = 0
        vDSP_maxv(compressed, 1, &maxVal, 12)
        guard maxVal > 0.0001 else { return nil }

        var norm = [Float](repeating: 0, count: 12)
        var recip = 1 / maxVal
        vDSP_vsmul(compressed, 1, &recip, &norm, 1, 12)

        let peak = norm.max() ?? 0
        var bassMax: Float = 0
        vDSP_maxv(bass, 1, &bassMax, 12)
        var bassNorm = [Float](repeating: 0, count: 12)
        if bassMax > 0 {
            var recipB = 1 / bassMax
            vDSP_vsmul(bass, 1, &recipB, &bassNorm, 1, 12)
        }
        var best: (score: Float, root: Int, suffix: String, label: String)?

        for root in 0 ..< 12 {
            let rootE = norm[root]
            guard rootE >= 0.12 else { continue }
            let min3 = norm[(root + 3) % 12]
            let maj3 = norm[(root + 4) % 12]
            let fifth = norm[(root + 7) % 12]
            let b7 = norm[(root + 10) % 12]
            let maj7 = norm[(root + 11) % 12]
            let bassRoot = bassNorm[root]
            // E's fifth is B (and B's overtone is F♯), so an E chord can look like B.
            // If a major or minor triad a fifth below this root has more bass, this isn't the tonic.
            let fifthBelow = (root + 5) % 12
            let lowerThird = max(norm[(fifthBelow + 4) % 12], norm[(fifthBelow + 3) % 12])
            let looksLikeFifthOfLowerTonic =
                bassNorm[fifthBelow] >= bassRoot * 0.7
                && norm[fifthBelow] >= 0.12
                && lowerThird >= 0.10
                && norm[(fifthBelow + 7) % 12] >= 0.10

            for quality in Self.qualities {
                let tones = quality.intervals.map { norm[(root + $0) % 12] }
                let weakest = tones.min() ?? 0
                // A chord tone can be quiet (open-string imbalance) but must be there.
                let minTone: Float = quality.suffix == "5" ? 0.28 : 0.11
                if weakest < minTone { continue }
                if looksLikeFifthOfLowerTonic, quality.suffix == "" || quality.suffix == "5" || quality.suffix == "7" {
                    continue
                }
                // Harmonics of D and G look like maj7 (C♯ / F♯). Demand a real seventh.
                if quality.suffix == "maj7", maj7 < 0.45 || maj7 < maj3 * 0.95 { continue }
                // Open D/G leak a faint C/F. Need a strong b7 to call it a 7.
                if quality.suffix == "7" {
                    if b7 < 0.30 || b7 < maj3 * 0.75 { continue }
                    if maj7 > b7 * 0.9 { continue }
                    // Em can look like C7, Am like F7 (minor triad on the 3rd, B vs B♭).
                    let onThird = (root + 4) % 12
                    let minorOnThird = norm[onThird] >= 0.18
                        && norm[(onThird + 3) % 12] >= 0.11
                        && norm[(onThird + 7) % 12] >= b7 * 0.85
                    if minorOnThird { continue }
                }
                if quality.suffix == "m7", b7 < 0.34 || b7 < min3 * 0.8 { continue }
                // D (D–F♯–A) plus a weak B is Bm7. Only keep m7 if B is really the root.
                if quality.suffix.contains("7"), rootE < peak * 0.72 { continue }
                if quality.suffix == "m7" {
                    let relativeMajor = (root + 3) % 12
                    if norm[relativeMajor] >= rootE * 0.72 { continue }
                }

                var score = tones.reduce(0, +)
                // Penalise leftover loud notes that are not in the chord.
                for pc in 0 ..< 12 {
                    let inChord = quality.intervals.contains { (root + $0) % 12 == pc }
                    if !inChord { score -= norm[pc] * 0.28 }
                }

                if quality.suffix == "5" {
                    // Open Em/A/C often look like power chords if we allow 5s too easily.
                    if max(min3, maj3) >= 0.11 { continue }
                    score *= 0.7
                }
                // F♯ harmonic of E looks like Esus2 (high e at fret 2). Keep plain E.
                if quality.suffix == "sus2", maj3 >= 0.12 { continue }
                if quality.suffix == "sus4", maj3 >= 0.12 { continue }
                if quality.suffix == "", maj3 >= 0.11 { score += 0.55 + rootE * 0.9 }
                if quality.suffix == "m", min3 >= 0.11 { score += 0.55 + rootE * 0.7 }
                if quality.suffix == "7", b7 >= 0.40 { score += 0.2 }
                if quality.suffix == "maj7" { score -= 0.4 }
                score += bassRoot * 0.9
                if fifth < 0.12 { score -= 0.2 }

                if best == nil || score > best!.score {
                    best = (score, root, quality.suffix, quality.label)
                }
            }
        }

        guard let best, best.score >= 0.55 else { return nil }
        let flats = Tuning.preferFlats(forRoot: best.root)
        let name = Tuning.noteName(best.root, flats: flats)
        let notes = (0 ..< 12).compactMap { pc -> String? in
            norm[pc] >= 0.16 ? Tuning.noteName(pc, flats: flats) : nil
        }
        return ChordReading(
            symbol: name + best.suffix,
            qualityName: "\(name) \(best.label)",
            shape: "Listen",
            notes: notes.joined(separator: " · ")
        )
    }

    private static func qualityName(for symbol: String) -> String {
        if symbol.hasSuffix("maj7") {
            return "\(String(symbol.dropLast(4))) major seventh"
        }
        if symbol.hasSuffix("m7") {
            return "\(String(symbol.dropLast(2))) minor seventh"
        }
        if symbol.hasSuffix("7") {
            return "\(String(symbol.dropLast())) dominant seventh"
        }
        if symbol.hasSuffix("m") {
            return "\(String(symbol.dropLast())) minor"
        }
        if symbol.hasSuffix("5") {
            return "\(String(symbol.dropLast())) power chord"
        }
        return "\(symbol) major"
    }
}
