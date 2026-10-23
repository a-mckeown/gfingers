import Foundation
import Observation

struct Finger: Identifiable, Equatable, Hashable {
    var id = UUID()
    /// 0 = low E … 5 = high E
    var stringIndex: Int
    var fret: Int
    /// How many strings this finger covers toward high E (1 = single note).
    var span: Int = 1

    func covers(string: Int) -> Bool {
        string >= stringIndex && string < stringIndex + span
    }
}

struct SoundingNote: Equatable {
    var stringIndex: Int
    var fret: Int
    var midi: Int
    var pitchClass: Int { ((midi % 12) + 12) % 12 }
}

@Observable
final class FretboardState {
    var muted = Array(repeating: false, count: Tuning.stringCount)
    var fingers: [Finger] = []
    var barreMode = false
    var statusMessage: String?

    func covers(string: Int) -> Int? {
        fingers
            .filter { $0.covers(string: string) }
            .map(\.fret)
            .max()
    }

    func soundingNotes() -> [SoundingNote] {
        (0 ..< Tuning.stringCount).compactMap { string in
            if muted[string] { return nil }
            let fret = covers(string: string) ?? 0
            let midi = Tuning.openMidi[string] + fret
            return SoundingNote(stringIndex: string, fret: fret, midi: midi)
        }
    }

    func fingerNumber(for finger: Finger) -> Int {
        let ordered = fingers.sorted { lhs, rhs in
            if lhs.fret != rhs.fret { return lhs.fret < rhs.fret }
            return lhs.stringIndex < rhs.stringIndex
        }
        return (ordered.firstIndex(of: finger) ?? 0) + 1
    }

    func toggleMute(string: Int) {
        muted[string].toggle()
        statusMessage = nil
    }

    func tap(string: Int, fret: Int) {
        statusMessage = nil
        if barreMode {
            placeBarre(from: string, fret: fret)
            return
        }

        if let existing = fingers.firstIndex(where: { $0.span == 1 && $0.stringIndex == string && $0.fret == fret }) {
            fingers.remove(at: existing)
            return
        }

        if let sameString = fingers.firstIndex(where: { $0.span == 1 && $0.stringIndex == string }) {
            fingers[sameString].fret = fret
            muted[string] = false
            return
        }

        if fingers.count >= Tuning.maxFingers {
            statusMessage = "Four fingers max — lift one, or use Barre for one finger across strings."
            return
        }

        fingers.append(Finger(stringIndex: string, fret: fret, span: 1))
        muted[string] = false
    }

    private func placeBarre(from string: Int, fret: Int) {
        let span = Tuning.stringCount - string
        if let existing = fingers.firstIndex(where: { $0.fret == fret && $0.stringIndex == string && $0.span == span }) {
            fingers.remove(at: existing)
            return
        }

        fingers.removeAll { $0.fret == fret && $0.span > 1 }
        fingers.removeAll { $0.span == 1 && $0.fret == fret && $0.stringIndex >= string }

        if fingers.count >= Tuning.maxFingers {
            statusMessage = "Four fingers max — lift one to add a barre."
            return
        }

        fingers.append(Finger(stringIndex: string, fret: fret, span: span))
        for s in string ..< Tuning.stringCount {
            muted[s] = false
        }
    }

    func clear() {
        fingers = []
        muted = Array(repeating: false, count: Tuning.stringCount)
        statusMessage = nil
    }

    /// `nil` mutes the string, `0` is open, a positive number is a fretted finger.
    func apply(frets: [Int?]) {
        precondition(frets.count == Tuning.stringCount)
        muted = frets.map { $0 == nil }
        fingers = frets.enumerated().compactMap { index, fret in
            guard let fret, fret > 0 else { return nil }
            return Finger(stringIndex: index, fret: fret, span: 1)
        }
        statusMessage = nil
    }
}
