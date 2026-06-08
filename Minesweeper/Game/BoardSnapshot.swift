//
//  BoardSnapshot.swift
//  Minesweeper
//

import Foundation

struct BoardSnapshot {
    struct Cell {
        let state: Tile.State
        let value: Tile.Value
    }

    let cells: [[Cell]]
    let revealedTiles: Int
    let mineCounter: Int
    let elapsedTime: TimeInterval
}

struct SolverCell {
    let isRevealed: Bool
    let isFlagged: Bool
    /// Adjacency mine count for revealed number tiles; 0 for revealed empty; nil when hidden.
    let revealedNumber: Int?
}

struct Coord: Hashable {
    let r: Int
    let c: Int
}
