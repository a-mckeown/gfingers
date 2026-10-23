import Foundation

enum Tuning {
    static let stringCount = 6
    static let fretCount = 24
    static let maxFingers = 4

    /// Low E → high E, MIDI note numbers for open strings.
    static let openMidi = [40, 45, 50, 55, 59, 64]
    static let stringNames = ["E", "A", "D", "G", "B", "e"]

    static let noteNamesSharp = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    static let noteNamesFlat = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]

    static func preferFlats(forRoot root: Int) -> Bool {
        [1, 3, 6, 8, 10].contains(root)
    }

    static func noteName(_ pitchClass: Int, flats: Bool? = nil) -> String {
        let pc = ((pitchClass % 12) + 12) % 12
        let useFlats = flats ?? preferFlats(forRoot: pc)
        return useFlats ? noteNamesFlat[pc] : noteNamesSharp[pc]
    }
}
