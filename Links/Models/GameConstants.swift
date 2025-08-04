//
//  GameConstants.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import Foundation

struct GameConstants {
    // MARK: - Game Configuration
    static let maxLives: Int = 10
    static let expectedWordCount: Int = 12
    static let startingWordIndex: Int = 1 // Index of first word to guess (second word in chain)
    
    // MARK: - Animation Timing
    struct Animation {
        static let firstLineTypewriterSpeed: TimeInterval = 0.025
        static let wordChainRevealSpeed: TimeInterval = 0.05
        static let messageWipeSpeedFast: TimeInterval = 0.005
        static let messageWipeSpeedNormal: TimeInterval = 0.015
        static let messageTypeSpeedFast: TimeInterval = 0.008
        static let messageTypeSpeedNormal: TimeInterval = 0.025
        static let gameActivationDelay: TimeInterval = 0.5
        static let gameOverSequenceDelay: TimeInterval = 2.5
        static let countdownUpdateInterval: TimeInterval = 1.0
    }
    
    // MARK: - Date Formats
    struct DateFormats {
        static let storage: String = "yyyy-MM-dd"        // For internal storage and API
        static let display: String = "M/d/yyyy"          // For user-facing display
        static let longDisplay: String = "MMMM d, yyyy"  // For detailed display
    }
    
    // MARK: - Validation
    struct Validation {
        static let minimumWordLength: Int = 2
        static let spellCheckLanguage: String = "en"
    }
    
    // MARK: - Server Error Messages
    struct ServerErrorMessages {
        static let messages = [
            "🤖 Our servers are having a moment. We'll be back soon!",
            "💥 Oops! Our backend decided to take a coffee break.",
            "🛠️ Technical difficulties! Even our code needs therapy sometimes.",
            "🙄 Servers are being dramatic again. Please check back later.",
            "😅 Houston, we have a problem... but we're working on it!",
            "🤦‍♂️ Our servers are playing hide and seek. They're really good at it.",
            "☕ Server maintenance in progress. Blame the developers.",
            "🎭 The servers are having an existential crisis. Give them some time."
        ]
        
        static func randomMessage() -> String {
            return messages.randomElement() ?? messages[0]
        }
    }
}