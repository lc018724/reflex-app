import SwiftUI

// MARK: - Master router

struct StimulusRouter: View {
    let data: StimulusData
    let mode: TestMode
    let engine: TestEngine

    var body: some View {
        switch data {
        case .flash:
            FlashStimulusView()
        case .fallingBall(let index, let count):
            FallingBallView(fallingIndex: index, total: count, engine: engine)
        case .antiTap:
            AntiTapView(engine: engine)
        case .find(let items, let targetIndex):
            FindView(items: items, target: items[targetIndex]) { i in
                engine.handleTap(data: .index(i))
            }
        case .colorTap(let colors, let targetIndex):
            ColorTapView(colors: colors, target: colors[targetIndex]) { i in
                engine.handleTap(data: .index(i))
            }
        case .oddOneOut(let items, _, _):
            OddOneOutView(items: items) { i in
                engine.handleTap(data: .index(i))
            }
        case .goNoGo(let isGo):
            GoNoGoView(isGo: isGo) {
                engine.handleTap()
            }
        case .stroop(let word, let textColor, _):
            StroopView(word: word, textColor: textColor.color, allColors: NamedColor.all) { name in
                engine.handleTap(data: .colorName(name))
            }
        case .reverseStroop(let boxes, let prompt, _):
            ReverseStroopView(boxes: boxes, prompt: prompt) { i in
                engine.handleTap(data: .index(i))
            }
        case .mirror(let shown, _):
            MirrorView(shown: shown) { side in
                engine.handleTap(data: .side(side))
            }
        case .math(let equation, let choices, _):
            MathView(equation: equation, choices: choices) { i in
                engine.handleTap(data: .index(i))
            }
        case .sequence(let steps, let isPlayback, _):
            SequencePlaybackView(steps: steps, isPlayback: isPlayback)
        case .nBack(let symbol, _):
            NBackView(symbol: symbol) {
                engine.handleTap()
            }
        case .peripheral(let nx, let ny):
            PeripheralView(normX: nx, normY: ny) {
                engine.handleTap()
            }
        case .doubleFlash(let count):
            DoubleFlashView(flashCount: count, engine: engine)
        case .digitMatch(let items, let targetIndex):
            DigitMatchView(items: items, target: items[targetIndex]) { i in
                engine.handleTap(data: .index(i))
            }
        case .simon(let color, let stimSide, _):
            SimonView(stimColor: color, stimSide: stimSide) { side in
                engine.handleTap(data: .side(side))
            }
        case .speedSort(let numbers, _):
            SpeedSortView(numbers: numbers) { i in
                engine.handleTap(data: .index(i))
            }
        case .dualTrack:
            FlashStimulusView() // simplified for now
        }
    }
}

// MARK: - Flash

struct FlashStimulusView: View {
    @State private var scale: CGFloat = 0.4

    var body: some View {
        Circle()
            .fill(RTheme.gold)
            .frame(width: 160, height: 160)
            .shadow(color: RTheme.gold.opacity(0.7), radius: 40)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                    scale = 1.0
                }
            }
    }
}

// MARK: - Falling Ball

struct FallingBallView: View {
    let fallingIndex: Int
    let total: Int
    let engine: TestEngine

    @State private var fallProgress: CGFloat = 0
    @State private var tapped = false

    private let ballSize: CGFloat = 44
    private let topY: CGFloat = 0.08
    private let fallDuration: Double = 1.8

    var body: some View {
        GeometryReader { geo in
            let spacing = geo.size.width / CGFloat(total + 1)

            ZStack {
                // Static balls at top
                ForEach(0..<total, id: \.self) { i in
                    if i != fallingIndex {
                        Circle()
                            .fill(RTheme.surface)
                            .overlay(Circle().stroke(RTheme.gold.opacity(0.5), lineWidth: 2))
                            .frame(width: ballSize, height: ballSize)
                            .position(x: spacing * CGFloat(i + 1),
                                      y: geo.size.height * topY)
                    }
                }

                // The falling ball
                if !tapped {
                    Circle()
                        .fill(RTheme.gold)
                        .shadow(color: RTheme.gold.opacity(0.6), radius: 16)
                        .frame(width: ballSize, height: ballSize)
                        .position(
                            x: spacing * CGFloat(fallingIndex + 1),
                            y: geo.size.height * topY + fallProgress * geo.size.height * 0.85
                        )
                        .onTapGesture {
                            tapped = true
                            engine.handleTap(data: .index(fallingIndex))
                        }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            withAnimation(.easeIn(duration: fallDuration)) {
                fallProgress = 1.0
            }
        }
    }
}

// MARK: - Anti-Tap (screen goes dark)

struct AntiTapView: View {
    let engine: TestEngine
    @State private var isLit = true

    var body: some View {
        ZStack {
            (isLit ? RTheme.gold : RTheme.bg)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.06), value: isLit)

            VStack(spacing: 20) {
                if isLit {
                    Text("WAIT...")
                        .font(RTheme.mono(28, weight: .bold))
                        .foregroundStyle(RTheme.bg)
                } else {
                    Text("NOW!")
                        .font(RTheme.mono(28, weight: .bold))
                        .foregroundStyle(RTheme.muted)
                }
            }
        }
        .onAppear {
            let delay = Double.random(in: 0.6...2.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                isLit = false
            }
        }
    }
}

// MARK: - Find

struct FindView: View {
    let items: [String]
    let target: String
    let onTap: (Int) -> Void

    var body: some View {
        VStack(spacing: 40) {
            // Target prompt
            VStack(spacing: 8) {
                Text("TAP")
                    .font(RTheme.mono(11, weight: .medium))
                    .foregroundStyle(RTheme.muted)
                    .tracking(3)
                Text(target)
                    .font(RTheme.mono(56, weight: .bold))
                    .foregroundStyle(RTheme.gold)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(RTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
            .padding(.horizontal, 32)

            // Grid of choices
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.0) { i, item in
                    Button { onTap(i) } label: {
                        Text(item)
                            .font(RTheme.mono(44, weight: .bold))
                            .foregroundStyle(RTheme.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(RTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Color Tap

struct ColorTapView: View {
    let colors: [NamedColor]
    let target: NamedColor
    let onTap: (Int) -> Void

    var body: some View {
        VStack(spacing: 36) {
            VStack(spacing: 8) {
                Text("TAP")
                    .font(RTheme.mono(11, weight: .medium))
                    .foregroundStyle(RTheme.muted)
                    .tracking(3)
                Text(target.name)
                    .font(RTheme.mono(36, weight: .bold))
                    .foregroundStyle(target.color)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(Array(colors.enumerated()), id: \.0) { i, nc in
                    Button { onTap(i) } label: {
                        Circle()
                            .fill(nc.color)
                            .frame(width: 110, height: 110)
                            .shadow(color: nc.color.opacity(0.5), radius: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Stroop

struct StroopView: View {
    let word: String
    let textColor: Color
    let allColors: [NamedColor]
    let onTap: (String) -> Void

    var body: some View {
        VStack(spacing: 36) {
            VStack(spacing: 8) {
                Text("TAP THE COLOR IT'S DRAWN IN")
                    .font(RTheme.mono(10, weight: .medium))
                    .foregroundStyle(RTheme.muted)
                    .tracking(2)
                    .multilineTextAlignment(.center)
                Text(word)
                    .font(RTheme.mono(56, weight: .bold))
                    .foregroundStyle(textColor)
            }

            // Color buttons (showing 4 random including the answer)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(allColors.prefix(4), id: \.name) { nc in
                    Button { onTap(nc.name) } label: {
                        Text(nc.name)
                            .font(RTheme.mono(16, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(RTheme.bg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(nc.color)
                            .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Reverse Stroop (Lucky's example 2)

struct ReverseStroopView: View {
    let boxes: [StroopBox]
    let prompt: String
    let onTap: (Int) -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("TAP THE BOX THAT SAYS")
                    .font(RTheme.mono(10, weight: .medium))
                    .foregroundStyle(RTheme.muted)
                    .tracking(2)
                Text(prompt)
                    .font(RTheme.mono(44, weight: .bold))
                    .foregroundStyle(RTheme.gold)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(Array(boxes.enumerated()), id: \.0) { i, box in
                    Button { onTap(i) } label: {
                        Text(box.text)
                            .font(RTheme.mono(20, weight: .bold))
                            .foregroundStyle(box.textColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 88)
                            .background(box.backgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Odd One Out

struct OddOneOutView: View {
    let items: [String]
    let onTap: (Int) -> Void

    var body: some View {
        VStack(spacing: 32) {
            Text("TAP THE ODD ONE OUT")
                .font(RTheme.mono(11, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(3)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.0) { i, item in
                    Button { onTap(i) } label: {
                        Text(item)
                            .font(RTheme.mono(48, weight: .bold))
                            .foregroundStyle(RTheme.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .background(RTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Go / No-Go

struct GoNoGoView: View {
    let isGo: Bool
    let onTap: () -> Void

    @State private var scale: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(isGo ? RTheme.gold : RTheme.red.opacity(0.15))
                    .frame(width: 180, height: 180)
                    .shadow(color: (isGo ? RTheme.gold : RTheme.red).opacity(0.5), radius: 30)

                if isGo {
                    Circle().fill(RTheme.gold).frame(width: 100, height: 100)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 72, weight: .black))
                        .foregroundStyle(RTheme.red)
                }
            }
            .scaleEffect(scale)
            .onTapGesture { if isGo { onTap() } else { onTap() } }
            .onAppear {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { scale = 1.0 }
            }

            Text(isGo ? "TAP NOW" : "DON'T TAP")
                .font(RTheme.mono(14, weight: .bold))
                .foregroundStyle(isGo ? RTheme.gold : RTheme.red)
                .tracking(4)
        }
    }
}

// MARK: - Mirror

struct MirrorView: View {
    let shown: LRDir
    let onTap: (LRDir) -> Void

    var body: some View {
        VStack(spacing: 40) {
            Text("TAP THE OPPOSITE SIDE")
                .font(RTheme.mono(11, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(2)

            Image(systemName: shown == .left ? "arrow.left" : "arrow.right")
                .font(.system(size: 80, weight: .black))
                .foregroundStyle(RTheme.gold)

            HStack(spacing: 24) {
                sideButton(.left)
                sideButton(.right)
            }
            .padding(.horizontal, 32)
        }
    }

    private func sideButton(_ side: LRDir) -> some View {
        Button { onTap(side) } label: {
            Image(systemName: side == .left ? "arrow.left" : "arrow.right")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(RTheme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(RTheme.gold)
                .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Math

struct MathView: View {
    let equation: String
    let choices: [Int]
    let onTap: (Int) -> Void

    var body: some View {
        VStack(spacing: 36) {
            Text(equation)
                .font(RTheme.mono(64, weight: .bold))
                .foregroundStyle(RTheme.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(Array(choices.enumerated()), id: \.0) { i, n in
                    Button { onTap(i) } label: {
                        Text("\(n)")
                            .font(RTheme.mono(36, weight: .bold))
                            .foregroundStyle(RTheme.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 88)
                            .background(RTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Sequence Playback

struct SequencePlaybackView: View {
    let steps: [Int]
    let isPlayback: Bool

    private let labels = ["1","2","3","4"]
    private let colors: [Color] = [RTheme.gold, RTheme.green, RTheme.red,
                                    Color(red: 0.55, green: 0.35, blue: 0.95)]

    var body: some View {
        VStack(spacing: 24) {
            Text(isPlayback ? "WATCH THE SEQUENCE" : "REPEAT IT")
                .font(RTheme.mono(12, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(3)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: RTheme.radiusSm)
                        .fill(colors[i])
                        .frame(height: 110)
                        .overlay(
                            Text(labels[i])
                                .font(RTheme.mono(32, weight: .bold))
                                .foregroundStyle(RTheme.bg)
                        )
                }
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Sequence Input

struct SequenceInputView: View {
    let steps: [Int]
    let inputSoFar: [Int]
    let targetSteps: [Int]
    let engine: TestEngine

    private let labels = ["1","2","3","4"]
    private let colors: [Color] = [RTheme.gold, RTheme.green, RTheme.red,
                                    Color(red: 0.55, green: 0.35, blue: 0.95)]

    var body: some View {
        VStack(spacing: 24) {
            Text("YOUR TURN — \(inputSoFar.count)/\(targetSteps.count)")
                .font(RTheme.mono(12, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(3)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Button { engine.handleSequenceInput(index: i) } label: {
                        RoundedRectangle(cornerRadius: RTheme.radiusSm)
                            .fill(colors[i])
                            .frame(height: 110)
                            .overlay(
                                Text(labels[i])
                                    .font(RTheme.mono(32, weight: .bold))
                                    .foregroundStyle(RTheme.bg)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - N-Back

struct NBackView: View {
    let symbol: String
    let onTap: () -> Void

    @State private var scale: CGFloat = 0.6

    var body: some View {
        VStack(spacing: 32) {
            Text("TAP IF THIS MATCHES 1 AGO")
                .font(RTheme.mono(10, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(2)
                .multilineTextAlignment(.center)

            Text(symbol)
                .font(RTheme.mono(120, weight: .bold))
                .foregroundStyle(RTheme.gold)
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { scale = 1.0 }
                }

            Button(action: onTap) {
                Text("MATCH")
                    .font(RTheme.rounded(18, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(RTheme.bg)
                    .frame(width: 200, height: 56)
                    .background(RTheme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: RTheme.radius))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Peripheral

struct PeripheralView: View {
    let normX: CGFloat
    let normY: CGFloat
    let onTap: () -> Void

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Text("WATCH THE EDGES")
                    .font(RTheme.mono(12))
                    .foregroundStyle(RTheme.muted.opacity(0.4))
                    .tracking(3)

                if appeared {
                    Circle()
                        .fill(RTheme.gold)
                        .shadow(color: RTheme.gold.opacity(0.8), radius: 20)
                        .frame(width: 52, height: 52)
                        .position(x: geo.size.width * normX,
                                  y: geo.size.height * normY)
                        .transition(.scale(scale: 0.1).combined(with: .opacity))
                        .onTapGesture { onTap() }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.spring(response: 0.2)) { appeared = true }
        }
    }
}

// MARK: - Double Flash

struct DoubleFlashView: View {
    let flashCount: Int
    let engine: TestEngine

    @State private var bgColor: Color = RTheme.bg

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 16) {
                Text(flashCount == 0 ? "WAIT FOR TWO FLASHES" : "ONE MORE...")
                    .font(RTheme.mono(14, weight: .medium))
                    .foregroundStyle(RTheme.muted)
                    .tracking(3)

                HStack(spacing: 12) {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .fill(i < flashCount ? RTheme.gold : RTheme.faint)
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .onAppear {
            scheduleNextFlash()
        }
        .onChange(of: flashCount) { _ in
            flash()
            if flashCount < 2 { scheduleNextFlash() }
        }
    }

    private func scheduleNextFlash() {
        let delay = Double.random(in: 0.8...1.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            engine.advanceDoubleFlash()
        }
    }

    private func flash() {
        withAnimation(.easeOut(duration: 0.05)) { bgColor = RTheme.gold }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.1)) { bgColor = RTheme.bg }
        }
    }
}

// MARK: - Digit Match

struct DigitMatchView: View {
    let items: [Int]
    let target: Int
    let onTap: (Int) -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("TAP")
                    .font(RTheme.mono(11, weight: .medium))
                    .foregroundStyle(RTheme.muted)
                    .tracking(3)
                Text("\(target)")
                    .font(RTheme.mono(64, weight: .bold))
                    .foregroundStyle(RTheme.gold)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.0) { i, digit in
                    Button { onTap(i) } label: {
                        Text("\(digit)")
                            .font(RTheme.mono(40, weight: .bold))
                            .foregroundStyle(RTheme.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(RTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Simon

struct SimonView: View {
    let stimColor: NamedColor
    let stimSide: LRDir
    let onTap: (LRDir) -> Void

    var body: some View {
        VStack(spacing: 40) {
            Text("TAP THE OPPOSITE SIDE")
                .font(RTheme.mono(11, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(2)

            HStack(spacing: 20) {
                let leftActive = stimSide == .left
                Circle()
                    .fill(leftActive ? stimColor.color : RTheme.surface)
                    .shadow(color: leftActive ? stimColor.color.opacity(0.6) : .clear, radius: 20)
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(!leftActive ? stimColor.color : RTheme.surface)
                    .shadow(color: !leftActive ? stimColor.color.opacity(0.6) : .clear, radius: 20)
                    .frame(width: 100, height: 100)
            }

            HStack(spacing: 24) {
                Button { onTap(.left) } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(RTheme.bg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(RTheme.gold)
                        .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                }
                .buttonStyle(.plain)
                Button { onTap(.right) } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(RTheme.bg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(RTheme.gold)
                        .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Speed Sort

struct SpeedSortView: View {
    let numbers: [Int]
    let onTap: (Int) -> Void

    var body: some View {
        VStack(spacing: 32) {
            Text("TAP THE HIGHEST NUMBER")
                .font(RTheme.mono(11, weight: .medium))
                .foregroundStyle(RTheme.muted)
                .tracking(2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(Array(numbers.enumerated()), id: \.0) { i, n in
                    Button { onTap(i) } label: {
                        Text("\(n)")
                            .font(RTheme.mono(52, weight: .bold))
                            .foregroundStyle(RTheme.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(RTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: RTheme.radiusSm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
        }
    }
}
