//
//  NoGuessGenerator.swift
//  Minesweeper
//

import Foundation

enum NoGuessGenerator {

    static func minOpening(rows: Int, cols: Int) -> Int {
        if rows == 8 && cols == 8 { return 10 }
        if rows == 16 && cols == 16 { return 25 }
        if rows == 16 && cols == 30 { return 25 }
        return max(5, rows * cols / 20)
    }

    static func maxAttempts(rows: Int, cols: Int) -> Int {
        if rows == 16 && cols == 30 { return 20000 }
        if rows == 16 && cols == 16 { return 10000 }
        return 5000
    }

    static func generate(
        rows: Int,
        cols: Int,
        mines: Int,
        firstClick: (Int, Int),
        minOpening: Int? = nil,
        maxAttempts: Int? = nil
    ) -> [(Int, Int)]? {
        let opening = minOpening ?? self.minOpening(rows: rows, cols: cols)
        let attempts = maxAttempts ?? self.maxAttempts(rows: rows, cols: cols)
        let safeZone = Set(safeZoneCoords(around: firstClick, rows: rows, cols: cols))

        var candidates = [(Int, Int)]()
        for r in 0..<rows {
            for c in 0..<cols {
                if !safeZone.contains(Coord(r: r, c: c)) {
                    candidates.append((r, c))
                }
            }
        }

        guard candidates.count >= mines else { return nil }

        let firstClickCoord = Coord(r: firstClick.0, c: firstClick.1)

        for _ in 0..<attempts {
            candidates.shuffle()
            let mineCoords = Set(candidates.prefix(mines).map { Coord(r: $0.0, c: $0.1) })
            let numbers = computeNumbers(mines: mineCoords, rows: rows, cols: cols)

            let openingSize = simulateOpeningSize(
                from: firstClickCoord, numbers: numbers, rows: rows, cols: cols)
            if openingSize < opening { continue }

            if isSolvableWithoutGuessing(
                mines: mineCoords,
                numbers: numbers,
                rows: rows,
                cols: cols,
                firstClick: firstClickCoord,
                totalMines: mines
            ) {
                return mineCoords.map { ($0.r, $0.c) }
            }
        }

        return nil
    }

    private static func safeZoneCoords(around: (Int, Int), rows: Int, cols: Int) -> [Coord] {
        var result = [Coord]()
        for dr in -1...1 {
            for dc in -1...1 {
                let r = around.0 + dr
                let c = around.1 + dc
                if r >= 0 && r < rows && c >= 0 && c < cols {
                    result.append(Coord(r: r, c: c))
                }
            }
        }
        return result
    }

    private static func computeNumbers(mines: Set<Coord>, rows: Int, cols: Int) -> [[Int]] {
        var numbers = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                if mines.contains(Coord(r: r, c: c)) { continue }
                numbers[r][c] = adjacent(r: r, c: c, rows: rows, cols: cols)
                    .filter { mines.contains($0) }.count
            }
        }
        return numbers
    }

    private static func simulateOpeningSize(
        from: Coord, numbers: [[Int]], rows: Int, cols: Int
    ) -> Int {
        var revealed = Set<Coord>()
        floodFillReveal(from: from, numbers: numbers, revealed: &revealed, rows: rows, cols: cols)
        return revealed.count
    }

    private static func floodFillReveal(
        from: Coord, numbers: [[Int]], revealed: inout Set<Coord>, rows: Int, cols: Int
    ) {
        if revealed.contains(from) { return }
        revealed.insert(from)

        for neighbor in adjacent(r: from.r, c: from.c, rows: rows, cols: cols) {
            if revealed.contains(neighbor) { continue }
            let value = numbers[neighbor.r][neighbor.c]
            if value == 0 {
                floodFillReveal(
                    from: neighbor, numbers: numbers, revealed: &revealed, rows: rows, cols: cols)
            } else if value > 0 {
                revealed.insert(neighbor)
            }
        }
    }

    private static func isSolvableWithoutGuessing(
        mines: Set<Coord>,
        numbers: [[Int]],
        rows: Int,
        cols: Int,
        firstClick: Coord,
        totalMines: Int
    ) -> Bool {
        var revealed = Set<Coord>()
        var flagged = Set<Coord>()

        floodFillReveal(
            from: firstClick, numbers: numbers, revealed: &revealed, rows: rows, cols: cols)

        while true {
            let (safe, mineDeductions) = deterministicDeduction(
                revealed: revealed,
                flagged: flagged,
                numbers: numbers,
                rows: rows,
                cols: cols
            )

            if safe.isEmpty && mineDeductions.isEmpty {
                let safeCellCount = rows * cols - totalMines
                return revealed.count == safeCellCount
            }

            for coord in mineDeductions {
                if !mines.contains(coord) { return false }
                flagged.insert(coord)
            }

            for coord in safe {
                if mines.contains(coord) { return false }
                revealed.insert(coord)
                if numbers[coord.r][coord.c] == 0 {
                    floodFillReveal(
                        from: coord, numbers: numbers, revealed: &revealed, rows: rows, cols: cols)
                }
            }
        }
    }

    private static func deterministicDeduction(
        revealed: Set<Coord>,
        flagged: Set<Coord>,
        numbers: [[Int]],
        rows: Int,
        cols: Int
    ) -> (safe: Set<Coord>, mines: Set<Coord>) {
        var safe = Set<Coord>()
        var mines = Set<Coord>()
        var changed = true

        while changed {
            changed = false
            for r in 0..<rows {
                for c in 0..<cols {
                    let coord = Coord(r: r, c: c)
                    guard revealed.contains(coord) else { continue }

                    let number = numbers[r][c]
                    guard number > 0 else { continue }

                    let neighbors = adjacent(r: r, c: c, rows: rows, cols: cols)
                    let flaggedCount = neighbors.filter { flagged.contains($0) }.count
                    let unknown = neighbors.filter { !revealed.contains($0) && !flagged.contains($0) }
                    let minesNeeded = number - flaggedCount

                    if minesNeeded == 0 {
                        for unknownCoord in unknown where !safe.contains(unknownCoord) {
                            safe.insert(unknownCoord)
                            changed = true
                        }
                    } else if minesNeeded == unknown.count && minesNeeded > 0 {
                        for unknownCoord in unknown where !mines.contains(unknownCoord) {
                            mines.insert(unknownCoord)
                            changed = true
                        }
                    }
                }
            }
        }

        return (safe, mines)
    }

    private static func adjacent(r: Int, c: Int, rows: Int, cols: Int) -> [Coord] {
        var result = [Coord]()
        for dr in -1...1 {
            for dc in -1...1 where dr != 0 || dc != 0 {
                let nr = r + dr
                let nc = c + dc
                if nr >= 0 && nr < rows && nc >= 0 && nc < cols {
                    result.append(Coord(r: nr, c: nc))
                }
            }
        }
        return result
    }
}
