import SwiftUI
import UIKit
import SpriteKit

// MARK: - Shared game state (SwiftUI <-> SpriteKit bridge)

final class GameState: ObservableObject {
    enum Screen {
        case menu, playing, win, gameOver
    }

    @Published var screen: Screen = .menu
    @Published var score: Int = 0
    @Published var coins: Int = 0
    @Published var lives: Int = 3

    weak var scene: GameScene?

    func startGame() {
        score = 0
        coins = 0
        lives = 3
        scene?.startNewGame()
        screen = .playing
    }
}

// MARK: - Root view

struct ContentView: View {
    @StateObject private var gameState = GameState()

    var body: some View {
        ZStack {
            // Same sky color as the game, so there's never a black flash
            // or letterbox bars around the game view.
            Color(red: 0.45, green: 0.75, blue: 1.0).ignoresSafeArea()

            GameSpriteView(gameState: gameState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            if gameState.screen == .menu {
                MenuOverlay(gameState: gameState)
            } else if gameState.screen == .win {
                EndOverlay(
                    title: "YOU WIN!",
                    subtitle: "Score: \(gameState.score)  •  Coins: \(gameState.coins)",
                    buttonTitle: "↻  PLAY AGAIN",
                    gameState: gameState
                )
            } else if gameState.screen == .gameOver {
                EndOverlay(
                    title: "GAME OVER",
                    subtitle: "Score: \(gameState.score)",
                    buttonTitle: "↻  TRY AGAIN",
                    gameState: gameState
                )
            }
        }
    }
}

// MARK: - SpriteKit view wrapper

/// SKView that re-fits the game scene every time its bounds change
/// (first layout, rotation, split view, ...).
final class GameSKView: SKView {
    override func layoutSubviews() {
        super.layoutSubviews()
        let s = bounds.size
        guard s.width > 1, s.height > 1 else { return }
        (scene as? GameScene)?.fitToView(s)
    }
}

struct GameSpriteView: UIViewRepresentable {
    let gameState: GameState

    /// Builds a ready-to-play scene with a guaranteed-valid size.
    /// UIScreen.main.bounds is always real here, unlike the view's own
    /// bounds which are still .zero at this point.
    private func makeScene() -> GameScene {
        let screenSize = UIScreen.main.bounds.size
        let scene = GameScene(size: GameScene.sizeForView(screenSize))
        scene.scaleMode = .aspectFill
        scene.gameState = gameState
        return scene
    }

    func makeUIView(context: Context) -> GameSKView {
        let view = GameSKView()
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        // Present immediately: updateUIView is not guaranteed to run again
        // after layout, so the scene must exist from the very start.
        let scene = makeScene()
        gameState.scene = scene
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ uiView: GameSKView, context: Context) {
        // Safety net: if the scene was somehow lost, restore it.
        if uiView.scene == nil {
            let scene = makeScene()
            gameState.scene = scene
            uiView.presentScene(scene)
        }
    }
}

// MARK: - Overlays

struct MenuOverlay: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("MARIO GAME")
                    .font(.system(size: 64, weight: .black))
                    .foregroundColor(.white)
                Text("Run, jump, stomp the enemies,\ngrab coins and reach the flag!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.85))
                Button("▶  PLAY") {
                    gameState.startGame()
                }
                .font(.system(size: 32, weight: .bold))
                .padding(.horizontal, 48)
                .padding(.vertical, 16)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
        }
    }
}

struct EndOverlay: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    @ObservedObject var gameState: GameState

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 56, weight: .black))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
                Button(buttonTitle) {
                    gameState.startGame()
                }
                .font(.system(size: 28, weight: .bold))
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
        }
    }
}
