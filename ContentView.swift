import SwiftUI

struct FallingItem: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let isHazard: Bool
}

struct ContentView: View {
    @AppStorage("highScore") private var highScore: Int = 0

    @State private var playerX: CGFloat = 200
    @State private var items: [FallingItem] = []
    @State private var score: Int = 0
    @State private var isNewBest: Bool = false
    @State private var isGameOver: Bool = false
    @State private var screenSize: CGSize = CGSize(width: 390, height: 844)
    @State private var lastSpawnTime: Date = .now

    let playerWidth: CGFloat = 80
    let playerHeight: CGFloat = 20
    let itemRadius: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.16)
                    .ignoresSafeArea()

                // Falling Stars & Hazards
                ForEach(items) { item in
                    Circle()
                        .fill(item.isHazard ? Color.red : Color.yellow)
                        .overlay(
                            Circle()
                                .stroke(item.isHazard ? Color.orange : Color.white, lineWidth: 2)
                        )
                        .frame(width: itemRadius * 2, height: itemRadius * 2)
                        .position(x: item.x, y: item.y)
                }

                // Player Paddle
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.cyan)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .frame(width: playerWidth, height: playerHeight)
                    .position(x: playerX, y: geo.size.height - 110)

                // Top HUD: Current Score + Saved Best Score
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SCORE")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.7))
                            Text("\(score)")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("BEST")
                                .font(.caption.bold())
                                .foregroundStyle(.yellow.opacity(0.85))
                            Text("\(highScore)")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                    Spacer()
                }

                // Game Over Overlay
                if isGameOver {
                    VStack(spacing: 14) {
                        Text("GAME OVER")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(.red)

                        if isNewBest {
                            Text("★ NEW HIGH SCORE! ★")
                                .font(.subheadline.bold())
                                .foregroundStyle(.yellow)
                        }

                        Text("Score: \(score)")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("Best: \(highScore)")
                            .font(.headline)
                            .foregroundStyle(.yellow)

                        Button("Play Again") {
                            restartGame(width: geo.size.width)
                        }
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.cyan)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                        .padding(.top, 6)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !isGameOver else { return }
                        let halfWidth = playerWidth / 2
                        playerX = min(max(value.location.x, halfWidth + 10), geo.size.width - halfWidth - 10)
                    }
            )
            .onAppear {
                screenSize = geo.size
                playerX = geo.size.width / 2
            }
            .onChange(of: geo.size) { _, newSize in
                screenSize = newSize
            }
        }
        // 60 FPS Game Loop
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                updateGame()
            }
        }
    }

    private func updateGame() {
        guard !isGameOver else { return }

        // Spawn new item every 0.65 seconds
        if Date.now.timeIntervalSince(lastSpawnTime) >= 0.65 {
            lastSpawnTime = .now
            let randomX = CGFloat.random(in: 30...max(40, screenSize.width - 30))
            let isHazard = Int.random(in: 1...10) <= 3
            items.append(FallingItem(x: randomX, y: -20, isHazard: isHazard))
        }

        // Move items & check collisions
        let speed: CGFloat = 5.0 + CGFloat(score) * 0.15
        let playerY = screenSize.height - 110

        var updatedItems: [FallingItem] = []

        for var item in items {
            item.y += speed

            let hitX = abs(item.x - playerX) < (playerWidth / 2 + itemRadius)
            let hitY = abs(item.y - playerY) < (playerHeight / 2 + itemRadius)

            if hitX && hitY {
                if item.isHazard {
                    isGameOver = true
                    return
                } else {
                    score += 1
                    if score > highScore {
                        highScore = score
                        isNewBest = true
                    }
                    continue
                }
            }

            if item.y < screenSize.height + 40 {
                updatedItems.append(item)
            }
        }

        items = updatedItems
    }

    private func restartGame(width: CGFloat) {
        score = 0
        isNewBest = false
        items.removeAll()
        playerX = width / 2
        lastSpawnTime = .now
        isGameOver = false
    }
}

#Preview {
    ContentView()
}

