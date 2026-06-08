//
//  Tile.swift
//  Minesweeper
//
//  Created by Cameron Goddard on 4/3/22.
//

import Foundation
import SpriteKit

@MainActor
class Tile {

    enum State {
        case Covered
        case Uncovered
        case Flagged
        case Question
    }

    enum Value {
        case Mine
        case MineRed
        case MineWrong
        case Empty
        case One
        case Two
        case Three
        case Four
        case Five
        case Six
        case Seven
        case Eight
    }

    let node: SKSpriteNode

    let r: Int
    let c: Int
    var state: State
    var value: Value

    init(r: Int, c: Int, state: State, val: Value = .Empty) {
        self.node = SKSpriteNode()
        self.r = r
        self.c = c
        self.state = state
        self.value = val
        self.node.texture = ThemeManager.shared.current.tiles.covered
        self.node.anchorPoint = CGPoint(x: 0, y: 1)
        self.node.name = String(r) + "," + String(c)
    }

    init() {
        self.node = SKSpriteNode()
        self.r = 0
        self.c = 0
        self.state = .Question
        self.value = .Empty
    }

    func setState(state: State, theme: Theme = ThemeManager.shared.current) {
        self.state = state

        switch state {
        case .Uncovered:
            self.node.texture = textureLookup(value: self.value, theme: theme)
        case .Covered:
            self.node.texture = theme.tiles.covered
        case .Flagged:
            self.node.texture = theme.tiles.flagged
        case .Question:
            self.node.texture = theme.tiles.question
        }
    }

    func setValue(val: Value) {
        self.value = val
    }

    func isNumber() -> Bool {
        return
            !(self.value == .Empty || self.value == .Mine || self.value == .MineRed
            || self.value == .MineWrong)
    }

    func pressed() {
        if self.state == .Question {
            self.node.texture = ThemeManager.shared.current.tiles.questionPressed
        } else {
            self.node.texture = ThemeManager.shared.current.tiles.pressed
        }
    }

    func raised() {
        self.setState(state: self.state)
    }

    enum HintOverlayKind {
        case safe
        case mine
        case probability(percent: Int, highlight: Bool)
    }

    func clearHintOverlay() {
        node.childNode(withName: "hintOverlay")?.removeFromParent()
    }

    func showHintOverlay(kind: HintOverlayKind, scale: CGFloat) {
        clearHintOverlay()

        let size = node.size
        let overlay = SKNode()
        overlay.name = "hintOverlay"
        overlay.zPosition = 10
        overlay.isUserInteractionEnabled = false

        switch kind {
        case .safe:
            let shape = SKShapeNode(rectOf: size)
            shape.isUserInteractionEnabled = false
            shape.fillColor = NSColor.systemGreen.withAlphaComponent(0.45)
            shape.strokeColor = NSColor.systemGreen
            shape.lineWidth = 1.5
            shape.position = CGPoint(x: size.width / 2, y: -size.height / 2)
            overlay.addChild(shape)
        case .mine:
            let shape = SKShapeNode(rectOf: size)
            shape.isUserInteractionEnabled = false
            shape.fillColor = NSColor.systemOrange.withAlphaComponent(0.45)
            shape.strokeColor = NSColor.systemOrange
            shape.lineWidth = 1.5
            shape.position = CGPoint(x: size.width / 2, y: -size.height / 2)
            overlay.addChild(shape)
        case .probability(let percent, let highlight):
            if highlight {
                let shape = SKShapeNode(rectOf: size)
                shape.isUserInteractionEnabled = false
                shape.fillColor = NSColor.systemGreen.withAlphaComponent(0.35)
                shape.strokeColor = NSColor.systemGreen
                shape.lineWidth = 1.5
                shape.position = CGPoint(x: size.width / 2, y: -size.height / 2)
                overlay.addChild(shape)
            }
            let label = SKLabelNode(text: "\(percent)%")
            label.isUserInteractionEnabled = false
            label.fontName = "Helvetica-Bold"
            label.fontSize = max(6, 8 * scale / 1.5)
            label.fontColor = highlight ? .white : .black
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: size.width / 2, y: -size.height / 2)
            overlay.addChild(label)
        }

        node.addChild(overlay)
    }

    func textureLookup(value: Value, theme: Theme) -> SKTexture {
        switch value {
        case .Mine:
            return theme.tiles.mine
        case .MineRed:
            return theme.tiles.mineRed
        case .MineWrong:
            return theme.tiles.mineWrong
        case .One:
            return theme.tiles.one
        case .Two:
            return theme.tiles.two
        case .Three:
            return theme.tiles.three
        case .Four:
            return theme.tiles.four
        case .Five:
            return theme.tiles.five
        case .Six:
            return theme.tiles.six
        case .Seven:
            return theme.tiles.seven
        case .Eight:
            return theme.tiles.eight
        default:
            return theme.tiles.empty
        }
    }
}

extension Tile: Equatable {
    nonisolated static func == (lhs: Tile, rhs: Tile) -> Bool {
        return lhs.r == rhs.r && lhs.c == rhs.c
    }
}

extension Tile: CustomStringConvertible {
    nonisolated var description: String {
        return "[\(r), \(c)]"
    }
}
