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

struct GameSpriteView: UIViewRepresentable {
    let gameState: GameState

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        let boundsSize = uiView.bounds.size
        guard boundsSize.width > 1, boundsSize.height > 1 else { return }
        if let scene = uiView.scene as? GameScene {
            scene.fitToView(boundsSize)
        } else if uiView.scene == nil {
            // Size the scene from the real view bounds so it fills the
            // screen exactly on every device (no bars, no cropping).
            let scene = GameScene(size: GameScene.sizeForView(boundsSize))
            scene.scaleMode = .aspectFill
            scene.gameState = gameState
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
