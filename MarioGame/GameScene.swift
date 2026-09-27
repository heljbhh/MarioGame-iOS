import SpriteKit

// MARK: - Tiles

private enum Tile: Int {
    case empty = 0
    case ground
    case brick
    case question
    case used
    case pipe
    case pipeTop

    var isSolid: Bool { self != .empty }
}

// MARK: - Entities

private final class Coin {
    let node: SKShapeNode
    var t: Double = 0
    var taken = false
    init(node: SKShapeNode) { self.node = node }
}

private final class Enemy {
    let node: SKSpriteNode
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var dir: CGFloat = -1
    var alive = true
    let w: CGFloat = 48
    let h: CGFloat = 40
    init(node: SKSpriteNode, x: CGFloat, y: CGFloat) {
        self.node = node
        self.x = x
        self.y = y
    }
}

// MARK: - Game scene

final class GameScene: SKScene {

    weak var gameState: GameState?

    // World constants
    private let tile: CGFloat = 64
    private let rows = 12
    private let cols = 120
    private var levelWidth: CGFloat { CGFloat(cols) * tile }
    private var levelHeight: CGFloat { CGFloat(rows) * tile }
    private var groundTopY: CGFloat { levelHeight - CGFloat(10) * tile }

    // Tiles & nodes
    private var tiles: [[Tile]] = []
    private var tileNodes: [String: SKSpriteNode] = [:]
    private var world: SKNode?
    private var cam: SKCameraNode?

    // Player state
    private var player: SKSpriteNode?
    private var px: CGFloat = 0
    private var py: CGFloat = 0
    private var vx: CGFloat = 0
    private var vy: CGFloat = 0
    private var onGround = false
    private let playerW: CGFloat = 44
    private let playerH: CGFloat = 60
    private let moveSpeed: CGFloat = 400
    private let jumpSpeed: CGFloat = 1130
    private let gravity: CGFloat = 2800
    private let maxFall: CGFloat = 1300
    private var invTimer: CGFloat = 0
    private var spawnX: CGFloat = 0
    private var spawnY: CGFloat = 0

    // Touch controls
    private enum PadButton { case left, right, jump }
    private var touchButtons: [UITouch: PadButton] = [:]
    private var leftHeld = false
    private var rightHeld = false
    private var leftNode: SKShapeNode?
    private var rightNode: SKShapeNode?
    private var jumpNode: SKShapeNode?

    // HUD
    private var scoreLabel: SKLabelNode?
    private var coinLabel: SKLabelNode?
    private var livesLabel: SKLabelNode?

    // Entities
    private var coins: [Coin] = []
    private var enemies: [Enemy] = []
    private var flagX: CGFloat = 0

    private var lastTime: TimeInterval = 0

    // MARK: - Adaptive layout (scene size follows the real view)

    /// Fixed logical height; the width follows the view's aspect ratio so
    /// the scene always fills the screen exactly (no bars, no cropping).
    static func sizeForView(_ viewSize: CGSize) -> CGSize {
        let h: CGFloat = 720
        let aspect = viewSize.width / max(viewSize.height, 1)
        return CGSize(width: max(h * aspect, h * 1.2), height: h)
    }

    private var halfW: CGFloat { size.width / 2 }
    private var halfH: CGFloat { size.height / 2 }

    /// Re-fit the scene when the hosting view changes size.
    func fitToView(_ viewSize: CGSize) {
        let newSize = GameScene.sizeForView(viewSize)
        guard abs(newSize.width - size.width) > 0.5 else { return }
        size = newSize
        layoutForCurrentSize()
    }

    /// Camera, HUD and touch buttons are positioned relative to the
    /// current scene size, so nothing is ever cut off at the edges.
    private func layoutForCurrentSize() {
        if levelWidth > size.width {
            cam?.position = CGPoint(x: min(max(px, halfW), levelWidth - halfW), y: halfH)
        } else {
            cam?.position = CGPoint(x: levelWidth / 2, y: halfH)
        }
        scoreLabel?.position = CGPoint(x: -halfW + 100, y: halfH - 55)
        coinLabel?.position = CGPoint(x: -halfW + 340, y: halfH - 55)
        livesLabel?.position = CGPoint(x: halfW - 100, y: halfH - 55)
        leftNode?.position = CGPoint(x: -halfW + 95, y: -(halfH - 95))
        rightNode?.position = CGPoint(x: -halfW + 235, y: -(halfH - 95))
        jumpNode?.position = CGPoint(x: halfW - 95, y: -(halfH - 95))
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0)
        buildWorld()
        setupCamera()
        updateHUD()
        // Position camera, HUD and buttons for the initial scene size right
        // away, so the first frame is correct even before any resize.
        layoutForCurrentSize()
    }

    func startNewGame() {
        world?.removeFromParent()
        tileNodes.removeAll()
        coins.removeAll()
        enemies.removeAll()
        touchButtons.removeAll()
        leftHeld = false
        rightHeld = false
        invTimer = 0
        lastTime = 0
        buildWorld()
        cam?.position = CGPoint(x: halfW, y: halfH)
        updateHUD()
    }

    // MARK: - Level construction

    private func buildWorld() {
        let w = SKNode()
        world = w
        addChild(w)
        tiles = Array(repeating: Array(repeating: Tile.empty, count: cols), count: rows)

        // Ground segments with pits between them
        addGround(from: 0, to: 24)
        addGround(from: 28, to: 46)
        addGround(from: 50, to: 75)
        addGround(from: 79, to: cols - 1)

        // Floating brick / question blocks
        setTile(10, 7, .brick);    setTile(11, 7, .question); setTile(12, 7, .brick)
        setTile(13, 7, .question);  setTile(14, 7, .brick)
        setTile(32, 7, .question);  setTile(33, 7, .brick);    setTile(34, 7, .question)
        setTile(63, 7, .brick);     setTile(64, 7, .question); setTile(65, 7, .brick)

        // Pipes (2 tiles wide)
        addPipe(col: 20, height: 2)
        addPipe(col: 55, height: 2)
        addPipe(col: 88, height: 1)

        // Coins: arcs over pits and floating rows
        for c in 25...27 { addCoin(col: c, row: 8) }
        for c in 47...49 { addCoin(col: c, row: 8) }
        for c in 60...65 { addCoin(col: c, row: 6) }
        addCoin(col: 11, row: 5)
        addCoin(col: 13, row: 5)

        // Enemies
        addEnemy(col: 36)
        addEnemy(col: 62)
        addEnemy(col: 84)
        addEnemy(col: 100)

        // Staircase before the flag
        for i in 0..<4 {
            for j in 0...i {
                setTile(106 + i, 9 - j, .ground)
            }
        }

        // Goal flag
        let flagCol = 113
        flagX = CGFloat(flagCol) * tile + tile / 2

        renderTiles()
        renderFlag(col: flagCol)
        renderDecorations()

        // Player
        spawnX = CGFloat(2) * tile + tile / 2
        spawnY = groundTopY + playerH / 2
        px = spawnX
        py = spawnY
        vx = 0
        vy = 0
        onGround = false

        let body = SKSpriteNode(
            color: UIColor(red: 0.9, green: 0.12, blue: 0.12, alpha: 1.0),
            size: CGSize(width: playerW, height: playerH)
        )
        body.position = CGPoint(x: px, y: py)
        body.zPosition = 4
        let eyeL = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 14))
        eyeL.position = CGPoint(x: -9, y: 12)
        let eyeR = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 14))
        eyeR.position = CGPoint(x: 9, y: 12)
        body.addChild(eyeL)
        body.addChild(eyeR)
        player = body
        w.addChild(body)
    }

    private func setTile(_ col: Int, _ row: Int, _ t: Tile) {
        guard col >= 0, col < cols, row >= 0, row < rows else { return }
        tiles[row][col] = t
    }

    private func addGround(from c0: Int, to c1: Int) {
        for c in c0...c1 {
            setTile(c, 10, .ground)
            setTile(c, 11, .ground)
        }
    }

    private func addPipe(col: Int, height: Int) {
        for j in 0..<height {
            setTile(col, 9 - j, .pipe)
            setTile(col + 1, 9 - j, .pipe)
        }
        setTile(col, 9 - height, .pipeTop)
        setTile(col + 1, 9 - height, .pipeTop)
    }

    private func tileCenter(col: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(col) * tile + tile / 2,
            y: levelHeight - CGFloat(row) * tile - tile / 2
        )
    }

    private func color(for t: Tile) -> UIColor {
        switch t {
        case .ground:   return UIColor(red: 0.72, green: 0.42, blue: 0.18, alpha: 1.0)
        case .brick:    return UIColor(red: 0.62, green: 0.28, blue: 0.12, alpha: 1.0)
        case .question: return UIColor(red: 0.98, green: 0.78, blue: 0.18, alpha: 1.0)
        case .used:     return UIColor(red: 0.50, green: 0.35, blue: 0.20, alpha: 1.0)
        case .pipe, .pipeTop:
            return UIColor(red: 0.16, green: 0.68, blue: 0.22, alpha: 1.0)
        case .empty:    return .clear
        }
    }

    private func renderTiles() {
        guard let w = world else { return }
        for r in 0..<rows {
            for c in 0..<cols {
                let t = tiles[r][c]
                guard t.isSolid else { continue }
                let size: CGSize = (t == .pipeTop)
                    ? CGSize(width: tile + 12, height: tile)
                    : CGSize(width: tile, height: tile)
                let node = SKSpriteNode(color: color(for: t), size: size)
                node.position = tileCenter(col: c, row: r)
                node.zPosition = 1
                if t == .question {
                    let q = SKLabelNode(fontNamed: "Helvetica-Bold")
                    q.text = "?"
                    q.fontSize = 34
                    q.fontColor = UIColor(red: 0.4, green: 0.25, blue: 0.05, alpha: 1.0)
                    q.verticalAlignmentMode = .center
                    q.horizontalAlignmentMode = .center
                    q.position = .zero
                    node.addChild(q)
                }
                w.addChild(node)
                tileNodes["\(c),\(r)"] = node
            }
        }
    }

    private func renderFlag(col: Int) {
        guard let w = world else { return }
        let poleX = CGFloat(col) * tile + tile / 2
        let poleBottom = groundTopY
        let poleTop = levelHeight - CGFloat(3) * tile

        let pole = SKSpriteNode(
            color: .gray,
            size: CGSize(width: 10, height: poleTop - poleBottom)
        )
        pole.position = CGPoint(x: poleX, y: (poleTop + poleBottom) / 2)
        pole.zPosition = 2
        w.addChild(pole)

        let ball = SKShapeNode(circleOfRadius: 16)
        ball.fillColor = .green
        ball.strokeColor = .clear
        ball.position = CGPoint(x: poleX, y: poleTop + 10)
        ball.zPosition = 2
        w.addChild(ball)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -90, y: -28))
        path.addLine(to: CGPoint(x: 0, y: -56))
        path.closeSubpath()
        let flag = SKShapeNode(path: path)
        flag.fillColor = UIColor(red: 0.1, green: 0.7, blue: 0.2, alpha: 1.0)
        flag.strokeColor = .clear
        flag.position = CGPoint(x: poleX - 5, y: poleTop - 12)
        flag.zPosition = 2
        w.addChild(flag)
    }

    private func renderDecorations() {
        guard let w = world else { return }
        for x in [700, 2200, 3900, 5600, 6900] as [CGFloat] {
            let cloud = SKSpriteNode(color: .white, size: CGSize(width: 180, height: 60))
            cloud.position = CGPoint(x: x, y: 560)
            cloud.zPosition = -5
            cloud.alpha = 0.9
            w.addChild(cloud)
        }
        for x in [1600, 3800, 6200] as [CGFloat] {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -110, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 130))
            path.addLine(to: CGPoint(x: 110, y: 0))
            path.closeSubpath()
            let hill = SKShapeNode(path: path)
            hill.fillColor = UIColor(red: 0.2, green: 0.7, blue: 0.25, alpha: 1.0)
            hill.strokeColor = .clear
            hill.position = CGPoint(x: x, y: groundTopY)
            hill.zPosition = -5
            w.addChild(hill)
        }
    }

    private func addCoin(col: Int, row: Int) {
        guard let w = world else { return }
        let n = SKShapeNode(circleOfRadius: 18)
        n.fillColor = UIColor(red: 1.0, green: 0.82, blue: 0.1, alpha: 1.0)
        n.strokeColor = UIColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1.0)
        n.lineWidth = 3
        n.position = tileCenter(col: col, row: row)
        n.zPosition = 2
        w.addChild(n)
        coins.append(Coin(node: n))
    }

    private func addEnemy(col: Int) {
        guard let w = world else { return }
        let n = SKSpriteNode(
            color: UIColor(red: 0.55, green: 0.32, blue: 0.16, alpha: 1.0),
            size: CGSize(width: 48, height: 40)
        )
        let e1 = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
        e1.position = CGPoint(x: -10, y: 6)
        let e2 = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
        e2.position = CGPoint(x: 10, y: 6)
        n.addChild(e1)
        n.addChild(e2)
        let x = CGFloat(col) * tile + tile / 2
        let y = groundTopY + 20
        n.position = CGPoint(x: x, y: y)
        n.zPosition = 3
        w.addChild(n)
        enemies.append(Enemy(node: n, x: x, y: y))
    }

    // MARK: - Camera, HUD, controls

    private func setupCamera() {
        let c = SKCameraNode()
        cam = c
        addChild(c)
        camera = c

        scoreLabel = makeLabel(text: "SCORE 0", pos: .zero)
        coinLabel = makeLabel(text: "COINS 0", pos: .zero)
        livesLabel = makeLabel(text: "LIVES 3", pos: .zero)

        leftNode = makeButton(title: "◀", pos: .zero)
        rightNode = makeButton(title: "▶", pos: .zero)
        jumpNode = makeButton(title: "▲", pos: .zero)

        layoutForCurrentSize()
    }

    private func makeLabel(text: String, pos: CGPoint) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: "Helvetica-Bold")
        l.text = text
        l.fontSize = 30
        l.fontColor = .white
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .center
        l.position = pos
        l.zPosition = 10
        cam?.addChild(l)
        return l
    }

    private func makeButton(title: String, pos: CGPoint) -> SKShapeNode {
        let b = SKShapeNode(circleOfRadius: 58)
        b.fillColor = UIColor(white: 1.0, alpha: 0.25)
        b.strokeColor = UIColor(white: 1.0, alpha: 0.6)
        b.lineWidth = 3
        b.position = pos
        b.zPosition = 10
        let t = SKLabelNode(fontNamed: "Helvetica-Bold")
        t.text = title
        t.fontSize = 40
        t.fontColor = .white
        t.horizontalAlignmentMode = .center
        t.verticalAlignmentMode = .center
        b.addChild(t)
        cam?.addChild(b)
        return b
    }

    private func updateHUD() {
        guard let gs = gameState else { return }
        scoreLabel?.text = "SCORE \(gs.score)"
        coinLabel?.text = "COINS \(gs.coins)"
        livesLabel?.text = "LIVES \(gs.lives)"
    }

    // MARK: - Main loop

    override func update(_ currentTime: TimeInterval) {
        guard let gs = gameState, gs.screen == .playing else { return }

        var dt = currentTime - lastTime
        lastTime = currentTime
        if dt <= 0 || dt > 1.0 / 20.0 {
            dt = 1.0 / 60.0
        }
        let step = CGFloat(dt)

        // Horizontal input
        var targetV: CGFloat = 0
        if leftHeld { targetV -= moveSpeed }
        if rightHeld { targetV += moveSpeed }
        vx = targetV

        // Gravity
        vy -= gravity * step
        if vy < -maxFall { vy = -maxFall }

        // Hurt blink
        if invTimer > 0 {
            invTimer -= step
            let phase = (Double(invTimer) * 10).truncatingRemainder(dividingBy: 2)
            player?.alpha = phase < 1 ? 0.4 : 1.0
        } else {
            player?.alpha = 1.0
        }

        movePlayer(dt: step)
        updateEnemies(dt: step)
        updateCoins(dt: step)
        checkCoinCollisions()
        checkEnemyCollisions()
        checkFlag()

        // Fell into a pit
        if py < -120 {
            hurtPlayer()
        }

        // Camera follows the player horizontally
        let cx = min(max(px, halfW), levelWidth - halfW)
        cam?.position = CGPoint(x: cx, y: halfH)
        player?.position = CGPoint(x: px, y: py)
    }

    // MARK: - Physics

    private func movePlayer(dt: CGFloat) {
        px += vx * dt
        px = min(max(px, playerW / 2), levelWidth - playerW / 2)
        resolvePlayer(horizontal: true)

        py += vy * dt
        onGround = false
        resolvePlayer(horizontal: false)
    }

    private func overlappedTiles(minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) -> [(col: Int, row: Int)] {
        let c0 = max(0, Int(floor(minX / tile)))
        let c1 = min(cols - 1, Int(floor(maxX / tile)))
        let r0 = max(0, Int(floor((levelHeight - maxY) / tile)))
        let r1 = min(rows - 1, Int(floor((levelHeight - minY) / tile)))
        var out: [(col: Int, row: Int)] = []
        guard c1 >= c0, r1 >= r0 else { return out }
        for r in r0...r1 {
            for c in c0...c1 {
                if tiles[r][c].isSolid {
                    out.append((col: c, row: r))
                }
            }
        }
        return out
    }

    private func resolvePlayer(horizontal: Bool) {
        let minX = px - playerW / 2
        let maxX = px + playerW / 2
        let minY = py - playerH / 2
        let maxY = py + playerH / 2
        for (c, r) in overlappedTiles(minX: minX, maxX: maxX, minY: minY, maxY: maxY) {
            let tileMinX = CGFloat(c) * tile
            let tileMaxX = tileMinX + tile
            let tileMaxY = levelHeight - CGFloat(r) * tile
            let tileMinY = tileMaxY - tile
            if horizontal {
                if vx > 0 {
                    px = tileMinX - playerW / 2 - 0.01
                } else if vx < 0 {
                    px = tileMaxX + playerW / 2 + 0.01
                }
                vx = 0
            } else {
                if vy > 0 {
                    // Head bump
                    py = tileMinY - playerH / 2 - 0.01
                    vy = 0
                    bumpTile(col: c, row: r)
                } else if vy <= 0 {
                    // Landed
                    py = tileMaxY + playerH / 2 + 0.01
                    vy = 0
                    onGround = true
                }
            }
        }
    }

    private func bumpTile(col: Int, row: Int) {
        let t = tiles[row][col]
        if t == .question {
            tiles[row][col] = .used
            if let node = tileNodes["\(col),\(row)"] {
                node.color = color(for: .used)
                node.removeAllChildren()
            }
            gameState?.coins += 1
            gameState?.score += 200
            updateHUD()

            let center = tileCenter(col: col, row: row)
            let popup = SKLabelNode(fontNamed: "Helvetica-Bold")
            popup.text = "+200"
            popup.fontSize = 26
            popup.fontColor = .yellow
            popup.position = CGPoint(x: center.x, y: center.y + 50)
            popup.zPosition = 5
            world?.addChild(popup)
            let rise = SKAction.moveBy(x: 0, y: 60, duration: 0.6)
            let fade = SKAction.fadeOut(withDuration: 0.6)
            popup.run(SKAction.sequence([
                SKAction.group([rise, fade]),
                SKAction.removeFromParent()
            ]))
        } else if t == .brick {
            if let node = tileNodes["\(col),\(row)"] {
                let up = SKAction.moveBy(x: 0, y: 12, duration: 0.08)
                node.run(SKAction.sequence([up, up.reversed()]))
            }
        }
    }

    private func updateEnemies(dt: CGFloat) {
        for e in enemies where e.alive {
            e.vy -= gravity * dt
            if e.vy < -maxFall { e.vy = -maxFall }
            e.vx = e.dir * 130

            e.x += e.vx * dt
            if collideEnemyX(e) {
                e.dir *= -1
            }

            e.y += e.vy * dt
            collideEnemyY(e)

            if e.y < -120 {
                e.alive = false
                e.node.removeFromParent()
                continue
            }
            e.node.position = CGPoint(x: e.x, y: e.y)
        }
    }

    private func collideEnemyX(_ e: Enemy) -> Bool {
        var hit = false
        let found = overlappedTiles(
            minX: e.x - e.w / 2, maxX: e.x + e.w / 2,
            minY: e.y - e.h / 2, maxY: e.y + e.h / 2
        )
        for (c, _) in found {
            let tileMinX = CGFloat(c) * tile
            let tileMaxX = tileMinX + tile
            if e.vx > 0 {
                e.x = tileMinX - e.w / 2 - 0.01
            } else if e.vx < 0 {
                e.x = tileMaxX + e.w / 2 + 0.01
            }
            e.vx = 0
            hit = true
        }
        return hit
    }

    private func collideEnemyY(_ e: Enemy) {
        let found = overlappedTiles(
            minX: e.x - e.w / 2, maxX: e.x + e.w / 2,
            minY: e.y - e.h / 2, maxY: e.y + e.h / 2
        )
        for (_, r) in found {
            let tileMaxY = levelHeight - CGFloat(r) * tile
            let tileMinY = tileMaxY - tile
            if e.vy <= 0 {
                e.y = tileMaxY + e.h / 2 + 0.01
                e.vy = 0
            } else {
                e.y = tileMinY - e.h / 2 - 0.01
                e.vy = 0
            }
        }
    }

    private func updateCoins(dt: CGFloat) {
        for coin in coins where !coin.taken {
            coin.t += Double(dt)
            let s = abs(cos(coin.t * 5.0))
            coin.node.xScale = CGFloat(0.25 + 0.75 * s)
        }
    }

    // MARK: - Interactions

    private func checkCoinCollisions() {
        for coin in coins where !coin.taken {
            let p = coin.node.position
            if abs(p.x - px) < 44 && abs(p.y - py) < 50 {
                coin.taken = true
                coin.node.removeFromParent()
                gameState?.coins += 1
                gameState?.score += 100
                updateHUD()
            }
        }
    }

    private func checkEnemyCollisions() {
        for e in enemies where e.alive {
            let overlapX = abs(e.x - px) < (e.w + playerW) / 2 - 6
            let overlapY = abs(e.y - py) < (e.h + playerH) / 2 - 6
            guard overlapX && overlapY else { continue }

            let playerBottom = py - playerH / 2
            let enemyTop = e.y + e.h / 2
            if vy < -50 && playerBottom > enemyTop - 20 {
                // Stomped!
                e.alive = false
                e.node.removeFromParent()
                vy = jumpSpeed * 0.55
                gameState?.score += 200
                updateHUD()
            } else if invTimer <= 0 {
                hurtPlayer()
            }
        }
    }

    private func checkFlag() {
        guard let gs = gameState else { return }
        if px + playerW / 2 >= flagX {
            gs.score += 1000
            updateHUD()
            gs.screen = .win
        }
    }

    private func hurtPlayer() {
        guard let gs = gameState else { return }
        gs.lives -= 1
        updateHUD()
        if gs.lives <= 0 {
            gs.screen = .gameOver
        } else {
            px = spawnX
            py = spawnY
            vx = 0
            vy = 0
            invTimer = 2.0
        }
    }

    // MARK: - Touch controls

    private func tryJump() {
        guard let gs = gameState, gs.screen == .playing else { return }
        if onGround {
            vy = jumpSpeed
            onGround = false
        }
    }

    private func cutJump() {
        if vy > jumpSpeed * 0.45 {
            vy = jumpSpeed * 0.45
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let cam = cam, let gs = gameState, gs.screen == .playing else { return }
        for t in touches {
            let p = t.location(in: cam)
            if let n = leftNode, n.contains(p) {
                touchButtons[t] = .left
                leftHeld = true
            } else if let n = rightNode, n.contains(p) {
                touchButtons[t] = .right
                rightHeld = true
            } else if let n = jumpNode, n.contains(p) {
                touchButtons[t] = .jump
                tryJump()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let cam = cam else { return }
        for t in touches {
            guard let b = touchButtons[t] else { continue }
            let p = t.location(in: cam)
            let node: SKShapeNode?
            switch b {
            case .left: node = leftNode
            case .right: node = rightNode
            case .jump: node = jumpNode
            }
            if let n = node, !n.contains(p) {
                releaseTouch(t, button: b)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if let b = touchButtons[t] {
                releaseTouch(t, button: b)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func releaseTouch(_ t: UITouch, button b: PadButton) {
        switch b {
        case .left: leftHeld = false
        case .right: rightHeld = false
        case .jump: cutJump()
        }
        touchButtons.removeValue(forKey: t)
    }
}
