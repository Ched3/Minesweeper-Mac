//
//  GameScene+Input.swift
//  Minesweeper
//
//  Created by Cameron Goddard on 6/13/22.
//

import Defaults
import GameplayKit
import SpriteKit

extension GameScene {

    override func mouseDown(with event: NSEvent) {
        let clickedNode = self.nodes(at: event.location(in: scene!))
        guard !clickedNode.isEmpty else { return }

        if let buttonName = buttonName(from: clickedNode) {
            if buttonName == "Hint Button" {
                hintButton.setPressed(true)
            } else if buttonName == "Continue Button" {
                continueButton.setPressed(true)
            }
            return
        }

        if let name = tileName(from: clickedNode) ?? clickedNode[0].name {
            if name == "Main Button" {
                mainButton.set(state: .HappyPressed)
            } else if isTileName(name) {
                if gameState == .Won || gameState == .Lost { return }
                mainButton.set(state: .Cautious)

                currentTile = name

                let coords = convertLocation(name: name)
                let tile = board.tileAt(r: coords[0], c: coords[1])!

                if tile.state == .Covered || tile.state == .Question {
                    tile.pressed()
                } else if tile.state == .Uncovered && tile.isNumber() {
                    isChord = true
                    board.adjacentPressAt(r: tile.r, c: tile.c)
                }
                if isMiddleClick() || event.modifierFlags.contains(.command) {
                    // TODO: Decrement right clicks by 1
                    isChord = true
                    board.adjacentPressAt(r: tile.r, c: tile.c)
                }
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        let clickedNode = self.nodes(at: event.location(in: scene!))

        if !clickedNode.isEmpty, let buttonName = buttonName(from: clickedNode) {
            if buttonName == "Hint Button" {
                hintButton.setPressed(false)
                if gameState == .Unstarted || gameState == .InProgress {
                    showHint()
                }
            } else if buttonName == "Continue Button" {
                continueButton.setPressed(false)
                if gameState == .Lost {
                    continueGame()
                }
            }
            return
        }

        if clickedNode.isEmpty {
            mainButton.set(state: .Happy)
            if isChord {
                // Raise tiles if we were chording and released outside a tile
                if let tileName = currentTile {
                    let coords = convertLocation(name: tileName)
                    board.adjacentRaiseAt(r: coords[0], c: coords[1])
                }
                isChord = false
            }
            return
        }

        if let name = tileName(from: clickedNode) ?? clickedNode[0].name {
            if name == "Main Button" {
                mainButton.set(state: .Happy)
                newGame()
            } else if isTileName(name) {
                if gameState == .Won || gameState == .Lost { return }

                clearHintIfActive()

                mainButton.set(state: .Happy)
                let coords = convertLocation(name: name)
                let tile = board.tileAt(r: coords[0], c: coords[1])!

                if tile.state == .Flagged && !isChord {
                    isChord = false
                    return
                }

                if gameState == .Unstarted {
                    gameTimer.start()
                    gameState = .InProgress
                }

                let snapshot = board.captureSnapshot(
                    elapsedTime: gameTimer.elapsedTime,
                    mineCounter: mineCounter.mines
                )
                if board.revealAt(r: coords[0], c: coords[1], isChord: isChord) {
                    lastSnapshot = snapshot
                    finishGame(won: false)
                } else if board.revealedTiles == rows * cols - mines {
                    finishGame(won: true)
                }
                isChord = false
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers?.lowercased() == "r" {
            mainButton.set(state: .Happy)
            newGame()
        } else {
            super.keyDown(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if gameState == .Won || gameState == .Lost { return }
        let clickedNode = self.nodes(at: event.location(in: scene!))
        guard !clickedNode.isEmpty else { return }

        if buttonName(from: clickedNode) != nil { return }

        if let name = tileName(from: clickedNode) ?? clickedNode[0].name {
            if name == "Main Button" { return }
            guard isTileName(name) else { return }

            let coords = convertLocation(name: name)
            let tile = board.tileAt(r: coords[0], c: coords[1])!

            if isMiddleClick() {
                isChord = true
                board.adjacentPressAt(r: tile.r, c: tile.c)
                return
            }

            if tile.state == .Flagged {
                if Defaults[.General.questions] {
                    board.setAt(r: coords[0], c: coords[1], state: .Question)
                } else {
                    board.setAt(r: coords[0], c: coords[1], state: .Covered)
                }
                mineCounter.increment()
            } else if tile.state == .Covered {
                board.setAt(r: coords[0], c: coords[1], state: .Flagged)
                mineCounter.decrement()
            } else if tile.state == .Question {
                board.setAt(r: coords[0], c: coords[1], state: .Covered)
            }

            tile.clearHintOverlay()

            NotificationCenter.default.post(name: .updateStat, object: nil, userInfo: ["Effective": 0])
            NotificationCenter.default.post(name: .updateStat, object: nil, userInfo: ["Right": 0])
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        // If we were chording, we need to perform the chord action
        if isChord {
            let clickedNode = self.nodes(at: event.location(in: scene!))

            // If still over a tile, perform the chord
            if let name = tileName(from: clickedNode) ?? clickedNode.first?.name,
                isTileName(name)
            {
                if gameState == .Won || gameState == .Lost {
                    isChord = false
                    return
                }

                clearHintIfActive()

                if gameState == .Unstarted {
                    gameTimer.start()
                    gameState = .InProgress
                }

                let coords = convertLocation(name: name)
                let snapshot = board.captureSnapshot(
                    elapsedTime: gameTimer.elapsedTime,
                    mineCounter: mineCounter.mines
                )

                if board.revealAt(r: coords[0], c: coords[1], isChord: true) {
                    lastSnapshot = snapshot
                    finishGame(won: false)
                } else if board.revealedTiles == rows * cols - mines {
                    finishGame(won: true)
                }
            } else if let tileName = currentTile {
                // If not over a tile, use the last known tile position
                let coords = convertLocation(name: tileName)
                board.adjacentRaiseAt(r: coords[0], c: coords[1])
            }

            isChord = false
            mainButton.set(state: .Happy)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let clickedNode = self.nodes(at: event.location(in: scene!))

        if let name = tileName(from: clickedNode) ?? clickedNode.first?.name {
            if name == "Main Button" { return }
            if gameState == .Won || gameState == .Lost { return }
            guard isTileName(name) else { return }

            if currentTile == name {
                let coords = convertLocation(name: name)
                let tile = board.tileAt(r: coords[0], c: coords[1])

                if tile?.state == .Covered || tile?.state == .Question {
                    tile?.pressed()
                }
                if isChord {
                    board.adjacentPressAt(r: tile!.r, c: tile!.c)
                }
            } else if let currentTile {
                let coords = convertLocation(name: currentTile)
                let tile = board.tileAt(r: coords[0], c: coords[1])

                if isChord, let dragName = tileName(from: clickedNode) ?? clickedNode.first?.name,
                    isTileName(dragName)
                {
                    let dragCoords = convertLocation(name: dragName)
                    board.adjacentRaiseAt(
                        r: tile!.r, c: tile!.c, diffR: dragCoords[0], diffC: dragCoords[1])
                } else {
                    tile?.raised()
                }
                self.currentTile = name
            }
        }
    }

    private func clearHintIfActive() {
        if hintActive {
            clearHint()
        }
    }

    private func buttonName(from nodes: [SKNode]) -> String? {
        for node in nodes {
            var current: SKNode? = node
            while let n = current {
                if n.name == "Hint Button" || n.name == "Continue Button" {
                    return n.name
                }
                current = n.parent
            }
        }
        return nil
    }

    private func tileName(from nodes: [SKNode]) -> String? {
        for node in nodes {
            var current: SKNode? = node
            while let n = current {
                if let name = n.name, isTileName(name) {
                    return name
                }
                current = n.parent
            }
        }
        return nil
    }

    private func isTileName(_ name: String) -> Bool {
        let parts = name.split(separator: ",")
        guard parts.count == 2 else { return false }
        return parts[0].allSatisfy(\.isNumber) && parts[1].allSatisfy(\.isNumber)
    }

    private func isMiddleClick() -> Bool {
        return (NSEvent.pressedMouseButtons & 0b11) == 0b11
    }

    private func convertLocation(name: String) -> [Int] {
        let coords = name.components(separatedBy: ",")
        let r = Int(String(coords[0]))!
        let c = Int(String(coords[1]))!
        return [r, c]
    }
}
