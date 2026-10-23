import Foundation
import Combine

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

final class FretboardState: ObservableObject {
    @Published var muted = Array(repeating: false, count: Tuning.stringCount)
    @Published var fingers: [Finger] = []
    @Published var barreMode = false
    @Published var capoMode = false
    /// Capo fret, or `nil` when off. Counts as the new nut for sounding notes.
    @Published var capoFret: Int?
    @Published var statusMessage: String?

    func fingerFret(on string: Int) -> Int? {
        fingers
            .filter { $0.covers(string: string) }
            .map(\.fret)
            .max()
    }

    func covers(string: Int) -> Int? {
        let stopped = fingerFret(on: string)
        if let capo = capoFret {
            if let stopped { return max(capo, stopped) }
            return capo
        }
        return stopped
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
        if capoMode {
            placeCapo(at: fret)
            return
        }
        if barreMode {
            if let capo = capoFret, fret <= capo {
                statusMessage = "That fret is behind the capo."
                return
            }
            placeBarre(from: string, fret: fret)
            return
        }

        if let capo = capoFret, fret <= capo {
            statusMessage = "That fret is behind the capo — play above it, or move the capo."
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
        // Next taps plant extra fingers (E-shaped F, etc.), not another barre.
        barreMode = false
    }

    private func placeCapo(at fret: Int) {
        if capoFret == fret {
            capoFret = nil
            capoMode = false
            return
        }
        capoFret = fret
        fingers.removeAll { $0.fret <= fret }
        capoMode = false
        barreMode = false
    }

    func clear() {
        fingers = []
        muted = Array(repeating: false, count: Tuning.stringCount)
        capoFret = nil
        capoMode = false
        barreMode = false
        statusMessage = nil
    }

    /// `nil` = muted, `0` = open, `>0` = fretted.
    func currentFrets() -> [Int?] {
        (0 ..< Tuning.stringCount).map { string in
            if muted[string] { return nil }
            return covers(string: string) ?? 0
        }
    }

    /// `nil` mutes the string, `0` is open, a positive number is a fretted finger.
    func apply(frets: [Int?]) {
        precondition(frets.count == Tuning.stringCount)
        muted = frets.map { $0 == nil }
        fingers = frets.enumerated().compactMap { index, fret in
            guard let fret, fret > 0 else { return nil }
            return Finger(stringIndex: index, fret: fret, span: 1)
        }
        capoFret = nil
        capoMode = false
        barreMode = false
        statusMessage = nil
    }
}
