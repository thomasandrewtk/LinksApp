//
//  TodayGameContent.swift
//  Links
//
//  Created by Assistant on 2025-01-14.
//

import SwiftUI
import Combine
import UIKit

/// Manages the content display for today's puzzle
class TodayGameContent: ObservableObject {
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
    private var shouldDisplayContent: Bool = true  // Controls whether content can be displayed
    
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
    
    // MARK: - Message Arrays (from GameViewModel)
    private let nextWordMessages = [
        "🤔 What word comes after",
        "🧐 Next up, what follows",
        "🤓 Alright genius, what comes after",
        "😏 Think you can guess what follows",
        "🙄 Obviously, what comes after"
    ]
    
    private let incorrectMessages = [
        "🙄 Nope! Here's a hint:",
        "😬 Wrong! Take this hint:",
        "🤦‍♂️ Not quite! Hint time:",
        "😅 Oops! Here's some help:",
        "🫤 Incorrect! Throwing you a bone:"
    ]
    
    private let gameOverMessages = [
        "💀 Game Over! Maybe tomorrow?",
        "😵 Yikes! Better luck next time.",
        "🪦 RIP. Try again tomorrow!",
        "😬 Oof. See you tomorrow!",
        "💔 Game Over! Don't give up!"
    ]
    
    private let victoryMessages = [
        "🎉 Holy cow! You actually did it!",
        "🤯 Wow! Didn't see that coming!",
        "👏 Impressive! You solved it!",
        "🥳 Look who's the word wizard!",
        "🏆 Victory! You're pretty good at this!"
    ]
    
    private let invalidWordMessages = [
        "🤨 That's not a real word! Try again.",
        "😕 Invalid word! Check your spelling.",
        "🔤 Not in my dictionary! Try another.",
        "📚 That word doesn't exist! Keep trying.",
        "❓ Not a valid word! Give it another shot."
    ]
    
    private let playYesterdayMessages = [
        "🕰️ Missed [yesterday]? Tap to play!",
        "⏮️ [Yesterday]'s puzzle awaits you!",
        "🎯 [Yesterday]'s game is ready!",
        "📅 Catch up on [yesterday]'s puzzle!",
        "🎮 [Yesterday]'s challenge waits!"
    ]
    
    private let viewYesterdayMessages = [
        "📊 Tap to view [yesterday]'s result!",
        "✅ Check out [yesterday]'s game!",
        "🔍 See how you did [yesterday]!",
        "📈 Review [yesterday]'s puzzle!",
        "🎉 Revisit [yesterday]'s victory!"
    ]
    
    // Track last used messages
    private var lastNextWordMessage: String = ""
    private var lastIncorrectMessage: String = ""
    private var lastGameOverMessage: String = ""
    private var lastVictoryMessage: String = ""
    private var lastInvalidWordMessage: String = ""
    private var lastPlayYesterdayMessage: String = ""
    private var lastViewYesterdayMessage: String = ""
    
    // MARK: - Timers
    private var gameOverTimer: Timer?
    private var countdownTimer: Timer?
    private var readinessTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    func configure(with terminal: TerminalViewModel) {
        self.terminal = terminal
        print("🔗 TodayGameContent: Configured with terminal")
    }
    
    // MARK: - Helper Methods
    /// Get a random message avoiding the last used one
    func getRandomMessage(from messages: [String], excluding lastMessage: String) -> String {
        let availableMessages = messages.filter { $0 != lastMessage }
        return availableMessages.randomElement() ?? messages.randomElement() ?? messages[0]
    }
    
    private func setupBindings() {
        // Listen for puzzle updates (e.g., midnight timer) but prevent duplicate setup
        puzzleService.$todaysPuzzle
            .compactMap { $0 }
            .dropFirst()
            .sink { [weak self] puzzle in
                guard let self = self, !self.isResetting else { return }
                self.handlePuzzleUpdate(puzzle)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Game Flow
    func start() {
        guard let terminal = terminal else {
            print("❌ TodayGameContent: Terminal not configured!")
            return
        }
        
        isActive = true
        print("🎮 TodayGameContent: Starting game...")
        terminal.clearAllImmediate()
        
        // Wait for SwiftData to be ready before loading
        waitForSwiftDataAndLoadPuzzle()
    }
    
    private func waitForSwiftDataAndLoadPuzzle() {
        // Check if SwiftData is already ready
        if completionService.isReady {
            print("✅ SwiftData ready immediately, loading puzzle")
            loadTodaysPuzzle()
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
                    print("✅ SwiftData ready, loading puzzle")
                    self.readinessTimer?.invalidate()
                    self.readinessTimer = nil
                    self.loadTodaysPuzzle()
                }
            }
        }
    }
    
    private func loadTodaysPuzzle() {
        print("📦 Loading today's puzzle...")
        if let puzzle = puzzleService.todaysPuzzle {
            print("✅ Found cached puzzle")
            setupWithPuzzle(puzzle)
        } else {
            print("🌐 Fetching puzzle from server...")
            Task {
                await puzzleService.fetchTodaysPuzzle()
                await MainActor.run {
                    if let puzzle = self.puzzleService.todaysPuzzle {
                        if puzzle.date == "fallback" && self.puzzleService.lastFetchError != nil {
                            print("❌ Server error, showing error message")
                            self.showServerError()
                        } else {
                            print("✅ Fetched puzzle successfully")
                            self.setupWithPuzzle(puzzle)
                        }
                    } else {
                        print("❌ No puzzle available")
                        self.showServerError()
                    }
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
                print("🔄 Returning to completed game - showing completed state")
                startCompletedGameDisplay()
                return
            } else {
                print("⏭️ Active game already configured, skipping duplicate setup")
                return
            }
        }
        
        print("🎲 Setting up puzzle for date: \(puzzle.date)")
        currentPuzzleDate = puzzle.date
        fullWords = puzzle.words
        
        // Get or create completion record
        if let existingCompletion = completionService.getGameCompletion(for: puzzle.date) {
            currentGameCompletion = existingCompletion
            print("📝 Found existing game completion")
            
            if existingCompletion.isCompleted {
                setupCompletedGameState(from: existingCompletion)
            } else {
                restoreGameState(from: existingCompletion)
            }
        } else {
            currentGameCompletion = completionService.createGameCompletion(for: puzzle.date, totalWords: puzzle.words.count)
            setupInitialGameState()
            print("🆕 Created new game completion")
        }
        
        // Start animation sequence
        print("🎬 Starting game animation sequence...")
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
        
        let dateString = getPuzzleDate()
        let firstLineMessage = "Can you solve today's links? \(dateString)"
        
        print("🧪 DEBUG: Starting first line animation")
        
        // Use a single command that chains both operations
        terminal.writeLine(DisplayLines.firstLine, content: firstLineMessage)
        terminal.onCompletion { [weak self] in
            print("🧪 DEBUG: First line completion handler called!")
            DispatchQueue.main.async {
                self?.animateWordChain()
            }
        }
        
        print("🧪 DEBUG: Both commands queued")
    }
    
    private func animateWordChain() {
        guard let terminal = terminal else {
            print("❌ Cannot animate word chain - terminal not configured")
            return
        }
        
        print("🧪 DEBUG: animateWordChain called")
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
            print("🧪 DEBUG: Word chain completion handler called!")
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
        
        print("🧪 DEBUG: showGamePrompt called")
        
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
                hostMessage = "🤔 What word comes after \(fullWords[0])?"
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
                print("🧪 DEBUG: Game prompt completion - setting isActive = true")
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
        
        Task {
            await NotificationManager.shared.onGameCompleted()
        }
    }
    
    // MARK: - Game Over Sequence
    private func startGameOverSequence() {
        gameOverTimer = Timer.scheduledTimer(withTimeInterval: GameConstants.Animation.gameOverSequenceDelay, repeats: false) { [weak self] _ in
            self?.showStreakScore()
        }
    }
    
    private func showStreakScore() {
        guard let terminal = terminal else { return }
        
        // Show streak/score message
        let message = generateStreakScoreMessage()
        terminal.writeLine(DisplayLines.streakLine, content: message)
        
        terminal.onCompletion { [weak self] in
            self?.showNavigationLink()
        }
    }
    
    private func showNavigationLink() {
        guard let terminal = terminal else { return }
        
        // Check if yesterday's game was completed to determine message type
        let message: String
        if completionService.isYesterdayGameCompleted() {
            // Show "view" message for completed games
            let randomMessage = getRandomMessage(from: viewYesterdayMessages, excluding: lastViewYesterdayMessage)
            lastViewYesterdayMessage = randomMessage
            message = randomMessage
        } else {
            // Show "play" message for incomplete games
            let randomMessage = getRandomMessage(from: playYesterdayMessages, excluding: lastPlayYesterdayMessage)
            lastPlayYesterdayMessage = randomMessage
            message = randomMessage
        }
        
        terminal.writeLine(DisplayLines.navigationLine, content: message)
        
        terminal.onCompletion { [weak self] in
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                self?.startCountdown()
            }
        }
    }
    
    private func startCountdown() {
        guard let terminal = terminal else { return }
        
        // SAFETY: Don't start countdown if content display is disabled
        guard shouldDisplayContent else {
            print("⏸️ Countdown start blocked - content display disabled")
            return
        }
        
        let timeUntilMidnight = getTimeUntilMidnight()
        let initialMessage = "⏰ Next puzzle in \(formatTime(timeUntilMidnight))"
        terminal.replaceLine(DisplayLines.promptLine, content: initialMessage)
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
    }
    
    private func updateCountdown() {
        guard let terminal = terminal else { return }
        
        // CRITICAL: Don't display countdown when not in today mode (prevents interference with yesterday's game)
        guard shouldDisplayContent else { 
            print("⏸️ Countdown update blocked - content display disabled")
            return 
        }
        
        let timeUntilMidnight = getTimeUntilMidnight()
        let message: String
        
        if timeUntilMidnight.hours == 0 && timeUntilMidnight.minutes == 0 && timeUntilMidnight.seconds == 0 {
            message = "🎯 New puzzle available! Restart the app."
            countdownTimer?.invalidate()
        } else {
            message = "⏰ Next puzzle in \(formatTime(timeUntilMidnight))"
        }
        
        terminal.setImmediate(lineIndex: DisplayLines.promptLine, content: message)
    }
    
    // MARK: - Server Error
    private func showServerError() {
        hasServerError = true
        isActive = false
        
        guard let terminal = terminal else {
            print("❌ Cannot show server error - terminal not configured")
            return
        }
        
        let errorMessage = GameConstants.ServerErrorMessages.randomMessage()
        terminal.writeLine(DisplayLines.firstLine, content: errorMessage)
    }
    
    // MARK: - Helpers
    private func getPuzzleDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = GameConstants.DateFormats.display
        return formatter.string(from: Date())
    }
    
    private func handlePuzzleUpdate(_ puzzle: DailyPuzzle) {
        reset()
        setupWithPuzzle(puzzle)
    }
    
    private func generateStreakScoreMessage() -> String {
        guard let completion = currentGameCompletion else { return "" }
        
        let score = completionService.getGameScore(for: completion.gameDate)
        let streak = completionService.getCurrentDailyStreak()
        
        return "📊 You got \(score.correct)/\(score.incorrect) correct! 🔥 \(streak) day streak!"
    }
    
    private func getTimeUntilMidnight() -> (hours: Int, minutes: Int, seconds: Int) {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let midnight = calendar.startOfDay(for: tomorrow)
        
        let timeInterval = midnight.timeIntervalSince(now)
        let totalSeconds = Int(timeInterval)
        
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        return (hours: max(0, hours), minutes: max(0, minutes), seconds: max(0, seconds))
    }
    
    private func formatTime(_ time: (hours: Int, minutes: Int, seconds: Int)) -> String {
        if time.hours > 0 {
            return String(format: "%02d:%02d:%02d", time.hours, time.minutes, time.seconds)
        } else {
            return String(format: "%02d:%02d", time.minutes, time.seconds)
        }
    }
    
    func reset() {
        print("🔄 TodayGameContent: Resetting game state")
        isResetting = true
        isActive = false
        terminal?.clearAllImmediate()
        
        // Invalidate all timers
        gameOverTimer?.invalidate()
        gameOverTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
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
        shouldDisplayContent = true  // Reset content display flag
        
        // Reset message tracking
        lastNextWordMessage = ""
        lastIncorrectMessage = ""
        lastGameOverMessage = ""
        lastVictoryMessage = ""
        lastInvalidWordMessage = ""
        lastPlayYesterdayMessage = ""
        lastViewYesterdayMessage = ""
    }
    
    // MARK: - Completed Game Display
    private func startCompletedGameDisplay() {
        guard let terminal = terminal else {
            print("❌ Cannot start completed game display - terminal not configured")
            return
        }
        
        print("🎬 Starting completed game display sequence with proper animations...")
        
        // Use the standard animation sequence, just like initial game loading
        startGameAnimation()
    }
    
    // MARK: - Timer Management
    func pauseTimers() {
        print("⏸️ TodayGameContent: Pausing timers and disabling content display")
        shouldDisplayContent = false  // Prevent any content drawing
        gameOverTimer?.invalidate()
        gameOverTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        readinessTimer?.invalidate()
        readinessTimer = nil
    }
    
    func resumeTimers() {
        print("▶️ TodayGameContent: Resuming timers and enabling content display")
        shouldDisplayContent = true  // Re-enable content drawing
        // Do NOT start countdown here - let the animation sequence handle it
        // The countdown will start naturally after the navigation link is displayed
    }
    
    // MARK: - Cleanup
    deinit {
        gameOverTimer?.invalidate()
        countdownTimer?.invalidate()
        readinessTimer?.invalidate()
    }
}