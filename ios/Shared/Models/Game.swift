import Foundation

enum GameID: String, Codable, CaseIterable {
    case trivia       = "trivia"
    case poker        = "poker"
    case tambola      = "tambola"
    case mafia        = "mafia"
    case heist        = "heist"
    case stockPanic   = "stock_panic"
    case mindMeld     = "mind_meld"
    case hotGrid      = "hot_grid"
    case speedSculptor = "speed_sculptor"
    case pong         = "pong"
    case connectFour  = "connect4"
    case chess        = "chess"
    case snakeLadder  = "snake_ladder"
    case roulette     = "roulette"
    case rajaMantri   = "raja_mantri"
    case memory       = "memory"
    case digitGuess   = "digit_guess"

    var displayName: String {
        switch self {
        case .trivia:        return "Trivia"
        case .poker:         return "Poker"
        case .tambola:       return "Tambola"
        case .mafia:         return "Mafia"
        case .heist:         return "Heist"
        case .stockPanic:    return "Stock Panic"
        case .mindMeld:      return "Mind Meld"
        case .hotGrid:       return "Hot Grid"
        case .speedSculptor: return "Speed Sculptor"
        case .pong:          return "Pong"
        case .connectFour:   return "Connect 4"
        case .chess:         return "Chess"
        case .snakeLadder:   return "Snake & Ladder"
        case .roulette:      return "Roulette"
        case .rajaMantri:    return "Raja Mantri"
        case .memory:        return "Memory"
        case .digitGuess:    return "Digit Guess"
        }
    }

    var emoji: String {
        switch self {
        case .trivia:        return "🧠"
        case .poker:         return "🃏"
        case .tambola:       return "🎱"
        case .mafia:         return "🕵️"
        case .heist:         return "🏦"
        case .stockPanic:    return "📈"
        case .mindMeld:      return "🔮"
        case .hotGrid:       return "💣"
        case .speedSculptor: return "🎨"
        case .pong:          return "🏓"
        case .connectFour:   return "🟡"
        case .chess:         return "♟️"
        case .snakeLadder:   return "🎲"
        case .roulette:      return "🎡"
        case .rajaMantri:    return "👑"
        case .memory:        return "🧩"
        case .digitGuess:    return "🔢"
        }
    }

    var category: GameCategory {
        switch self {
        case .trivia, .mindMeld, .digitGuess:
            return .knowledge
        case .poker, .roulette, .tambola:
            return .casino
        case .mafia, .heist, .rajaMantri:
            return .social
        case .stockPanic, .hotGrid, .connectFour, .chess, .snakeLadder, .memory:
            return .strategy
        case .speedSculptor:
            return .creative
        case .pong:
            return .action
        }
    }

    var minPlayers: Int {
        switch self {
        case .pong:          return 2
        case .poker:         return 2
        case .chess:         return 2
        case .connectFour:   return 2
        case .digitGuess:    return 2
        case .snakeLadder:   return 2
        case .roulette:      return 1
        case .memory:        return 2
        case .tambola:       return 2
        case .trivia:        return 2
        case .mafia:         return 5
        case .heist:         return 3
        case .hotGrid:       return 2
        case .stockPanic:    return 2
        case .mindMeld:      return 3
        case .speedSculptor: return 3
        case .rajaMantri:    return 4
        }
    }

    var maxPlayers: Int {
        switch self {
        case .pong:          return 2
        case .chess:         return 2
        case .connectFour:   return 2
        case .digitGuess:    return 4
        case .poker:         return 8
        case .roulette:      return 8
        case .snakeLadder:   return 6
        case .memory:        return 4
        case .tambola:       return 20
        case .trivia:        return 10
        case .mafia:         return 15
        case .heist:         return 6
        case .hotGrid:       return 8
        case .stockPanic:    return 6
        case .mindMeld:      return 8
        case .speedSculptor: return 8
        case .rajaMantri:    return 4
        }
    }

    // Phone is the controller; TV is the board.
    // Some games have asymmetric info (private phone screen matters).
    var hasPrivateInfo: Bool {
        switch self {
        case .poker, .mafia, .heist, .rajaMantri, .tambola:
            return true
        default:
            return false
        }
    }

    var phoneInputStyle: PhoneInputStyle {
        switch self {
        case .pong:                       return .tilt
        case .speedSculptor:              return .draw
        case .trivia, .hotGrid, .memory,
             .connectFour, .mindMeld,
             .digitGuess, .mafia, .heist,
             .rajaMantri, .tambola:       return .tap
        case .poker, .roulette,
             .stockPanic:                 return .swipe
        case .chess, .snakeLadder:        return .tapGrid
        }
    }
}

enum GameCategory: String, CaseIterable {
    case knowledge = "Knowledge"
    case casino    = "Casino"
    case social    = "Social"
    case strategy  = "Strategy"
    case creative  = "Creative"
    case action    = "Action"
}

enum PhoneInputStyle {
    case tap        // single tap on options
    case tapGrid    // tap cells in a grid
    case swipe      // swipe gestures / sliders
    case draw       // drawing canvas
    case tilt       // gyroscope / accelerometer
}
