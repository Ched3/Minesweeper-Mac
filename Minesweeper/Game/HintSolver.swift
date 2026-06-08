//
//  HintSolver.swift
//  Minesweeper
//

import Foundation

enum HintResult {
    case deterministic(safe: Set<Coord>, mines: Set<Coord>)
    case probabilities([Coord: Double])
}

enum HintSolver {

    private static let maxEnumerationCells = 20

    static func solve(grid: [[SolverCell]], rows: Int, cols: Int, totalMines: Int, flagCount: Int)
        -> HintResult
    {
        let (safe, mines) = deterministicDeduction(grid: grid, rows: rows, cols: cols)
        if !safe.isEmpty || !mines.isEmpty {
            return .deterministic(safe: safe, mines: mines)
        }
        let probs = computeProbabilities(
            grid: grid, rows: rows, cols: cols, totalMines: totalMines, flagCount: flagCount)
        return .probabilities(probs)
    }

    private static func deterministicDeduction(
        grid: [[SolverCell]], rows: Int, cols: Int
    ) -> (safe: Set<Coord>, mines: Set<Coord>) {
        var safe = Set<Coord>()
        var mines = Set<Coord>()
        var changed = true

        while changed {
            changed = false
            for r in 0..<rows {
                for c in 0..<cols {
                    guard let number = grid[r][c].revealedNumber, number > 0 else { continue }

                    let neighbors = adjacent(r: r, c: c, rows: rows, cols: cols)
                    let flaggedCount = neighbors.filter { grid[$0.r][$0.c].isFlagged }.count
                    let unknown = neighbors.filter {
                        let cell = grid[$0.r][$0.c]
                        return !cell.isRevealed && !cell.isFlagged
                    }
                    let minesNeeded = number - flaggedCount

                    if minesNeeded == 0 {
                        for coord in unknown where !safe.contains(coord) {
                            safe.insert(coord)
                            changed = true
                        }
                    } else if minesNeeded == unknown.count && minesNeeded > 0 {
                        for coord in unknown where !mines.contains(coord) {
                            mines.insert(coord)
                            changed = true
                        }
                    }
                }
            }
        }

        return (safe, mines)
    }

    private static func computeProbabilities(
        grid: [[SolverCell]], rows: Int, cols: Int, totalMines: Int, flagCount: Int
    ) -> [Coord: Double] {
        var unknown = [Coord]()
        for r in 0..<rows {
            for c in 0..<cols {
                let cell = grid[r][c]
                if !cell.isRevealed && !cell.isFlagged {
                    unknown.append(Coord(r: r, c: c))
                }
            }
        }

        guard !unknown.isEmpty else { return [:] }

        let remainingMines = max(0, totalMines - flagCount)

        if unknown.count <= maxEnumerationCells {
            return enumerateProbabilities(
                grid: grid, rows: rows, cols: cols, unknown: unknown, remainingMines: remainingMines)
        }

        return localAverageProbabilities(
            grid: grid, rows: rows, cols: cols, unknown: unknown, remainingMines: remainingMines)
    }

    private static func enumerateProbabilities(
        grid: [[SolverCell]], rows: Int, cols: Int, unknown: [Coord], remainingMines: Int
    ) -> [Coord: Double] {
        let n = unknown.count
        var mineCounts = [Coord: Int]()
        for coord in unknown {
            mineCounts[coord] = 0
        }
        var validConfigs = 0

        let total = 1 << n
        for mask in 0..<total {
            var assignment = [Coord: Bool]()
            var mineTotal = 0
            for (i, coord) in unknown.enumerated() {
                let isMine = (mask >> i) & 1 == 1
                assignment[coord] = isMine
                if isMine { mineTotal += 1 }
            }

            if mineTotal != remainingMines { continue }
            if !satisfiesConstraints(grid: grid, rows: rows, cols: cols, assignment: assignment) {
                continue
            }

            validConfigs += 1
            for coord in unknown where assignment[coord] == true {
                mineCounts[coord, default: 0] += 1
            }
        }

        if validConfigs == 0 {
            return uniformProbabilities(unknown: unknown, remainingMines: remainingMines)
        }

        var result = [Coord: Double]()
        for coord in unknown {
            result[coord] = Double(mineCounts[coord] ?? 0) / Double(validConfigs)
        }

        for r in 0..<rows {
            for c in 0..<cols where grid[r][c].isFlagged {
                result[Coord(r: r, c: c)] = 1.0
            }
        }

        return result
    }

    private static func localAverageProbabilities(
        grid: [[SolverCell]], rows: Int, cols: Int, unknown: [Coord], remainingMines: Int
    ) -> [Coord: Double] {
        var sums = [Coord: Double]()
        var counts = [Coord: Int]()

        for r in 0..<rows {
            for c in 0..<cols {
                guard let number = grid[r][c].revealedNumber, number > 0 else { continue }

                let neighbors = adjacent(r: r, c: c, rows: rows, cols: cols)
                let flaggedCount = neighbors.filter { grid[$0.r][$0.c].isFlagged }.count
                let unknownNeighbors = neighbors.filter {
                    let cell = grid[$0.r][$0.c]
                    return !cell.isRevealed && !cell.isFlagged
                }
                guard !unknownNeighbors.isEmpty else { continue }

                let localProb = Double(number - flaggedCount) / Double(unknownNeighbors.count)
                for coord in unknownNeighbors {
                    sums[coord, default: 0] += localProb
                    counts[coord, default: 0] += 1
                }
            }
        }

        var result = [Coord: Double]()
        let defaultProb = Double(remainingMines) / Double(max(unknown.count, 1))

        for coord in unknown {
            if let count = counts[coord], count > 0 {
                result[coord] = min(1.0, max(0.0, sums[coord]! / Double(count)))
            } else {
                result[coord] = defaultProb
            }
        }

        for r in 0..<rows {
            for c in 0..<cols where grid[r][c].isFlagged {
                result[Coord(r: r, c: c)] = 1.0
            }
        }

        return result
    }

    private static func uniformProbabilities(unknown: [Coord], remainingMines: Int) -> [Coord: Double]
    {
        let prob = Double(remainingMines) / Double(max(unknown.count, 1))
        var result = [Coord: Double]()
        for coord in unknown {
            result[coord] = prob
        }
        return result
    }

    private static func satisfiesConstraints(
        grid: [[SolverCell]], rows: Int, cols: Int, assignment: [Coord: Bool]
    ) -> Bool {
        for r in 0..<rows {
            for c in 0..<cols {
                guard let number = grid[r][c].revealedNumber, number > 0 else { continue }

                let neighbors = adjacent(r: r, c: c, rows: rows, cols: cols)
                var mineCount = neighbors.filter { grid[$0.r][$0.c].isFlagged }.count
                for coord in neighbors {
                    let cell = grid[coord.r][coord.c]
                    if !cell.isRevealed && !cell.isFlagged {
                        if assignment[coord] == true { mineCount += 1 }
                    }
                }
                if mineCount != number { return false }
            }
        }
        return true
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
