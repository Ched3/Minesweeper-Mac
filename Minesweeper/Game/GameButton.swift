//
//  GameButton.swift
//  Minesweeper
//

import SpriteKit

class GameButton: SKSpriteNode {

    private let label: SKLabelNode
    private var sceneSize: CGSize
    private var buttonScale: CGFloat

    var isHiddenButton: Bool = false {
        didSet {
            self.isHidden = isHiddenButton
        }
    }

    init(title: String, name: String, sceneSize: CGSize, scale: CGFloat) {
        self.sceneSize = sceneSize
        self.buttonScale = scale

        let theme = ThemeManager.shared.current
        let buttonSize = theme.mainButton.happy.size()

        label = SKLabelNode(text: title)
        label.fontName = "Helvetica-Bold"
        label.fontSize = title.count > 4 ? 5 : 7
        label.fontColor = .black
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1

        super.init(texture: theme.tiles.covered, color: .clear, size: buttonSize)

        self.name = name
        self.anchorPoint = CGPoint(x: 0, y: 1)
        self.zPosition = 5
        self.setScale(scale)
        addChild(label)
        centerLabel()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setPressed(_ pressed: Bool) {
        let theme = ThemeManager.shared.current
        texture = pressed ? theme.tiles.pressed : theme.tiles.covered
    }

    func updateTextures(to theme: Theme) {
        texture = theme.tiles.covered
    }

    func updateScale(sceneSize: CGSize, scale: CGFloat) {
        self.sceneSize = sceneSize
        self.buttonScale = scale
        self.setScale(scale)
        label.fontSize = (label.text?.count ?? 0) > 4 ? 5 * scale / 1.5 : 7 * scale / 1.5
        centerLabel()
    }

    func layoutNextTo(mainButton: MainButton, xOffset: CGFloat) {
        let mainWidth = ThemeManager.shared.current.mainButton.happy.size().width * buttonScale
        let gap = 4 * buttonScale
        position = CGPoint(
            x: mainButton.position.x + mainWidth + gap + xOffset,
            y: sceneSize.height / 2 - (buttonScale * 15)
        )
    }

    private func centerLabel() {
        label.position = CGPoint(x: size.width / 2, y: -size.height / 2)
    }
}
