import SwiftUI

// MARK: - Test Mode

enum TestMode: String, CaseIterable, Identifiable {
    case flash         = "FLASH"
    case fallingBall   = "CATCH"
    case find          = "FIND"
    case colorTap      = "COLOR"
    case stroop        = "STROOP"
    case reverseStroop = "DECODE"
    case oddOneOut     = "ODD ONE"
    case mirror        = "MIRROR"
    case goNoGo        = "CONTROL"
    case math          = "MATH"
    case antiTap       = "DARK"
    case sequence      = "SEQUENCE"
    case nBack         = "N-BACK"
    case peripheral    = "EDGE"
    case doubleFlash   = "DOUBLE"
    case digitMatch    = "DIGIT"
    case simon         = "SIMON"
    case speedSort     = "SORT"
    case rhythm        = "RHYTHM"
    case dualTrack     = "DUAL"
    case dropArcade    = "DROP"
    case whackArcade   = "WHACK"
    case chainArcade   = "CHAIN"

    var id: String { rawValue }
    var title: String { rawValue }

    var emoji: String {
        switch self {
        case .flash:         return "⚡"
        case .fallingBall:   return "🎯"
        case .find:          return "🔍"
        case .colorTap:      return "🎨"
        case .stroop:        return "🧠"
        case .reverseStroop: return "🔀"
        case .oddOneOut:     return "👁"
        case .mirror:        return "🪞"
        case .goNoGo:        return "🚦"
        case .math:          return "➕"
        case .antiTap:       return "🌑"
        case .sequence:      return "📋"
        case .nBack:         return "💭"
        case .peripheral:    return "📡"
        case .doubleFlash:   return "⚡⚡"
        case .digitMatch:    return "🔢"
        case .simon:         return "↔️"
        case .speedSort:     return "📊"
        case .rhythm:        return "🥁"
        case .dualTrack:     return "👀"
        case .dropArcade:    return "🫳"
        case .whackArcade:   return "🔨"
        case .chainArcade:   return "⛓️"
        }
    }

    var subtitle: String {
        switch self {
        case .flash:         return "Pure speed"
        case .fallingBall:   return "Spatial catch"
        case .find:          return "Visual search"
        case .colorTap:      return "Color match"
        case .stroop:        return "Ignore the word"
        case .reverseStroop: return "Read, not color"
        case .oddOneOut:     return "Spot the difference"
        case .mirror:        return "Tap opposite"
        case .goNoGo:        return "Impulse control"
        case .math:          return "Calculate fast"
        case .antiTap:       return "Tap the dark"
        case .sequence:      return "Repeat pattern"
        case .nBack:         return "1-back memory"
        case .peripheral:    return "Screen edges"
        case .doubleFlash:   return "Wait for two"
        case .digitMatch:    return "Find the number"
        case .simon:         return "Opposite side"
        case .speedSort:     return "Sort fast"
        case .rhythm:        return "Beat timing"
        case .dualTrack:     return "Track two"
        case .dropArcade:    return "Arcade reflex game"
        case .whackArcade:   return "Tap targets fast"
        case .chainArcade:   return "Tap in sequence"
        }
    }

    var instruction: String {
        switch self {
        case .flash:
            return "Tap the moment the circle appears"
        case .fallingBall:
            return "One ball falls — tap it before it hits the bottom"
        case .find:
            return "The target is shown at top. Tap it in the grid"
        case .colorTap:
            return "Tap the circle that matches the color shown at top"
        case .stroop:
            return "Tap the COLOR the word is drawn in — ignore what the word says"
        case .reverseStroop:
            return "The prompt shows a word. Tap the box whose TEXT matches — ignore its color"
        case .oddOneOut:
            return "Three are the same. Tap the one that is different"
        case .mirror:
            return "Tap the OPPOSITE side from the arrow"
        case .goNoGo:
            return "Tap every circle. Do NOT tap the X"
        case .math:
            return "Solve the equation. Tap the correct answer"
        case .antiTap:
            return "The screen will go dark. Tap the moment it does"
        case .sequence:
            return "Watch the sequence, then repeat it in order"
        case .nBack:
            return "Tap if the letter matches the one from 1 trial ago"
        case .peripheral:
            return "A circle appears at the edge of the screen. Tap it fast"
        case .doubleFlash:
            return "Wait for TWO flashes, then tap. One flash = don't tap yet"
        case .digitMatch:
            return "The target number is shown at top. Tap it in the grid"
        case .simon:
            return "Gold = left, White = right. But tap the OPPOSITE side"
        case .speedSort:
            return "Tap the HIGHEST number as fast as you can"
        case .rhythm:
            return "A beat plays — tap when you feel the 4th beat will land"
        case .dualTrack:
            return "Two targets will flash. Tap both in any order"
        case .dropArcade:
            return "5 balls wait at the top. One drops — tap it before it lands. Speed increases. 3 lives."
        case .whackArcade:
            return "Targets pop up around the screen. Tap each one before it disappears. Don't miss or you lose a life."
        case .chainArcade:
            return "Numbered targets appear. Tap them in order — 1, 2, 3... as fast as you can. Wrong tap = life lost."
        }
    }

    var trialCount: Int {
        switch self {
        case .sequence, .nBack: return 6
        case .doubleFlash:      return 4
        default:                return 5
        }
    }

    var tier: Int {
        switch self {
        case .flash, .fallingBall, .antiTap:             return 1
        case .find, .colorTap, .oddOneOut, .goNoGo:      return 2
        case .stroop, .reverseStroop, .mirror, .math:    return 3
        case .sequence, .nBack, .peripheral, .doubleFlash: return 4
        case .digitMatch, .simon, .speedSort, .rhythm, .dualTrack: return 5
        case .dropArcade:                                 return 0
        case .whackArcade:                                return 0
        case .chainArcade:                                return 0
        }
    }

    var isArcade: Bool { self == .dropArcade || self == .whackArcade || self == .chainArcade }
}

// MARK: - Stimulus payload

enum StimulusData {
    // Tier 1
    case flash
    case fallingBall(index: Int, count: Int)
    case antiTap

    // Tier 2
    case find(items: [String], targetIndex: Int)
    case colorTap(colors: [NamedColor], targetIndex: Int)
    case oddOneOut(items: [String], oddIndex: Int, style: OddStyle)
    case goNoGo(isGo: Bool)

    // Tier 3
    case stroop(word: String, textColor: NamedColor, correctAnswer: String)
    case reverseStroop(boxes: [StroopBox], prompt: String, correctIndex: Int)
    case mirror(shown: LRDir, correct: LRDir)
    case math(equation: String, choices: [Int], correctIndex: Int)

    // Tier 4
    case sequence(steps: [Int], isPlayback: Bool, inputSoFar: [Int], activeStep: Int?)
    case nBack(symbol: String, shouldTap: Bool)
    case peripheral(normX: CGFloat, normY: CGFloat)
    case doubleFlash(flashCount: Int)

    // Tier 5
    case digitMatch(items: [Int], targetIndex: Int)
    case simon(color: NamedColor, stimSide: LRDir, correctSide: LRDir)
    case speedSort(numbers: [Int], highestIndex: Int)
    case dualTrack(positions: [DualPos], phase: DualPhase)
}

// MARK: - Supporting types

enum LRDir { case left, right }

enum OddStyle { case letter, number, shape, symbol }

struct NamedColor: Equatable {
    let name: String
    let color: Color

    static let all: [NamedColor] = [
        NamedColor(name: "GOLD",   color: RTheme.gold),
        NamedColor(name: "RED",    color: Color(red: 0.92, green: 0.28, blue: 0.28)),
        NamedColor(name: "BLUE",   color: Color(red: 0.28, green: 0.60, blue: 0.98)),
        NamedColor(name: "GREEN",  color: Color(red: 0.25, green: 0.85, blue: 0.50)),
        NamedColor(name: "PURPLE", color: Color(red: 0.70, green: 0.35, blue: 0.95)),
        NamedColor(name: "WHITE",  color: Color.white),
    ]

    static func random(_ count: Int, excluding: [NamedColor] = []) -> [NamedColor] {
        var pool = all.filter { c in !excluding.contains(c) }
        pool.shuffle()
        return Array(pool.prefix(count))
    }
}

struct StroopBox {
    let text: String
    let backgroundColor: Color
    let textColor: Color
}

struct DualPos {
    let x: CGFloat
    let y: CGFloat
}

enum DualPhase {
    case showFirst(Int)
    case showSecond(Int)
    case awaitTaps([Int])
}

// MARK: - Test Phase

enum TestPhase {
    case idle
    case instruction                        // show mode instructions
    case countdown(Int)
    case waiting
    case stimulus(StimulusData)
    case tooSoon
    case result(ms: Double, trial: Int, total: Int, isError: Bool)
    case sequenceInput(steps: [Int], inputSoFar: [Int], targetSteps: [Int])
    case sessionDone(avg: Double, best: Double, results: [Double])
}
