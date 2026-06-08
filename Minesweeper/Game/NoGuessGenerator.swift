//
//  NoGuessGenerator.swift
//  Minesweeper
//

import Foundation

/// Generates mine layouts that are guaranteed solvable without guessing.
///
/// Boards are produced by repeatedly placing mines at random and running a
/// deterministic logic solver until one is fully solvable. The solver works on
/// flat integer arrays (cells indexed as `r * cols + c`) with precomputed
/// neighbor lists, and applies both single-cell count deduction and
/// subset / constraint-subtraction deduction so that the vast majority of
/// human-solvable boards are accepted — keeping the number of attempts low.
enum NoGuessGenerator {

    static func minOpening(rows: Int, cols: Int) -> Int {
        if rows == 8 && cols == 8 { return 10 }
        if rows == 16 && cols == 16 { return 25 }
        if rows == 16 && cols == 30 { return 25 }
        return max(5, rows * cols / 20)
    }

    static func maxAttempts(rows: Int, cols: Int) -> Int {
        if rows == 16 && cols == 30 { return 3000 }
        if rows == 16 && cols == 16 { return 2000 }
        // Custom boards: scale with area so large/dense layouts get enough tries
        // (each attempt costs well under a millisecond), bounded to keep the
        // worst case — a board with no no-guess solution — responsive.
        return min(6000, max(2000, rows * cols * 5))
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
        let n = rows * cols
        let start = firstClick.0 * cols + firstClick.1

        // Precompute neighbor indices once — these never change across attempts.
        let neighbors = buildNeighbors(rows: rows, cols: cols)

        // Cells eligible to hold a mine: everything outside the 3x3 first-click zone.
        var inSafeZone = [Bool](repeating: false, count: n)
        for nb in neighbors[start] { inSafeZone[nb] = true }
        inSafeZone[start] = true

        var candidates = [Int]()
        candidates.reserveCapacity(n)
        for i in 0..<n where !inSafeZone[i] {
            candidates.append(i)
        }
        guard candidates.count >= mines else { return nil }

        let safeTargetCount = n - mines

        // Scratch buffers reused across attempts to avoid per-attempt allocation.
        var mine = [Bool](repeating: false, count: n)
        var number = [Int](repeating: 0, count: n)

        for _ in 0..<attempts {
            candidates.shuffle()

            for i in 0..<n { mine[i] = false }
            for k in 0..<mines { mine[candidates[k]] = true }

            computeNumbers(mine: mine, neighbors: neighbors, n: n, number: &number)

            if solveAttempt(
                number: number,
                neighbors: neighbors,
                n: n,
                start: start,
                minOpening: opening,
                safeTargetCount: safeTargetCount
            ) {
                return (0..<n).filter { mine[$0] }.map { ($0 / cols, $0 % cols) }
            }
        }

        return nil
    }

    // MARK: - Setup

    private static func buildNeighbors(rows: Int, cols: Int) -> [[Int]] {
        var neighbors = [[Int]](repeating: [], count: rows * cols)
        for r in 0..<rows {
            for c in 0..<cols {
                var list = [Int]()
                for dr in -1...1 {
                    for dc in -1...1 where dr != 0 || dc != 0 {
                        let nr = r + dr
                        let nc = c + dc
                        if nr >= 0 && nr < rows && nc >= 0 && nc < cols {
                            list.append(nr * cols + nc)
                        }
                    }
                }
                neighbors[r * cols + c] = list
            }
        }
        return neighbors
    }

    private static func computeNumbers(
        mine: [Bool], neighbors: [[Int]], n: Int, number: inout [Int]
    ) {
        for i in 0..<n {
            if mine[i] {
                number[i] = 0
                continue
            }
            var count = 0
            for nb in neighbors[i] where mine[nb] { count += 1 }
            number[i] = count
        }
    }

    // MARK: - Solver

    /// Returns true if the board is fully solvable starting from `start` using only
    /// deterministic logic (no guessing), and the initial opening is large enough.
    ///
    /// Deduction is sound, so any cell it reveals is genuinely safe and any cell it
    /// flags is genuinely a mine — the actual mine array is not needed here.
    private static func solveAttempt(
        number: [Int],
        neighbors: [[Int]],
        n: Int,
        start: Int,
        minOpening: Int,
        safeTargetCount: Int
    ) -> Bool {
        var revealed = [Bool](repeating: false, count: n)
        var flagged = [Bool](repeating: false, count: n)
        var revealedCount = 0

        // Work queue of revealed numbered cells whose neighborhood may have changed.
        var queue = [Int]()
        var inQueue = [Bool](repeating: false, count: n)

        func enqueue(_ i: Int) {
            if number[i] > 0 && !inQueue[i] {
                inQueue[i] = true
                queue.append(i)
            }
        }

        // Reveal a safe cell, cascading through zero cells like a real opening.
        func reveal(_ start: Int) {
            if revealed[start] || flagged[start] { return }
            var stack = [start]
            while let cur = stack.popLast() {
                if revealed[cur] { continue }
                revealed[cur] = true
                revealedCount += 1
                if number[cur] == 0 {
                    for nb in neighbors[cur] where !revealed[nb] && !flagged[nb] {
                        stack.append(nb)
                    }
                } else {
                    enqueue(cur)
                }
                for nb in neighbors[cur] where revealed[nb] && number[nb] > 0 {
                    enqueue(nb)
                }
            }
        }

        func flag(_ i: Int) {
            if flagged[i] || revealed[i] { return }
            flagged[i] = true
            for nb in neighbors[i] where revealed[nb] && number[nb] > 0 {
                enqueue(nb)
            }
        }

        reveal(start)
        if revealedCount < minOpening { return false }

        while true {
            // ---- Basic single-cell deduction, drained via the work queue ----
            var qi = 0
            while qi < queue.count {
                let ci = queue[qi]
                qi += 1
                inQueue[ci] = false

                var flaggedCount = 0
                var unknown = [Int]()
                for nb in neighbors[ci] {
                    if flagged[nb] {
                        flaggedCount += 1
                    } else if !revealed[nb] {
                        unknown.append(nb)
                    }
                }
                if unknown.isEmpty { continue }

                let need = number[ci] - flaggedCount
                if need == 0 {
                    for u in unknown { reveal(u) }
                } else if need == unknown.count {
                    for u in unknown { flag(u) }
                }
            }
            queue.removeAll(keepingCapacity: true)

            if revealedCount == safeTargetCount { return true }

            // ---- Subset / constraint-subtraction deduction (basic stalled) ----
            if subsetDeduction(
                number: number,
                neighbors: neighbors,
                n: n,
                revealed: revealed,
                flagged: flagged,
                reveal: reveal,
                flag: flag
            ) {
                continue  // produced progress; re-run basic deduction
            }

            // No deduction possible: solvable only if everything safe is revealed.
            return revealedCount == safeTargetCount
        }
    }

    /// One pass of subset deduction over the active frontier constraints.
    /// Returns true if it revealed or flagged at least one cell.
    private static func subsetDeduction(
        number: [Int],
        neighbors: [[Int]],
        n: Int,
        revealed: [Bool],
        flagged: [Bool],
        reveal: (Int) -> Void,
        flag: (Int) -> Void
    ) -> Bool {
        // Build active constraints: each revealed number with remaining unknown cells.
        var cells = [[Int]]()  // sorted unknown-cell indices per constraint
        var minesLeft = [Int]()
        for i in 0..<n where revealed[i] && number[i] > 0 {
            var flaggedCount = 0
            var unknown = [Int]()
            for nb in neighbors[i] {
                if flagged[nb] {
                    flaggedCount += 1
                } else if !revealed[nb] {
                    unknown.append(nb)
                }
            }
            if unknown.isEmpty { continue }
            cells.append(unknown.sorted())
            minesLeft.append(number[i] - flaggedCount)
        }

        let count = cells.count
        var progressed = false

        for a in 0..<count {
            for b in 0..<count where b != a {
                // Require cells[a] ⊆ cells[b]; both arrays are sorted ascending.
                if cells[a].count >= cells[b].count { continue }
                guard let diff = subsetDifference(sub: cells[a], sup: cells[b]) else {
                    continue
                }
                let dm = minesLeft[b] - minesLeft[a]
                if dm == 0 {
                    for cell in diff { reveal(cell) }
                    progressed = true
                } else if dm == diff.count {
                    for cell in diff { flag(cell) }
                    progressed = true
                }
            }
            if progressed { break }  // re-derive constraints after any change
        }

        return progressed
    }

    /// If `sub` is a subset of `sup` (both sorted ascending), returns `sup \ sub`.
    /// Returns nil if `sub` is not a subset.
    private static func subsetDifference(sub: [Int], sup: [Int]) -> [Int]? {
        var i = 0
        var diff = [Int]()
        for value in sup {
            if i < sub.count && sub[i] == value {
                i += 1
            } else {
                diff.append(value)
            }
        }
        return i == sub.count ? diff : nil
    }
}
