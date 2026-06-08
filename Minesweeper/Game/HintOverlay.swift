//
//  HintOverlay.swift
//  Minesweeper
//

import SpriteKit

@MainActor
class HintOverlay {

    private let board: Board

    init(board: Board) {
        self.board = board
    }

    func clear() {
        for r in 0..<board.rows {
            for c in 0..<board.cols {
                board.tileAt(r: r, c: c)?.clearHintOverlay()
            }
        }
    }

    func showDeterministic(safe: Set<Coord>, mines: Set<Coord>) {
        clear()
        for coord in safe {
            board.tileAt(r: coord.r, c: coord.c)?.showHintOverlay(
                kind: .safe, scale: board.hintScale)
        }
        for coord in mines {
            board.tileAt(r: coord.r, c: coord.c)?.showHintOverlay(
                kind: .mine, scale: board.hintScale)
        }
    }

    func showProbabilities(_ probabilities: [Coord: Double]) {
        clear()

        let unrevealed = probabilities.filter { coord, prob in
            guard let tile = board.tileAt(r: coord.r, c: coord.c) else { return false }
            return tile.state != .Uncovered && prob < 1.0
        }

        let minProb = unrevealed.values.min() ?? 0

        for (coord, prob) in probabilities {
            guard let tile = board.tileAt(r: coord.r, c: coord.c) else { continue }
            if tile.state == .Uncovered { continue }

            let percent = Int((prob * 100).rounded())
            let highlight = prob == minProb && prob < 1.0
            tile.showHintOverlay(
                kind: .probability(percent: percent, highlight: highlight),
                scale: board.hintScale)
        }
    }
}
