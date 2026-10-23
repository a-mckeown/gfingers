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
        // Leftover finger on the D string must not become A7♭9/E
        check("Open D with D-string 2", frets: [0, 0, 2, 2, 3, 2], expectPrefix: "D")
        check("Open D muted D string", frets: [0, 0, nil, 2, 3, 2], expectPrefix: "D")
        // 2–3–2 triangle one string too low (D–G–B) still reads as D
        check("D triangle on D-G-B", frets: [0, 0, 2, 3, 2, 0], expectPrefix: "D")
        check("D triangle on E-A-D", frets: [2, 3, 2, 0, 0, 0], expectPrefix: "D")
        check("D triangle pointing at nut", frets: [0, 0, 0, 3, 2, 3], expectPrefix: "D")
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

        let barreBoard = FretboardState()
        barreBoard.barreMode = true
        barreBoard.tap(string: 0, fret: 1)
        if barreBoard.barreMode {
            print("FAIL F via taps → barre mode stayed on")
            failed += 1
        } else {
            barreBoard.tap(string: 1, fret: 3)
            barreBoard.tap(string: 2, fret: 3)
            barreBoard.tap(string: 3, fret: 2)
            let symbol = ChordDetector.read(from: barreBoard).symbol
            if symbol == "F" || symbol.hasPrefix("F") {
                print("OK  F via barre then fingers → \(symbol)")
            } else {
                print("FAIL F via barre then fingers → \(symbol) (wanted F)")
                failed += 1
            }
        }
        // Barre Bm: X 2 4 4 3 2
        check("Barre Bm", frets: [nil, 2, 4, 4, 3, 2], expectPrefix: "Bm")
        // D/F# (F# in bass)
        check("D/F#", frets: [2, nil, 0, 2, 3, 2], expectPrefix: "D/F♯")

        let capoBoard = FretboardState()
        capoBoard.capoMode = true
        capoBoard.tap(string: 0, fret: 2)
        capoBoard.toggleMute(string: 0)
        capoBoard.toggleMute(string: 1)
        capoBoard.tap(string: 3, fret: 4)
        capoBoard.tap(string: 4, fret: 5)
        capoBoard.tap(string: 5, fret: 4)
        let capoSymbol = ChordDetector.read(from: capoBoard).symbol
        if capoSymbol == "E" || capoSymbol.hasPrefix("E") {
            print("OK  D shape at capo 2 → \(capoSymbol)")
        } else {
            print("FAIL D shape at capo 2 → \(capoSymbol) (wanted E)")
            failed += 1
        }

        let capoE = FretboardState()
        capoE.capoMode = true
        capoE.tap(string: 0, fret: 1)
        capoE.tap(string: 1, fret: 3)
        capoE.tap(string: 2, fret: 3)
        capoE.tap(string: 3, fret: 2)
        let capoESymbol = ChordDetector.read(from: capoE).symbol
        if capoESymbol == "F" || capoESymbol.hasPrefix("F") {
            print("OK  E shape at capo 1 → \(capoESymbol)")
        } else {
            print("FAIL E shape at capo 1 → \(capoESymbol) (wanted F)")
            failed += 1
        }

        let slide = FretboardState()
        slide.apply(frets: [nil, nil, 0, 2, 3, 2])
        slide.beginShapeDrag()
        slide.dragShape(by: 2)
        let slid = ChordDetector.read(from: slide).symbol
        if slid == "E" || slid.hasPrefix("E") {
            print("OK  D shape slid +2 → \(slid)")
        } else {
            print("FAIL D shape slid +2 → \(slid) (wanted E)")
            failed += 1
        }
        slide.endShapeDrag()

        let slideF = FretboardState()
        slideF.apply(frets: [1, 3, 3, 2, 1, 1])
        slideF.beginShapeDrag()
        slideF.dragShape(by: 2)
        let slidF = ChordDetector.read(from: slideF).symbol
        if slidF == "G" || slidF.hasPrefix("G") {
            print("OK  F barre slid +2 → \(slidF)")
        } else {
            print("FAIL F barre slid +2 → \(slidF) (wanted G)")
            failed += 1
        }
        slideF.endShapeDrag()

        if failed > 0 {
            fputs("\(failed) check(s) failed\n", stderr)
            exit(1)
        }
        print("All chord checks passed")
    }
}
