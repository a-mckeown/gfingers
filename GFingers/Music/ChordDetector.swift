import Foundation

struct ChordReading: Equatable {
    var symbol: String
    var qualityName: String
    var shape: String
    var notes: String
}

enum ChordDetector {
    private struct Formula {
        let suffix: String
        let label: String
        let intervals: Set<Int>
        let optional: Set<Int>
        let extraWeight: Int
    }

    /// More notes / more specific qualities first.
    private static let formulas: [Formula] = [
        .init(suffix: "13", label: "thirteenth", intervals: [0, 4, 7, 10, 9, 2], optional: [7, 2], extraWeight: 6),
        .init(suffix: "m13", label: "minor thirteenth", intervals: [0, 3, 7, 10, 9, 2], optional: [7, 2], extraWeight: 6),
        .init(suffix: "11", label: "eleventh", intervals: [0, 4, 7, 10, 2, 5], optional: [7, 2, 4], extraWeight: 5),
        .init(suffix: "m11", label: "minor eleventh", intervals: [0, 3, 7, 10, 2, 5], optional: [7, 2], extraWeight: 5),
        .init(suffix: "maj9", label: "major ninth", intervals: [0, 4, 7, 11, 2], optional: [7], extraWeight: 5),
        .init(suffix: "9", label: "dominant ninth", intervals: [0, 4, 7, 10, 2], optional: [7], extraWeight: 5),
        .init(suffix: "m9", label: "minor ninth", intervals: [0, 3, 7, 10, 2], optional: [7], extraWeight: 5),
        .init(suffix: "7♯9", label: "dominant seventh sharp nine", intervals: [0, 4, 7, 10, 3], optional: [7], extraWeight: 4),
        .init(suffix: "7♭9", label: "dominant seventh flat nine", intervals: [0, 4, 7, 10, 1], optional: [7], extraWeight: 4),
        .init(suffix: "7♯5", label: "dominant seventh sharp five", intervals: [0, 4, 8, 10], optional: [], extraWeight: 4),
        .init(suffix: "7♭5", label: "dominant seventh flat five", intervals: [0, 4, 6, 10], optional: [], extraWeight: 4),
        .init(suffix: "maj7", label: "major seventh", intervals: [0, 4, 7, 11], optional: [7], extraWeight: 4),
        .init(suffix: "m7♭5", label: "half-diminished seventh", intervals: [0, 3, 6, 10], optional: [], extraWeight: 4),
        .init(suffix: "dim7", label: "diminished seventh", intervals: [0, 3, 6, 9], optional: [], extraWeight: 4),
        .init(suffix: "7sus4", label: "dominant seventh suspended four", intervals: [0, 5, 7, 10], optional: [7], extraWeight: 4),
        .init(suffix: "m7", label: "minor seventh", intervals: [0, 3, 7, 10], optional: [7], extraWeight: 4),
        .init(suffix: "7", label: "dominant seventh", intervals: [0, 4, 7, 10], optional: [7], extraWeight: 4),
        .init(suffix: "6/9", label: "six nine", intervals: [0, 4, 7, 9, 2], optional: [7], extraWeight: 4),
        .init(suffix: "6", label: "major sixth", intervals: [0, 4, 7, 9], optional: [7], extraWeight: 3),
        .init(suffix: "m6", label: "minor sixth", intervals: [0, 3, 7, 9], optional: [7], extraWeight: 3),
        .init(suffix: "add9", label: "add nine", intervals: [0, 4, 7, 2], optional: [7], extraWeight: 3),
        .init(suffix: "madd9", label: "minor add nine", intervals: [0, 3, 7, 2], optional: [7], extraWeight: 3),
        .init(suffix: "sus2", label: "suspended two", intervals: [0, 2, 7], optional: [7], extraWeight: 2),
        .init(suffix: "sus4", label: "suspended four", intervals: [0, 5, 7], optional: [7], extraWeight: 2),
        .init(suffix: "aug", label: "augmented", intervals: [0, 4, 8], optional: [], extraWeight: 2),
        .init(suffix: "dim", label: "diminished", intervals: [0, 3, 6], optional: [], extraWeight: 2),
        .init(suffix: "m", label: "minor", intervals: [0, 3, 7], optional: [7], extraWeight: 2),
        .init(suffix: "", label: "major", intervals: [0, 4, 7], optional: [7], extraWeight: 2),
        .init(suffix: "5", label: "power chord", intervals: [0, 7], optional: [], extraWeight: 1),
    ]

    static func read(from state: FretboardState) -> ChordReading {
        let played = state.currentFrets()
        let capo = state.capoFret ?? 0
        if let named = GuitarShapes.match(frets: played, capo: capo) {
            return named
        }
        if let named = dTriangleFromFingers(state) {
            return named
        }
        let floor = played.compactMap { $0 }.min() ?? 0
        if floor > capo, let named = GuitarShapes.match(frets: played, capo: floor) {
            return named
        }

        let notes = state.soundingNotes()
        if notes.isEmpty {
            return ChordReading(
                symbol: "—",
                qualityName: "Mute every string, or place a finger",
                shape: "",
                notes: ""
            )
        }

        let pitchClasses = Set(notes.map(\.pitchClass))
        let bass = notes.map(\.midi).min().map { (( $0 % 12) + 12) % 12 }!
        if let named = openDFamily(pitchClasses, bass: bass) {
            var reading = named
            reading.shape = shapeLabel(state: state, quality: "")
            return reading
        }
        var reading = fromPitchClasses(pitchClasses, bass: bass, allowExtraNotes: false)
        let quality = reading.qualityName.contains("power") ? "5" : ""
        reading.shape = shapeLabel(state: state, quality: quality)
        return reading
    }

    /// Names a chord from pitch classes. `allowExtraNotes` is for messy microphone chroma.
    static func fromPitchClasses(
        _ pitchClasses: Set<Int>,
        bass: Int? = nil,
        allowExtraNotes: Bool = false
    ) -> ChordReading {
        let listedFallback = pitchClasses
            .sorted()
            .map { Tuning.noteName($0) }
            .joined(separator: " · ")

        if pitchClasses.isEmpty {
            return ChordReading(symbol: "—", qualityName: "", shape: "", notes: "")
        }

        let bassPC = bass.map { (($0 % 12) + 12) % 12 }
        var best: (score: Int, root: Int, formula: Formula)?

        for root in pitchClasses {
            let intervals = Set(pitchClasses.map { ($0 - root + 12) % 12 })
            for formula in formulas {
                let required = formula.intervals.subtracting(formula.optional)
                if !required.isSubset(of: intervals) { continue }
                let unexplained = intervals.subtracting(formula.intervals)
                if !unexplained.isEmpty, !allowExtraNotes { continue }
                let missingOptional = formula.optional.subtracting(intervals).count
                let matched = formula.intervals.intersection(intervals).count
                var score = matched * 10 + formula.extraWeight * 3 - missingOptional * 4 - unexplained.count * 6
                // Keep plain guitar triads ahead of 11 / 7♭9 labels that fit the same notes.
                if formula.suffix == "" || formula.suffix == "m" || formula.suffix == "add9" {
                    score += 16
                }
                if formula.suffix == "11" || formula.suffix == "13" || formula.suffix == "7♭9" || formula.suffix == "7♯9" {
                    score -= 10
                }
                if formula.suffix == "5", intervals == [0, 7] || intervals == [0, 7, 0] {
                    score += 8
                }
                if formula.suffix == "5", intervals.contains(4) || intervals.contains(3) {
                    continue
                }
                if best == nil || score > best!.score {
                    best = (score, root, formula)
                }
            }
        }

        guard let best else {
            let root = bassPC ?? pitchClasses.first!
            let flats = Tuning.preferFlats(forRoot: root)
            return ChordReading(
                symbol: "?",
                qualityName: "No standard chord match yet",
                shape: "",
                notes: pitchClasses.sorted().map { Tuning.noteName($0, flats: flats) }.joined(separator: " · ")
            )
        }

        let flats = Tuning.preferFlats(forRoot: best.root)
        var symbol = Tuning.noteName(best.root, flats: flats) + best.formula.suffix
        if let bassPC, bassPC != best.root {
            symbol += "/" + Tuning.noteName(bassPC, flats: flats)
        }

        let listed = pitchClasses.sorted().map { Tuning.noteName($0, flats: flats) }.joined(separator: " · ")
        return ChordReading(
            symbol: symbol,
            qualityName: Tuning.noteName(best.root, flats: flats) + " " + best.formula.label,
            shape: "",
            notes: listed.isEmpty ? listedFallback : listed
        )
    }

    private static func uniquePitchNames(notes: [SoundingNote], root: Int) -> String {
        let flats = Tuning.preferFlats(forRoot: root)
        var seen = Set<Int>()
        var names: [String] = []
        for note in notes {
            if seen.insert(note.pitchClass).inserted {
                names.append(Tuning.noteName(note.pitchClass, flats: flats))
            }
        }
        return names.joined(separator: " · ")
    }

    private static func shapeLabel(state: FretboardState, quality: String) -> String {
        var tags: [String] = []
        if quality == "5" { tags.append("Power chord") }
        if let capo = state.capoFret { tags.append("Capo \(capo)") }
        if state.fingers.contains(where: { $0.span >= 3 }) { tags.append("Barre") }
        let nut = state.capoFret ?? 0
        let hasOpen = state.soundingNotes().contains { $0.fret == nut }
        let maxFret = state.soundingNotes().map(\.fret).max() ?? 0
        if hasOpen, maxFret <= 4, !tags.contains("Barre") {
            tags.append("Open")
        } else if maxFret > 0, !tags.contains("Barre"), quality != "5" {
            tags.append("Fretted")
        }
        return tags.joined(separator: " · ")
    }

    /// Three adjacent fingers in a 2–3–2 or 3–2–3 cluster are the open D shape.
    private static func dTriangleFromFingers(_ state: FretboardState) -> ChordReading? {
        let planted = state.fingers
            .filter { $0.span == 1 }
            .sorted { $0.stringIndex < $1.stringIndex }
        guard planted.count >= 3 else { return nil }
        for i in 0 ... planted.count - 3 {
            let a = planted[i]
            let b = planted[i + 1]
            let c = planted[i + 2]
            guard b.stringIndex == a.stringIndex + 1, c.stringIndex == a.stringIndex + 2 else { continue }
            let textbook = a.fret == 2 && b.fret == 3 && c.fret == 2
            let inverted = a.fret == 3 && b.fret == 2 && c.fret == 3
            guard textbook || inverted else { continue }
            if textbook, a.stringIndex == 3, state.fingerFret(on: 0) == 2 {
                return ChordReading(
                    symbol: "D/F♯",
                    qualityName: "D major, F♯ in the bass",
                    shape: "Open",
                    notes: "D · F♯ · A"
                )
            }
            return ChordReading(
                symbol: "D",
                qualityName: "D major",
                shape: "Open",
                notes: "D · F♯ · A"
            )
        }
        return nil
    }

    /// D–F♯–A is open D. Ringing E/A must not become A7♭9/E.
    private static func openDFamily(_ pitchClasses: Set<Int>, bass: Int) -> ChordReading? {
        let d = 2, fSharp = 6, a = 9
        guard pitchClasses.isSuperset(of: [d, fSharp, a]) else { return nil }
        let symbol = bass == fSharp ? "D/F♯" : "D"
        let quality = bass == fSharp ? "D major, F♯ in the bass" : "D major"
        let flats = Tuning.preferFlats(forRoot: d)
        let listed = pitchClasses.sorted().map { Tuning.noteName($0, flats: flats) }.joined(separator: " · ")
        return ChordReading(symbol: symbol, qualityName: quality, shape: "Open", notes: listed)
    }
}
