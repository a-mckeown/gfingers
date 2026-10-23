import Foundation

/// Textbook guitar voicings. Matched before interval analysis so an open D
/// still reads as D even if the unused bass strings are left ringing.
enum GuitarShapes {
    struct Shape {
        let symbol: String
        let qualityName: String
        let kind: String
        /// Six strings, low E → high e. `nil` is muted in the textbook diagram.
        let frets: [Int?]
    }

    static let catalog: [Shape] = [
        .init(symbol: "D", qualityName: "D major", kind: "Open", frets: [nil, nil, 0, 2, 3, 2]),
        .init(symbol: "Dm", qualityName: "D minor", kind: "Open", frets: [nil, nil, 0, 2, 3, 1]),
        .init(symbol: "D7", qualityName: "D dominant seventh", kind: "Open", frets: [nil, nil, 0, 2, 1, 2]),
        .init(symbol: "D/F♯", qualityName: "D major, F♯ in the bass", kind: "Open", frets: [2, nil, 0, 2, 3, 2]),
        .init(symbol: "G", qualityName: "G major", kind: "Open", frets: [3, 2, 0, 0, 0, 3]),
        .init(symbol: "G", qualityName: "G major", kind: "Open", frets: [3, 2, 0, 0, 3, 3]),
        .init(symbol: "C", qualityName: "C major", kind: "Open", frets: [nil, 3, 2, 0, 1, 0]),
        .init(symbol: "E", qualityName: "E major", kind: "Open", frets: [0, 2, 2, 1, 0, 0]),
        .init(symbol: "Em", qualityName: "E minor", kind: "Open", frets: [0, 2, 2, 0, 0, 0]),
        .init(symbol: "E7", qualityName: "E dominant seventh", kind: "Open", frets: [0, 2, 0, 1, 0, 0]),
        .init(symbol: "A", qualityName: "A major", kind: "Open", frets: [nil, 0, 2, 2, 2, 0]),
        .init(symbol: "Am", qualityName: "A minor", kind: "Open", frets: [nil, 0, 2, 2, 1, 0]),
        .init(symbol: "A7", qualityName: "A dominant seventh", kind: "Open", frets: [nil, 0, 2, 0, 2, 0]),
        .init(symbol: "F", qualityName: "F major", kind: "Barre", frets: [1, 3, 3, 2, 1, 1]),
        .init(symbol: "Fm", qualityName: "F minor", kind: "Barre", frets: [1, 3, 3, 1, 1, 1]),
        .init(symbol: "Bm", qualityName: "B minor", kind: "Barre", frets: [nil, 2, 4, 4, 3, 2]),
        .init(symbol: "B7", qualityName: "B dominant seventh", kind: "Open", frets: [nil, 2, 1, 2, 0, 2]),
        .init(symbol: "A5", qualityName: "A power chord", kind: "Power chord", frets: [nil, 0, 2, 2, nil, nil]),
        .init(symbol: "E5", qualityName: "E power chord", kind: "Power chord", frets: [0, 2, 2, nil, nil, nil]),
        .init(symbol: "D5", qualityName: "D power chord", kind: "Power chord", frets: [nil, nil, 0, 2, 3, nil]),
        .init(symbol: "G5", qualityName: "G power chord", kind: "Power chord", frets: [3, 5, 5, nil, nil, nil]),
    ]

    static func match(frets played: [Int?]) -> ChordReading? {
        for shape in catalog {
            if matches(shape, played: played) {
                return ChordReading(
                    symbol: shape.symbol,
                    qualityName: shape.qualityName,
                    shape: shape.kind,
                    notes: notesLabel(frets: played)
                )
            }
        }
        return nil
    }

    /// Textbook mutes (`nil`) may still be ringing open; other strings must match.
    private static func matches(_ shape: Shape, played: [Int?]) -> Bool {
        zip(shape.frets, played).allSatisfy { wanted, got in
            if let wanted {
                return got == wanted
            }
            // Unused in the diagram: muted is ideal; open is the usual learner miss.
            return got == nil || got == 0
        }
    }

    private static func notesLabel(frets: [Int?]) -> String {
        var seen = Set<Int>()
        var names: [String] = []
        for (string, fret) in frets.enumerated() {
            guard let fret else { continue }
            let pc = (Tuning.openMidi[string] + fret) % 12
            if seen.insert(pc).inserted {
                names.append(Tuning.noteName(pc))
            }
        }
        return names.joined(separator: " · ")
    }
}
