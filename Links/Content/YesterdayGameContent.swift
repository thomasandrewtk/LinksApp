//
//  YesterdayGameContent.swift
//  Links
//
//  Created by Assistant on 2025-01-14.
//

import SwiftUI
import Combine
import UIKit

/// Manages the content display for yesterday's puzzle
class YesterdayGameContent: ObservableObject {
    // MARK: - Terminal
    var terminal: TerminalViewModel?
    @Published var isActive: Bool = false
    
    // MARK: - Game State
    @Published var currentLives: Int = GameConstants.maxLives
    @Published var currentGuess: String = ""
    @Published var hasServerError: Bool = false
    
    // Computed property to check if game is completed
    var isGameCompleted: Bool {
        currentGameCompletion?.isCompleted ?? false
    }
    
    // MARK: - State Management
    private var isResetting: Bool = false
    private var currentPuzzleDate: String?
    
    // MARK: - Services
    private let puzzleService = PuzzleService.shared
    private let completionService = GameCompletionService.shared
    
    // MARK: - Game Data
    private var fullWords: [String] = []
    private var wordChain: [String] = []
    private var currentWordIndex: Int = GameConstants.startingWordIndex
    private var revealedLetters: [Int: Int] = [:]
    private var currentGameCompletion: GameCompletion?
    
    // MARK: - Display Lines
    private struct DisplayLines {
        static let firstLine = 1
        static let wordChainStart = 3
        static let promptLine = 18
        static let streakLine = 20
        static let navigationLine = 22
    }
    
    // MARK: - Message Arrays (yesterday-specific)
    private let nextWordMessages = [
        "🤔 What word came after",
        "🧐 Yesterday, what followed",
        "🤓 Alright genius, what came after",
        "😏 Think you can guess what followed",
        "🙄 Obviously, what came after"
    ]
    
    private let incorrectMessages = [
        "🙄 Nope! Here's a hint:",
        "😬 Wrong! Take this hint:",
        "🤦‍♂️ Not quite! Hint time:",
        "😅 Oops! Here's some help:",
        "🫤 Incorrect! Throwing you a bone:"
    ]
    
    private let gameOverMessages = [
        "💀 Game Over! At least today's fresh!",
        "😵 Yikes! Better luck with today's puzzle.",
        "🪦 RIP. Today awaits you!",
        "😬 Oof. Try today's game instead!",
        "💔 Game Over! Today's puzzle is ready!"
    ]
    
    private let victoryMessages = [
        "🎉 Holy cow! You solved yesterday's puzzle!",
        "🤯 Wow! Yesterday defeated at last!",
        "👏 Impressive! Yesterday conquered!",
        "🥳 Look who caught up on yesterday!",
        "🏆 Victory! Yesterday's puzzle crushed!"
    ]
    
    private let invalidWordMessages = [
        "🤨 That's not a real word! Try again.",
        "😕 Invalid word! Check your spelling.",
        "🔤 Not in my dictionary! Try another.",
        "📚 That word doesn't exist! Keep trying.",
        "❓ Not a valid word! Give it another shot."
    ]
    
    private let backToTodayMessages = [
        "🕰️ Ready for [today]'s puzzle? Tap to play!",
        "⏮️ [Today]'s fresh challenge awaits!",
        "🎯 Time for [today]'s game!",
        "📅 Jump back to [today]'s puzzle!",
        "🎮 [Today]'s challenge is ready!"
    ]
    
    // Track last used messages
    private var lastNextWordMessage: String = ""
    private var lastIncorrectMessage: String = ""
    private var lastGameOverMessage: String = ""
    private var lastVictoryMessage: String = ""
    private var lastInvalidWordMessage: String = ""
    private var lastBackToTodayMessage: String = ""
    
    // MARK: - Timers
    private var gameOverTimer: Timer?
    private var readinessTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // No reactive bindings for yesterday's content - it's static once loaded
    }
    
    func configure(with terminal: TerminalViewModel) {
        self.terminal = terminal
        print("🔗 YesterdayGameContent: Configured with terminal")
    }
    
    // MARK: - Helper Methods
    /// Get a random message avoiding the last used one
    func getRandomMessage(from messages: [String], excluding lastMessage: String) -> String {
        let availableMessages = messages.filter { $0 != lastMessage }
        return availableMessages.randomElement() ?? messages.randomElement() ?? messages[0]
    }
    
    // MARK: - Game Flow
    func start() {
        guard let terminal = terminal else {
            print("❌ YesterdayGameContent: Terminal not configured!")
            return
        }
        
        isActive = true
        print("🎮 YesterdayGameContent: Starting yesterday's game...")
        terminal.clearAllImmediate()
        
        // Wait for SwiftData to be ready before loading
        waitForSwiftDataAndLoadPuzzle()
    }
    
    private func waitForSwiftDataAndLoadPuzzle() {
        // Check if SwiftData is already ready
        if completionService.isReady {
            print("✅ SwiftData ready immediately, loading yesterday's puzzle")
            loadYesterdaysPuzzle()
            return
        }
        
        // Otherwise, poll until it's ready
        print("⏳ Waiting for SwiftData to be ready...")
        readinessTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                if self.completionService.isReady {
                    print("✅ SwiftData ready, loading yesterday's puzzle")
                    self.readinessTimer?.invalidate()
                    self.readinessTimer = nil
                    self.loadYesterdaysPuzzle()
                }
            }
        }
    }
    
    private func loadYesterdaysPuzzle() {
        print("📦 Loading yesterday's puzzle...")
        let yesterdayDate = GameCompletion.yesterdayDateString()
        
        Task {
            do {
                let puzzle = try await puzzleService.fetchPuzzleForDate(yesterdayDate)
                await MainActor.run {
                    print("✅ Fetched yesterday's puzzle successfully")
                    self.setupWithPuzzle(puzzle)
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to fetch yesterday's puzzle: \(error)")
                    self.showServerError()
                }
            }
        }
    }
    
    private func setupWithPuzzle(_ puzzle: DailyPuzzle) {
        // Check if puzzle is already configured
        if currentPuzzleDate == puzzle.date && !fullWords.isEmpty {
            print("⏭️ Puzzle \(puzzle.date) already configured")
            
            // If returning to a completed game, show the completed state
            if let completion = currentGameCompletion, completion.isCompleted {
                print("🔄 Returning to completed yesterday game - showing completed state")
                startCompletedGameDisplay()
                return
            } else {
                print("⏭️ Active game already configured, skipping duplicate setup")
                return
            }
        }
        
        print("🎲 Setting up yesterday's puzzle for date: \(puzzle.date)")
        currentPuzzleDate = puzzle.date
        fullWords = puzzle.words
        
        // Get or create completion record
        if let existingCompletion = completionService.getGameCompletion(for: puzzle.date) {
            currentGameCompletion = existingCompletion
            print("📝 Found existing game completion for yesterday")
            
            if existingCompletion.isCompleted {
                setupCompletedGameState(from: existingCompletion)
            } else {
                restoreGameState(from: existingCompletion)
            }
        } else {
            currentGameCompletion = completionService.createGameCompletion(for: puzzle.date, totalWords: puzzle.words.count)
            setupInitialGameState()
            print("🆕 Created new game completion for yesterday")
        }
        
        // Start animation sequence
        print("🎬 Starting yesterday's game animation sequence...")
        startGameAnimation()
    }
    
    private func setupInitialGameState() {
        wordChain = Array(repeating: "", count: fullWords.count)
        revealedLetters = [:]
        
        // Initialize revealed letters
        for (index, _) in fullWords.enumerated() {
            if index != 0 && index != fullWords.count - 1 {
                revealedLetters[index] = 1
            }
        }
    }
    
    private func restoreGameState(from completion: GameCompletion) {
        currentLives = GameConstants.maxLives - completion.livesUsed
        currentWordIndex = completion.currentWordIndex
        revealedLetters = completion.revealedLetters
        setupInitialGameState()
    }
    
    private func setupCompletedGameState(from completion: GameCompletion) {
        currentLives = GameConstants.maxLives - completion.livesUsed
        currentWordIndex = completion.currentWordIndex
        revealedLetters = completion.revealedLetters
        isActive = false
        setupInitialGameState()
    }
    
    // MARK: - Animation Sequence
    private func startGameAnimation() {
        guard let terminal = terminal else {
            print("❌ Cannot start animation - terminal not configured")
            return
        }
        
        // Clear reset flag once animation begins (prevents reactive binding interference)
        isResetting = false
        
        let dateString = getYesterdayPuzzleDate()
        let firstLineMessage = "Playing yesterday's puzzle: \(dateString)"
        
        print("🧪 DEBUG: Starting first line animation for yesterday")
        
        // Use a single command that chains both operations
        terminal.writeLine(DisplayLines.firstLine, content: firstLineMessage)
        terminal.onCompletion { [weak self] in
            print("🧪 DEBUG: Yesterday first line completion handler called!")
            DispatchQueue.main.async {
                self?.animateWordChain()
            }
        }
        
        print("🧪 DEBUG: Yesterday commands queued")
    }
    
    private func animateWordChain() {
        guard let terminal = terminal else {
            print("❌ Cannot animate word chain - terminal not configured")
            return
        }
        
        print("🧪 DEBUG: animateWordChain called for yesterday")
        print("🧪 DEBUG: fullWords count = \(fullWords.count)")
        print("🧪 DEBUG: fullWords = \(fullWords)")
        
        guard !fullWords.isEmpty else {
            print("❌ Cannot animate word chain - fullWords is empty!")
            // Still call showGamePrompt to continue the sequence
            showGamePrompt()
            return
        }
        
        let targetWords = buildWordChainTarget()
        print("🧪 DEBUG: targetWords count = \(targetWords.count)")
        print("🧪 DEBUG: targetWords = \(targetWords)")
        
        // Create parallel animations for all words
        var parallelCommands: [TerminalViewModel.AnimationCommand] = []
        
        for (index, word) in targetWords.enumerated() {
            let lineIndex = DisplayLines.wordChainStart + index
            print("🧪 DEBUG: Adding word '\(word)' to line \(lineIndex)")
            parallelCommands.append(.writeLine(lineIndex: lineIndex, content: word, speed: GameConstants.Animation.wordChainRevealSpeed))
        }
        
        print("🧪 DEBUG: parallelCommands count = \(parallelCommands.count)")
        
        if parallelCommands.isEmpty {
            print("❌ No parallel commands to execute - calling showGamePrompt directly")
            showGamePrompt()
            return
        }
        
        terminal.parallel(parallelCommands)
        
        // After word chain, show appropriate prompt
        terminal.onCompletion { [weak self] in
            print("🧪 DEBUG: Yesterday word chain completion handler called!")
            self?.showGamePrompt()
        }
    }
    
    private func buildWordChainTarget() -> [String] {
        var targetWords: [String] = []
        
        for (index, word) in fullWords.enumerated() {
            var displayWord = ""
            
            if index == 0 || index == fullWords.count - 1 {
                displayWord = word
            } else if index < currentWordIndex {
                displayWord = word
            } else if index == currentWordIndex {
                let revealedCount = revealedLetters[index] ?? 1
                let revealedPart = String(word.prefix(revealedCount))
                let hiddenPart = String(repeating: "_", count: word.count - revealedCount)
                displayWord = revealedPart + hiddenPart
            } else {
                let hiddenWord = String(word.prefix(1)) + String(repeating: "_", count: word.count - 1)
                displayWord = hiddenWord
            }
            
            // Add status indicator
            let status = getWordStatus(for: index)
            switch status {
            case .completed:
                displayWord += " ✓"
            case .incomplete:
                displayWord += " ✗"
            case .inProgress, .notStarted:
                break
            }
            
            targetWords.append(displayWord)
        }
        
        return targetWords
    }
    
    // MARK: - Word Status
    private enum WordStatus {
        case completed
        case incomplete
        case inProgress
        case notStarted
    }
    
    private func getWordStatus(for index: Int) -> WordStatus {
        // First and last words don't show indicators
        if index == 0 || index == fullWords.count - 1 {
            return .notStarted
        }
        
        // Check if all letters are revealed
        func isWordFullyRevealed(at wordIndex: Int) -> Bool {
            guard wordIndex < fullWords.count else { return false }
            let word = fullWords[wordIndex]
            let revealedCount = revealedLetters[wordIndex] ?? 1
            return revealedCount >= word.count
        }
        
        // If the game is completed
        if let completion = currentGameCompletion, completion.isCompleted {
            if index < currentWordIndex {
                return .completed
            } else if isWordFullyRevealed(at: index) {
                return .completed
            } else {
                return .incomplete
            }
        }
        
        // For active games
        if index < currentWordIndex {
            return .completed
        } else if isWordFullyRevealed(at: index) {
            return .completed
        } else if index == currentWordIndex {
            return .inProgress
        } else {
            return .notStarted
        }
    }
    
    private func showGamePrompt() {
        guard let terminal = terminal else {
            print("❌ Cannot show game prompt - terminal not configured")
            return
        }
        
        print("🧪 DEBUG: showGamePrompt called for yesterday")
        
        if let completion = currentGameCompletion, completion.isCompleted {
            if completion.didWin {
                let message = getRandomMessage(from: victoryMessages, excluding: lastVictoryMessage)
                lastVictoryMessage = message
                terminal.writeLine(DisplayLines.promptLine, content: message)
                startGameOverSequence()
            } else {
                let message = getRandomMessage(from: gameOverMessages, excluding: lastGameOverMessage)
                lastGameOverMessage = message
                terminal.writeLine(DisplayLines.promptLine, content: message)
                startGameOverSequence()
            }
        } else {
            // Active game
            guard !fullWords.isEmpty else {
                print("❌ Cannot show game prompt - fullWords is empty!")
                return
            }
            
            let hostMessage: String
            if currentWordIndex == 1 {
                hostMessage = "🤔 What word came after \(fullWords[0])?"
            } else {
                guard currentWordIndex > 0 && currentWordIndex - 1 < fullWords.count else {
                    print("❌ Invalid currentWordIndex \(currentWordIndex) for fullWords count \(fullWords.count)")
                    return
                }
                let previousWord = fullWords[currentWordIndex - 1]
                let randomMessage = getRandomMessage(from: nextWordMessages, excluding: lastNextWordMessage)
                lastNextWordMessage = randomMessage
                hostMessage = "\(randomMessage) \(previousWord)?"
            }
            
            print("🧪 DEBUG: Writing game prompt: '\(hostMessage)'")
            terminal.writeLine(DisplayLines.promptLine, content: hostMessage)
            terminal.onCompletion { [weak self] in
                print("🧪 DEBUG: Yesterday game prompt completion - setting isActive = true")
                self?.isActive = true
            }
        }
    }
    
    // MARK: - Game Logic
    func handleInput(_ input: String) {
        guard let terminal = terminal,
              isActive && !terminal.isAnimating else { return }
        
        let trimmedGuess = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGuess.isEmpty else { return }
        
        currentGuess = ""
        
        if !isValidWord(trimmedGuess) {
            handleInvalidWord()
        } else {
            let targetWord = fullWords[currentWordIndex]
            
            if trimmedGuess.uppercased() == targetWord {
                handleCorrectGuess()
            } else {
                handleIncorrectGuess()
            }
        }
    }
    
    private func handleCorrectGuess() {
        guard let terminal = terminal else { return }
        
        // Update word chain display with checkmark
        let lineIndex = DisplayLines.wordChainStart + currentWordIndex
        terminal.setImmediate(lineIndex: lineIndex, content: fullWords[currentWordIndex] + " ✓")
        
        currentWordIndex += 1
        updateGameProgress()
        
        if currentWordIndex < fullWords.count - 1 {
            let previousWord = fullWords[currentWordIndex - 1]
            let randomMessage = getRandomMessage(from: nextWordMessages, excluding: lastNextWordMessage)
            lastNextWordMessage = randomMessage
            let newPrompt = "\(randomMessage) \(previousWord)?"
            
            terminal.replaceLine(DisplayLines.promptLine, content: newPrompt)
        } else {
            // Victory!
            completeGame()
            let message = getRandomMessage(from: victoryMessages, excluding: lastVictoryMessage)
            lastVictoryMessage = message
            terminal.replaceLine(DisplayLines.promptLine, content: message)
            isActive = false
            startGameOverSequence()
        }
    }
    
    private func handleIncorrectGuess() {
        guard let terminal = terminal else { return }
        
        currentLives -= 1
        updateLivesUsed()
        
        if currentLives <= 0 {
            // Game over
            updateGameProgress()
            completeGame()
            
            let message = getRandomMessage(from: gameOverMessages, excluding: lastGameOverMessage)
            lastGameOverMessage = message
            terminal.replaceLine(DisplayLines.promptLine, content: message)
            isActive = false
            startGameOverSequence()
        } else {
            // Give hint
            giveHint()
            
            let targetWord = fullWords[currentWordIndex]
            let revealedCount = revealedLetters[currentWordIndex] ?? 1
            
            if revealedCount >= targetWord.count {
                // Word fully revealed - auto advance
                currentWordIndex += 1
                updateGameProgress()
                
                if currentWordIndex < fullWords.count - 1 {
                    let previousWord = fullWords[currentWordIndex - 1]
                    let randomMessage = getRandomMessage(from: nextWordMessages, excluding: lastNextWordMessage)
                    lastNextWordMessage = randomMessage
                    let newPrompt = "\(randomMessage) \(previousWord)?"
                    terminal.replaceLine(DisplayLines.promptLine, content: newPrompt)
                } else {
                    // Victory through hints
                    completeGame()
                    let message = getRandomMessage(from: victoryMessages, excluding: lastVictoryMessage)
                    lastVictoryMessage = message
                    terminal.replaceLine(DisplayLines.promptLine, content: message)
                    isActive = false
                    startGameOverSequence()
                }
            } else {
                let message = getRandomMessage(from: incorrectMessages, excluding: lastIncorrectMessage)
                lastIncorrectMessage = message
                terminal.replaceLine(DisplayLines.promptLine, content: message)
            }
            
            updateGameProgress()
        }
    }
    
    private func handleInvalidWord() {
        guard let terminal = terminal else { return }
        
        let message = getRandomMessage(from: invalidWordMessages, excluding: lastInvalidWordMessage)
        lastInvalidWordMessage = message
        terminal.replaceLine(DisplayLines.promptLine, content: message)
    }
    
    private func giveHint() {
        guard let terminal = terminal else { return }
        
        let currentRevealed = revealedLetters[currentWordIndex] ?? 1
        let targetWord = fullWords[currentWordIndex]
        
        if currentRevealed < targetWord.count {
            let newRevealed = min(currentRevealed + 1, targetWord.count)
            revealedLetters[currentWordIndex] = newRevealed
            
            // Update display with status
            let revealedPart = String(targetWord.prefix(newRevealed))
            let hiddenPart = String(repeating: "_", count: targetWord.count - newRevealed)
            var displayText = revealedPart + hiddenPart
            
            // Add checkmark if fully revealed
            if newRevealed >= targetWord.count {
                displayText += " ✓"
            }
            
            let lineIndex = DisplayLines.wordChainStart + currentWordIndex
            terminal.setImmediate(lineIndex: lineIndex, content: displayText)
        }
    }
    
    // MARK: - Validation
    private func isValidWord(_ word: String) -> Bool {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedWord.count >= GameConstants.Validation.minimumWordLength && 
              trimmedWord.allSatisfy({ $0.isLetter }) else {
            return false
        }
        
        let textChecker = UITextChecker()
        let range = NSRange(location: 0, length: trimmedWord.utf16.count)
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: trimmedWord,
            range: range,
            startingAt: 0,
            wrap: false,
            language: GameConstants.Validation.spellCheckLanguage
        )
        
        return misspelledRange.location == NSNotFound
    }
    
    // MARK: - Game Completion
    private func updateGameProgress() {
        guard let completion = currentGameCompletion else { return }
        
        let wordsCompleted = currentWordIndex - 1
        completionService.updateProgress(
            for: completion.gameDate,
            wordsCompleted: wordsCompleted,
            currentWordIndex: currentWordIndex,
            revealedLetters: revealedLetters
        )
    }
    
    private func updateLivesUsed() {
        guard let completion = currentGameCompletion else { return }
        
        let livesUsed = GameConstants.maxLives - currentLives
        completionService.updateLivesUsed(for: completion.gameDate, livesUsed: livesUsed)
    }
    
    private func completeGame() {
        guard let completion = currentGameCompletion else { return }
        
        let livesUsed = GameConstants.maxLives - currentLives
        let didWin = currentWordIndex >= fullWords.count - 1 && currentLives > 0
        
        completionService.markGameCompleted(for: completion.gameDate, livesUsed: livesUsed, didWin: didWin)
        completion.markCompleted(livesUsed: livesUsed, didWin: didWin)
        
        // NOTE: Yesterday completion should NOT trigger notifications
        // which contribute to daily streak - this maintains streak isolation
    }
    
    // MARK: - Game Over Sequence
    private func startGameOverSequence() {
        gameOverTimer = Timer.scheduledTimer(withTimeInterval: GameConstants.Animation.gameOverSequenceDelay, repeats: false) { [weak self] _ in
            self?.showScoreAndNavigation()
        }
    }
    
    private func showScoreAndNavigation() {
        guard let terminal = terminal else { return }
        
        // Show score message (NO streak for yesterday's games)
        let message = generateScoreMessage()
        terminal.writeLine(DisplayLines.streakLine, content: message)
        
        terminal.onCompletion { [weak self] in
            self?.showNavigationLink()
        }
    }
    
    private func showNavigationLink() {
        guard let terminal = terminal else { return }
        
        // Always show link back to today's game
        let randomMessage = getRandomMessage(from: backToTodayMessages, excluding: lastBackToTodayMessage)
        lastBackToTodayMessage = randomMessage
        terminal.writeLine(DisplayLines.navigationLine, content: randomMessage)
    }
    
    // MARK: - Server Error
    private func showServerError() {
        hasServerError = true
        isActive = false
        
        guard let terminal = terminal else {
            print("❌ Cannot show server error - terminal not configured")
            return
        }
        
        let errorMessage = "😅 Yesterday's puzzle isn't available right now. Try today's game instead!"
        terminal.writeLine(DisplayLines.firstLine, content: errorMessage)
    }
    
    // MARK: - Helpers
    private func getYesterdayPuzzleDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = GameConstants.DateFormats.display
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return formatter.string(from: yesterday)
    }
    
    private func generateScoreMessage() -> String {
        guard let completion = currentGameCompletion else { return "" }
        
        let score = completionService.getGameScore(for: completion.gameDate)
        
        // NO STREAK for yesterday's games - maintains streak isolation
        return "📊 You got \(score.correct)/\(score.incorrect) correct on yesterday's puzzle!"
    }
    
    // MARK: - Completed Game Display
    private func startCompletedGameDisplay() {
        guard let terminal = terminal else {
            print("❌ Cannot start completed game display - terminal not configured")
            return
        }
        
        print("🎬 Starting completed yesterday game display sequence...")
        
        // Use the standard animation sequence for completed games
        startGameAnimation()
    }
    
    func reset() {
        print("🔄 YesterdayGameContent: Resetting game state")
        isResetting = true
        isActive = false
        terminal?.clearAllImmediate()
        
        // Invalidate all timers
        gameOverTimer?.invalidate()
        gameOverTimer = nil
        readinessTimer?.invalidate()
        readinessTimer = nil
        
        // Reset state
        currentLives = GameConstants.maxLives
        currentGuess = ""
        hasServerError = false
        fullWords = []
        wordChain = []
        currentWordIndex = GameConstants.startingWordIndex
        revealedLetters = [:]
        currentGameCompletion = nil
        currentPuzzleDate = nil
        
        // Reset message tracking
        lastNextWordMessage = ""
        lastIncorrectMessage = ""
        lastGameOverMessage = ""
        lastVictoryMessage = ""
        lastInvalidWordMessage = ""
        lastBackToTodayMessage = ""
    }
    
    // MARK: - Cleanup
    deinit {
        gameOverTimer?.invalidate()
        readinessTimer?.invalidate()
    }
}