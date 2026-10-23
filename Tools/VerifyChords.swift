import Foundation

@main
struct VerifyChords {
    static func main() {
        var failed = 0

        func check(_ name: String, frets: [Int?], expectPrefix: String) {
            let board = FretboardState()
            board.apply(frets: frets)
            let symbol = ChordDetector.read(from: board).symbol
            let ok = symbol == expectPrefix || symbol.hasPrefix(expectPrefix)
            if ok {
                print("OK  \(name) → \(symbol)")
            } else {
                print("FAIL \(name) → \(symbol) (wanted \(expectPrefix))")
                failed += 1
            }
        }

        // Open D: X X 0 2 3 2
        check("Open D", frets: [nil, nil, 0, 2, 3, 2], expectPrefix: "D")
        // Learner D with unused bass still ringing
        check("Open D ringing bass", frets: [0, 0, 0, 2, 3, 2], expectPrefix: "D")
        // Open G: 3 2 0 0 0 3
        check("Open G", frets: [3, 2, 0, 0, 0, 3], expectPrefix: "G")
        // Open C: X 3 2 0 1 0
        check("Open C", frets: [nil, 3, 2, 0, 1, 0], expectPrefix: "C")
        // Open Em: 0 2 2 0 0 0
        check("Open Em", frets: [0, 2, 2, 0, 0, 0], expectPrefix: "Em")
        // Open Am: X 0 2 2 1 0
        check("Open Am", frets: [nil, 0, 2, 2, 1, 0], expectPrefix: "Am")
        // Open E: 0 2 2 1 0 0
        check("Open E", frets: [0, 2, 2, 1, 0, 0], expectPrefix: "E")
        // Open A: X 0 2 2 2 0
        check("Open A", frets: [nil, 0, 2, 2, 2, 0], expectPrefix: "A")
        // Power A: X 0 2 2 X X
        check("A5 power", frets: [nil, 0, 2, 2, nil, nil], expectPrefix: "A5")
        // Power E: 0 2 2 X X X
        check("E5 power", frets: [0, 2, 2, nil, nil, nil], expectPrefix: "E5")
        // Barre F: 1 3 3 2 1 1
        check("Barre F", frets: [1, 3, 3, 2, 1, 1], expectPrefix: "F")
        // Barre Bm: X 2 4 4 3 2
        check("Barre Bm", frets: [nil, 2, 4, 4, 3, 2], expectPrefix: "Bm")
        // D/F# (F# in bass)
        check("D/F#", frets: [2, nil, 0, 2, 3, 2], expectPrefix: "D/F♯")

        if failed > 0 {
            fputs("\(failed) check(s) failed\n", stderr)
            exit(1)
        }
        print("All chord checks passed")
    }
}
