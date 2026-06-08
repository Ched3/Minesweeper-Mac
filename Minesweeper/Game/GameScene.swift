//
//  GameScene.swift
//  Minesweeper
//
//  Created by Cameron Goddard on 4/3/22.
//

import Defaults
import GameplayKit
import SpriteKit

enum GameState {
    case Unstarted
    case InProgress
    case Won
    case Lost
}

class GameScene: SKScene {

    var gameState: GameState = .Unstarted

    var board: Board
    var borders: Borders
    var gameTimer: GameTimer
    var mineCounter: MineCounter
    var mainButton: MainButton
    var hintButton: GameButton!
    var continueButton: GameButton!

    var rows, cols, mines: Int
    var scale: CGFloat

    let isThemePreview: Bool
    let gameMode: GameMode

    var currentTile: String? = nil
    var isChord = false
    var lastSnapshot: BoardSnapshot?
    var hintOverlay: HintOverlay!
    var hintActive = false

    init(
        size: CGSize, scale: CGFloat, rows: Int, cols: Int, mines: Int, minesLayout: [(Int, Int)]?,
        isThemePreview: Bool = false, gameMode: GameMode = .standard
    ) {
        self.rows = rows
        self.cols = cols
        self.mines = mines
        self.scale = scale
        self.isThemePreview = isThemePreview
        self.gameMode = gameMode

        borders = Borders(sceneSize: size, scale: scale)
        board = Board(
            scale: scale, rows: rows, cols: cols, mines: mines, minesLayout: minesLayout,
            isThemePreview: isThemePreview, gameMode: gameMode)
        mainButton = MainButton(sceneSize: size, scale: scale)
        gameTimer = GameTimer(sceneSize: size, scale: scale)
        mineCounter = MineCounter(sceneSize: size, scale: scale, mines: mines)

        super.init(size: size)

        hintOverlay = HintOverlay(board: board)
        hintButton = GameButton(
            title: "", name: "Hint Button", sceneSize: size, scale: scale)
        continueButton = GameButton(
            title: "Continue", name: "Continue Button", sceneSize: size, scale: scale)
        continueButton.isHiddenButton = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(self.restartGame(_:)), name: .restartGame, object: nil)
    }

    /// Called when the scene is presented by a view
    /// - Parameter view: The view that is presenting this scene
    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addNodes()
    }

    /// Creates the game board, number displays, and borders with the current theme. Adds all to this game scene
    func addNodes() {
        self.addChild(borders)
        self.addChild(mainButton)
        self.addChild(mineCounter)
        self.addChild(gameTimer)
        if !isThemePreview {
            self.addChild(hintButton)
            self.addChild(continueButton)
            updateButtonsForGameState()
            layoutHeaderButtons()
        }
        self.addChild(board.node)

        if isThemePreview {
            // Add a transparent blocker to prevent user interaction in the themes settings window
            let blocker = SKSpriteNode(color: .clear, size: self.size)
            blocker.position = .zero
            blocker.zPosition = 1000
            self.addChild(blocker)

            mineCounter.mines = 7
            gameTimer.elapsedTime = 42
        }
    }

    /// Force update all game textures. Called when a theme is changed
    /// - Parameter theme: The theme to update to
    func updateTextures(to theme: Theme = ThemeManager.shared.current) {
        borders.updateTextures(to: theme)
        mainButton.updateTextures(to: theme)
        board.updateTextures(to: theme)
        gameTimer.updateTextures(to: theme)
        mineCounter.updateTextures(to: theme)
        if !isThemePreview {
            hintButton.updateTextures(to: theme)
            continueButton.updateTextures(to: theme)
        }
    }

    func layoutHeaderButtons() {
        guard !isThemePreview else { return }
        hintButton.layoutNextTo(mainButton: mainButton, xOffset: 0)
        continueButton.layoutNextTo(mainButton: mainButton, xOffset: 0)
    }

    /// Force update the size of all nodes. Called when the scale setting is changed, or the Zoom button is pressed
    /// - Parameters:
    ///   - size: The new scene size to adapt to
    ///   - scale: The new scaling for each node
    func updateScale(size: CGSize, scale: CGFloat) {
        self.scale = scale

        borders.updateScale(sceneSize: size, scale: scale)
        mainButton.updateScale(sceneSize: size, scale: scale)
        board.updateScale(scale: scale)
        gameTimer.updateScale(sceneSize: size, scale: scale)
        mineCounter.updateScale(sceneSize: size, scale: scale)
        if !isThemePreview {
            hintButton.updateScale(sceneSize: size, scale: scale)
            continueButton.updateScale(sceneSize: size, scale: scale)
            layoutHeaderButtons()
        }
        clearHint()
    }

    func clearHint() {
        hintActive = false
        hintOverlay.clear()
    }

    func showHint() {
        clearHint()
        let grid = board.exportSolverGrid()
        let result = HintSolver.solve(
            grid: grid,
            rows: rows,
            cols: cols,
            totalMines: mines,
            flagCount: board.flagCount()
        )
        switch result {
        case .deterministic(let safe, let mineTiles):
            hintOverlay.showDeterministic(safe: safe, mines: mineTiles)
        case .probabilities(let probs):
            hintOverlay.showProbabilities(probs)
        }
        hintActive = true
    }

    func continueGame() {
        guard let snapshot = lastSnapshot else { return }
        board.restoreSnapshot(snapshot)
        mineCounter.mines = snapshot.mineCounter
        mineCounter.set(value: snapshot.mineCounter)
        gameState = .InProgress
        mainButton.set(state: .Happy)
        continueButton.isHiddenButton = true
        hintButton.isHiddenButton = false
        gameTimer.resume(from: snapshot.elapsedTime)
        lastSnapshot = nil
    }

    private func updateButtonsForGameState() {
        guard !isThemePreview else { return }
        switch gameState {
        case .Unstarted, .InProgress:
            hintButton.isHiddenButton = false
            continueButton.isHiddenButton = true
        case .Lost:
            hintButton.isHiddenButton = true
            continueButton.isHiddenButton = lastSnapshot == nil
        case .Won:
            hintButton.isHiddenButton = true
            continueButton.isHiddenButton = true
        }
    }

    /// Handle game ending logic for the board, main button, and stats
    /// - Parameter won: Whether the player won the game
    func finishGame(won: Bool) {
        NotificationCenter.default.post(name: .revealStats, object: nil)

        if won {
            gameState = .Won
            board.flagMines()
            mainButton.set(state: .Cool)
            lastSnapshot = nil
            clearHint()

            updateBestTimes()
        } else {
            gameState = .Lost
            board.lostGame()
            mainButton.set(state: .Dead)
            clearHint()
        }
        updateButtonsForGameState()
        gameTimer.stop()
    }

    /// Update the list of best game times across all difficulties
    private func updateBestTimes() {
        let offset: Int
        switch Defaults[.Game.difficulty] {
        case "Beginner":
            offset = 0
        case "Intermediate":
            offset = 2
        case "Hard":
            offset = 5
        default:
            return
        }

        if gameTimer.elapsedTime < Defaults[.BestTimes.bestTimes][offset]
            || Defaults[.BestTimes.bestTimes][offset] == -1
        {
            Defaults[.BestTimes.bestTimes][offset + 2] = Defaults[.BestTimes.bestTimes][offset + 1]
            Defaults[.BestTimes.bestTimes][offset + 1] = Defaults[.BestTimes.bestTimes][offset]
            Defaults[.BestTimes.bestTimes][offset] = gameTimer.elapsedTime
        } else if gameTimer.elapsedTime < Defaults[.BestTimes.bestTimes][offset + 1]
            || Defaults[.BestTimes.bestTimes][offset + 1] == -1
        {
            Defaults[.BestTimes.bestTimes][offset + 2] = Defaults[.BestTimes.bestTimes][offset + 1]
            Defaults[.BestTimes.bestTimes][offset + 1] = gameTimer.elapsedTime
        } else if gameTimer.elapsedTime < Defaults[.BestTimes.bestTimes][offset + 2]
            || Defaults[.BestTimes.bestTimes][offset + 2] == -1
        {
            Defaults[.BestTimes.bestTimes][offset + 2] = gameTimer.elapsedTime
        }
    }

    /// Handles game reset logic for the board, stats, and number displays
    /// - Parameter restart: Whether the previous board is being replayed
    func newGame(restart: Bool = false) {
        gameState = .Unstarted
        lastSnapshot = nil
        clearHint()
        NotificationCenter.default.post(name: .resetStats, object: nil)

        board.reset(restart: restart)
        gameTimer.reset()
        mineCounter.reset(mines: mines)
        mainButton.set(state: .Happy)
        updateButtonsForGameState()
    }

    /// Called when the previous board should be replayed
    @objc func restartGame(_: Notification) {
        newGame(restart: true)
    }

    /// Required method
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }

    /// Required method
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
