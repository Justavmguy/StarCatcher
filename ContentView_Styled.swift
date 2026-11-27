import SwiftUI

// MARK: - Models

struct FallingItem: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let isHazard: Bool
}

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    let color: Color
}

// MARK: - Shapes & small views

/// Pointed star. 5 points = a star, 8 points with a high innerRatio = a spiky orb.
struct StarShape: Shape {
    var points: Int = 5
    var innerRatio: CGFloat = 0.47

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        var path = Path()
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct StarView: View {
    let size: CGFloat

    var body: some View {
        StarShape()
            .fill(LinearGradient(
                colors: [Color(red: 1.0, green: 0.96, blue: 0.69),
                         Color(red: 1.0, green: 0.72, blue: 0.01)],
                startPoint: .top, endPoint: .bottom))
            .overlay(
                StarShape()
                    .stroke(Color.white.opacity(0.9),
                            style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            )
            .frame(width: size, height: size)
            .shadow(color: Color.yellow.opacity(0.8), radius: 8)
    }
}

struct HazardView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            StarShape(points: 8, innerRatio: 0.7)
                .fill(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.54, blue: 0.6),
                             Color(red: 0.7, green: 0.07, blue: 0.18)],
                    center: .center, startRadius: 0, endRadius: size / 2))
            StarShape(points: 8, innerRatio: 0.7)
                .stroke(Color.orange.opacity(0.9),
                        style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            Circle()
                .fill(Color(red: 0.16, green: 0.02, blue: 0.04))
                .frame(width: size * 0.34, height: size * 0.34)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.red.opacity(0.8), radius: 8)
    }
}

/// Twinkling, slowly drifting stars drawn in a single Canvas.
struct Starfield: View {
    struct Dot {
        let x: Double
        let y: Double
        let size: Double
        let phase: Double
        let speed: Double
    }

    @State private var dots: [Dot] = (0..<70).map { _ in
        Dot(x: .random(in: 0...1),
            y: .random(in: 0...1),
            size: .random(in: 0.8...2.4),
            phase: .random(in: 0...6.28),
            speed: .random(in: 0.01...0.04))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for dot in dots {
                    let y = (dot.y + t * dot.speed).truncatingRemainder(dividingBy: 1)
                    let twinkle = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * 1.6 + dot.phase))
                    context.opacity = twinkle
                    let rect = CGRect(x: dot.x * size.width,
                                      y: y * size.height,
                                      width: dot.size,
                                      height: dot.size)
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

enum Phase {
    case menu, playing, paused
}

struct PillButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(isPrimary ? Color(red: 0.02, green: 0.12, blue: 0.16) : Color.white)
                .frame(minWidth: 170)
                .padding(.vertical, 13)
                .background(fill)
                .overlay(Capsule().stroke(Color.white.opacity(isPrimary ? 0 : 0.25), lineWidth: 1))
                .shadow(color: Color.cyan.opacity(isPrimary ? 0.6 : 0), radius: 10)
        }
    }

    @ViewBuilder private var fill: some View {
        if isPrimary {
            Capsule().fill(LinearGradient(
                colors: [Color(red: 0.56, green: 0.96, blue: 1.0),
                         Color(red: 0.12, green: 0.72, blue: 0.87)],
                startPoint: .top, endPoint: .bottom))
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }
}

/// Big bobbing star for the menu.
struct MenuStar: View {
    @State private var bob = false

    var body: some View {
        StarView(size: 96)
            .rotationEffect(.degrees(bob ? 8 : -8))
            .offset(y: bob ? -8 : 8)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: bob)
            .onAppear { bob = true }
    }
}

// MARK: - Game

struct ContentView: View {
    @AppStorage("highScore") private var highScore: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var playerX: CGFloat = 200
    @State private var items: [FallingItem] = []
    @State private var particles: [Particle] = []
    @State private var score: Int = 0
    @State private var isNewBest: Bool = false
    @State private var isGameOver: Bool = false
    @State private var phase: Phase = .menu
    @State private var showHelp: Bool = false
    @State private var shake: CGFloat = 0
    @State private var screenSize: CGSize = CGSize(width: 390, height: 844)
    @State private var lastSpawnTime: Date = .now
    @State private var lastFrame: Date = .now

    let playerWidth: CGFloat = 80
    let playerHeight: CGFloat = 20
    let itemRadius: CGFloat = 14

    private var shakeOffset: CGSize {
        guard shake > 0 else { return .zero }
        return CGSize(width: CGFloat.random(in: -8...8) * shake,
                      height: CGFloat.random(in: -8...8) * shake)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background

                // Falling stars & hazards
                ForEach(items) { item in
                    Group {
                        if item.isHazard {
                            HazardView(size: itemRadius * 2.3)
                                .rotationEffect(.degrees(-Double(item.y) * 0.9))
                        } else {
                            StarView(size: itemRadius * 2.4)
                                .rotationEffect(.degrees(Double(item.y) * 0.7))
                        }
                    }
                    .position(x: item.x, y: item.y)
                }

                // Sparks
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: 2 + 5 * p.life, height: 2 + 5 * p.life)
                        .opacity(Double(p.life))
                        .position(x: p.x, y: p.y)
                }

                if phase != .menu {
                    paddle(in: geo)
                    hud
                }

                if phase == .menu {
                    menuScreen(in: geo)
                        .transition(.opacity)
                }

                if phase == .paused {
                    pauseCard
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                if isGameOver {
                    gameOverCard(in: geo)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .offset(shakeOffset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard phase == .playing, !isGameOver else { return }
                        let halfWidth = playerWidth / 2
                        playerX = min(max(value.location.x, halfWidth + 10), geo.size.width - halfWidth - 10)
                    }
            )
            .sensoryFeedback(.impact(weight: .light), trigger: score) { old, new in new > old }
            .sensoryFeedback(.error, trigger: isGameOver) { _, new in new }
            .onAppear {
                screenSize = geo.size
                playerX = geo.size.width / 2
                lastFrame = .now
            }
            .onChange(of: geo.size) { _, newSize in
                screenSize = newSize
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active && phase == .playing && !isGameOver {
                    phase = .paused
                }
            }
        }
        // Game loop (movement is time-based, so the exact tick rate doesn't matter)
        .task {
            lastFrame = .now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                updateGame()
            }
        }
    }

    // MARK: Pieces of the UI

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.05, blue: 0.12),
                         Color(red: 0.11, green: 0.09, blue: 0.31)],
                startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Color.cyan.opacity(0.18), Color.clear],
                center: .bottom, startRadius: 10, endRadius: 360)
            Starfield()
        }
        .ignoresSafeArea()
    }

    private func paddle(in geo: GeometryProxy) -> some View {
        Capsule()
            .fill(LinearGradient(
                colors: [Color(red: 0.56, green: 0.96, blue: 1.0),
                         Color(red: 0.12, green: 0.72, blue: 0.87)],
                startPoint: .top, endPoint: .bottom))
            .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: 2))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(height: 4)
                    .padding(.horizontal, 12)
                    .padding(.top, 3)
            }
            .frame(width: playerWidth, height: playerHeight)
            .shadow(color: Color.cyan.opacity(0.7), radius: 12)
            .position(x: playerX, y: geo.size.height - 110)
    }

    private var hud: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Score")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(score)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(score)))
                        .animation(.snappy, value: score)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                Spacer()

                if phase == .playing && !isGameOver {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { phase = .paused }
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Pause")

                    Spacer()
                }

                VStack(alignment: .trailing, spacing: 0) {
                    Text("Best")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.yellow.opacity(0.85))
                    Text("\(highScore)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                        .contentTransition(.numericText(value: Double(highScore)))
                        .animation(.snappy, value: highScore)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()
        }
    }

    private func gameOverCard(in geo: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Game over")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.47))
                    .shadow(color: Color.red.opacity(0.6), radius: 10)

                if isNewBest {
                    Text("★ New high score! ★")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.yellow)
                }

                Text("Score: \(score)")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("Best: \(highScore)")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.yellow)

                VStack(spacing: 10) {
                    PillButton(title: "Play again", isPrimary: true) {
                        restartGame(width: geo.size.width)
                    }
                    PillButton(title: "Menu", isPrimary: false) {
                        goToMenu()
                    }
                }
                .padding(.top, 6)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: Game logic

    private func updateGame() {
        // Delta time: seconds since the last update, capped so a hiccup can't cause a huge jump.
        let now = Date.now
        let dt = CGFloat(min(now.timeIntervalSince(lastFrame), 0.05))
        lastFrame = now

        // Sparks and screen shake keep animating even after game over.
        updateEffects(dt: dt)

        guard phase == .playing, !isGameOver else { return }

        // Spawn new item every 0.65 seconds
        if now.timeIntervalSince(lastSpawnTime) >= 0.65 {
            lastSpawnTime = now
            let randomX = CGFloat.random(in: 30...max(40, screenSize.width - 30))
            let isHazard = Int.random(in: 1...10) <= 3
            items.append(FallingItem(x: randomX, y: -20, isHazard: isHazard))
        }

        // Points per second (300 at score 0, +9 per point), capped so items can't skip the paddle.
        let speedPerSecond = min(300 + CGFloat(score) * 9, 700)
        let distance = speedPerSecond * dt
        let playerY = screenSize.height - 110

        var updatedItems: [FallingItem] = []

        for var item in items {
            item.y += distance

            let hitX = abs(item.x - playerX) < (playerWidth / 2 + itemRadius)
            let hitY = abs(item.y - playerY) < (playerHeight / 2 + itemRadius)

            if hitX && hitY {
                if item.isHazard {
                    burst(at: item.x, item.y, color: .red, count: 28)
                    if !reduceMotion { shake = 1 }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isGameOver = true
                    }
                    return
                } else {
                    burst(at: item.x, item.y, color: .yellow, count: 10)
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

    private func updateEffects(dt: CGFloat) {
        if !particles.isEmpty {
            particles = particles.compactMap { (p: Particle) -> Particle? in
                var q = p
                q.x += q.vx * dt
                q.y += q.vy * dt
                q.vy += 320 * dt
                q.life -= dt * 2
                return q.life > 0 ? q : nil
            }
        }
        if shake > 0 {
            shake = max(0, shake - dt * 3)
        }
    }

    private func burst(at x: CGFloat, _ y: CGFloat, color: Color, count: Int) {
        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * CGFloat.pi))
            let speed = CGFloat.random(in: 60...230)
            particles.append(Particle(x: x, y: y,
                                      vx: cos(angle) * speed,
                                      vy: sin(angle) * speed - 50,
                                      life: 1,
                                      color: color))
        }
    }

    private func menuScreen(in geo: GeometryProxy) -> some View {
        VStack(spacing: 28) {
            Spacer()

            MenuStar()

            VStack(spacing: 6) {
                Text("StarCatcher")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color.cyan.opacity(0.5), radius: 12)
                Text("Best: \(highScore)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(.yellow)
            }

            VStack(spacing: 12) {
                PillButton(title: "Play", isPrimary: true) {
                    startGame(width: geo.size.width)
                }
                PillButton(title: "How to play", isPrimary: false) {
                    showHelp = true
                }
            }

            Spacer()
            Spacer()
        }
        .alert("How to play", isPresented: $showHelp) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Drag to move the paddle. Catch the stars to score. Avoid the red spikes. The game speeds up as your score grows.")
        }
    }

    private var pauseCard: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Paused")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 6)

                PillButton(title: "Resume", isPrimary: true) {
                    resumeGame()
                }
                PillButton(title: "Menu", isPrimary: false) {
                    goToMenu()
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func startGame(width: CGFloat) {
        restartGame(width: width)
        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .playing
        }
    }

    private func resumeGame() {
        lastSpawnTime = .now
        lastFrame = .now
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .playing
        }
    }

    private func goToMenu() {
        items.removeAll()
        particles.removeAll()
        score = 0
        isNewBest = false
        shake = 0
        withAnimation(.easeInOut(duration: 0.25)) {
            isGameOver = false
            phase = .menu
        }
    }

    private func restartGame(width: CGFloat) {
        score = 0
        isNewBest = false
        items.removeAll()
        particles.removeAll()
        shake = 0
        playerX = width / 2
        lastSpawnTime = .now
        lastFrame = .now
        withAnimation(.easeOut(duration: 0.2)) {
            isGameOver = false
        }
    }
}

#Preview {
    ContentView()
}
