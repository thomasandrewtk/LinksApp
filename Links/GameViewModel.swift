//
//  GameViewModel.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import SwiftUI
import Combine
import Foundation
import UIKit
import SwiftData

class GameViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentGuess: String = ""
    @Published var currentLives: Int = 5
    @Published var currentPrompt: String = ""
    @Published var displayedPrompt: String = ""
    @Published var displayedFirstLine: String = ""
    @Published var wordChain: [String] = []
    @Published var isGameActive: Bool = false
    @Published var isAnimating: Bool = false
    @Published var isContentReady: Bool = false
    @Published var showFirstLine: Bool = false
    @Published var hasServerError: Bool = false
    
    // MARK: - Game Configuration
    let maxLives: Int = GameConstants.maxLives
    var puzzleDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = GameConstants.DateFormats.display
        return formatter.string(from: Date())
    }
    
    // MARK: - Game Data
    @Published var fullWords: [String] = []
    private let puzzleService = PuzzleService.shared
    private let completionService = GameCompletionService.shared
    
    // MARK: - Game Completion Tracking
    @Published var currentGameCompletion: GameCompletion?
    @Published var isPlayingPreviousGame: Bool = false
    var currentGameDate: String {
        return currentGameCompletion?.gameDate ?? GameCompletion.todayDateString()
    }
    
    // MARK: - Host Messages with Personality
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
    
    // MARK: - Game State
    private var currentWordIndex: Int = GameConstants.startingWordIndex // Starting at second word (first guess)
    private var revealedLetters: [Int: Int] = [:] // wordIndex: number of letters revealed
    
    // Track last used messages to avoid repeats
    private var lastNextWordMessage: String = ""
    private var lastIncorrectMessage: String = ""
    private var lastGameOverMessage: String = ""
    private var lastVictoryMessage: String = ""
    private var lastInvalidWordMessage: String = ""
    
    // Countdown timer
    private var gameOverTimer: Timer?
    private var countdownTimer: Timer?
    
    // Typewriter animation
    private var typewriterTimer: Timer?
    private var targetMessage: String = ""
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Timer to check for SwiftData readiness
    private var readinessTimer: Timer?
    
    init() {
        // Start completely blank, wait for SwiftData to be ready before loading content
        waitForSwiftDataAndLoadPuzzle()
    }
    
    // MARK: - SwiftData Readiness Check
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
                    // Invalidate timer on main actor
                    self.readinessTimer?.invalidate()
                    self.readinessTimer = nil
                    self.loadTodaysPuzzle()
                }
            }
        }
    }
    
    // MARK: - Game Selection
    func playTodaysGame() {
        isPlayingPreviousGame = false
        loadTodaysPuzzle()
    }
    
    func playPreviousGame(completion: GameCompletion, puzzle: DailyPuzzle) {
        isPlayingPreviousGame = true
        currentGameCompletion = completion
        fullWords = puzzle.words
        
        // Restore game state from completion record
        restoreGameState(from: completion)
        markContentReady()
    }
    
    func canPlayYesterdaysGame() -> Bool {
        return completionService.getYesterdayGameIfIncomplete() != nil
    }
    
    // MARK: - Content Ready
    private func markContentReady() {
        hasServerError = false
        isContentReady = true
        showFirstLine = false  // Start with nothing visible
        print("✅ Content loaded and ready")
        
        // Ensure clean state before animation
        displayedFirstLine = ""
        displayedPrompt = ""
        
        // Start the animation sequence: first line -> word chain -> host message
        let firstLine = "Can you solve today's links? \(puzzleDate)"
        showFirstLine = true
        animateFirstLine(to: firstLine) {
            // After first line completes, animate word chain
            self.animateWordChainSimultaneous()
        }
    }
    
    // MARK: - Server Error State
    private func markServerError() {
        hasServerError = true
        isContentReady = false
        showFirstLine = false  // Start with nothing visible
        isGameActive = false
        print("❌ Server error state activated")
        
        // Ensure clean state before animation
        displayedFirstLine = ""
        displayedPrompt = ""
        
        // Show random snarky error message with animation
        let errorMessage = GameConstants.ServerErrorMessages.randomMessage()
        showFirstLine = true
        animateFirstLine(to: errorMessage)
    }
    
    // MARK: - Puzzle Loading
    private func loadTodaysPuzzle() {
        // Check if we already have today's puzzle
        if let puzzle = puzzleService.todaysPuzzle {
            finishLoadingWithPuzzle(puzzle)
            print("✅ Using cached puzzle for \(puzzle.date)")
        } else {
            // Fetch from server
            Task {
                await puzzleService.fetchTodaysPuzzle()
                await MainActor.run {
                    if let puzzle = self.puzzleService.todaysPuzzle {
                        // Check if this is the fallback puzzle due to server error
                        if puzzle.date == "fallback" && self.puzzleService.lastFetchError != nil {
                            self.markServerError()
                        } else {
                            self.finishLoadingWithPuzzle(puzzle)
                            print("✅ Loaded puzzle for \(puzzle.date)")
                        }
                    } else {
                        // No puzzle at all
                        self.markServerError()
                    }
                }
            }
        }
        
        // Listen for puzzle updates (like at midnight) - but not the initial load
        puzzleService.$todaysPuzzle
            .compactMap { $0 }
            .dropFirst() // Skip the first emission to avoid duplicate processing
            .sink { [weak self] puzzle in
                self?.fullWords = puzzle.words
                self?.resetGame() // Reset game with new puzzle
                print("🔄 New puzzle loaded: \(puzzle.date)")
            }
            .store(in: &cancellables)
    }
    
    private func finishLoadingWithPuzzle(_ puzzle: DailyPuzzle) {
        // Validate puzzle has the expected number of words
        if puzzle.words.count != GameConstants.expectedWordCount {
            print("⚠️ Puzzle has \(puzzle.words.count) words, expected \(GameConstants.expectedWordCount)")
            // Still proceed but log the warning
        }
        
        fullWords = puzzle.words
        
        // Get or create completion record for this game
        if let existingCompletion = completionService.getGameCompletion(for: puzzle.date) {
            currentGameCompletion = existingCompletion
            
            // If game is already completed, show completion state
            if existingCompletion.isCompleted {
                setupCompletedGameState(from: existingCompletion)
            } else {
                // Resume from where user left off
                restoreGameState(from: existingCompletion)
            }
        } else {
            // Create new game completion record
            currentGameCompletion = completionService.createGameCompletion(for: puzzle.date, totalWords: puzzle.words.count)
            setupInitialWordChain()
        }
        
        markContentReady()
    }
    
    private func restoreGameState(from completion: GameCompletion) {
        // Restore game progress
        currentLives = maxLives - completion.livesUsed
        currentWordIndex = completion.currentWordIndex
        revealedLetters = completion.revealedLetters
        
        print("🔄 Restored game state: word \(currentWordIndex), lives \(currentLives)")
        print("🎯 Animation will show restored state with \(completion.revealedLetters.count) words with revealed letters")
    }
    
    private func setupCompletedGameState(from completion: GameCompletion) {
        // Restore the final game state
        currentLives = maxLives - completion.livesUsed
        currentWordIndex = completion.currentWordIndex
        revealedLetters = completion.revealedLetters
        isGameActive = false
        
        print("🎯 Showing completed game state - \(completion.didWin ? "Victory" : "Game Over")")
        print("📊 Completion stats: \(completion.wordsCompleted)/\(completion.totalWords) words, \(completion.livesUsed) lives used, Won: \(completion.didWin)")
    }
    
    // MARK: - Setup
    private func setupInitialWordChain() {
        // Don't setup if we don't have words yet
        guard !fullWords.isEmpty else { return }
        
        // Initialize empty word chain for animation, but setup revealed letters
        wordChain = Array(repeating: "", count: fullWords.count)
        revealedLetters = [:]
        
        // Set up revealed letters tracking for middle words
        for (index, _) in fullWords.enumerated() {
            if index != 0 && index != fullWords.count - 1 {
                revealedLetters[index] = 1 // First letter is revealed for middle words
            }
        }
    }
    
    // MARK: - Word Chain Target Building
    private func buildWordChainTarget() -> [String] {
        var targetWords: [String] = []
        
        for (index, word) in fullWords.enumerated() {
            if index == 0 || index == fullWords.count - 1 {
                // First and last words are always fully revealed
                targetWords.append(word)
            } else if index < currentWordIndex {
                // Words that have been correctly guessed are fully revealed
                targetWords.append(word)
            } else if index == currentWordIndex {
                // Current word shows revealed letters
                let revealedCount = revealedLetters[index] ?? 1
                let revealedPart = String(word.prefix(revealedCount))
                let hiddenPart = String(repeating: "_", count: word.count - revealedCount)
                targetWords.append(revealedPart + hiddenPart)
            } else {
                // Future words show first letter + underscores
                let hiddenWord = String(word.prefix(1)) + String(repeating: "_", count: word.count - 1)
                targetWords.append(hiddenWord)
            }
        }
        
        return targetWords
    }
    
    // MARK: - Word Chain Animation
    private func animateWordChainSimultaneous() {
        // Build target words based on current game state
        let targetWords = buildWordChainTarget()
        
        // Reset word chain to empty for animation
        wordChain = Array(repeating: "", count: fullWords.count)
        
        // Find the maximum word length to know when to stop
        let maxLength = targetWords.map { $0.count }.max() ?? 0
        var currentCharIndex = 0
        
        _ = Timer.scheduledTimer(withTimeInterval: GameConstants.Animation.wordChainRevealSpeed, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Update each word simultaneously
            for wordIndex in 0..<targetWords.count {
                let targetWord = targetWords[wordIndex]
                let currentLength = min(currentCharIndex + 1, targetWord.count)
                self.wordChain[wordIndex] = String(targetWord.prefix(currentLength))
            }
            
            currentCharIndex += 1
            
            // Stop when we've revealed all characters of the longest word
            if currentCharIndex >= maxLength {
                timer.invalidate()
                print("🎬 Word chain animation complete")
                // Start final step: host message and activate game
                self.startGame()
            }
        }
    }
    
    // MARK: - First Line Animation
    private func animateFirstLine(to newMessage: String, completion: (() -> Void)? = nil) {
        guard !isAnimating else { 
            completion?()
            return 
        }
        
        isAnimating = true
        var index = 0
        
        _ = Timer.scheduledTimer(withTimeInterval: GameConstants.Animation.firstLineTypewriterSpeed, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if index < newMessage.count {
                index += 1
                self.displayedFirstLine = String(newMessage.prefix(index))
            } else {
                timer.invalidate()
                self.isAnimating = false
                self.displayedFirstLine = newMessage
                completion?()
            }
        }
    }
    
    // MARK: - Game Activation
    private func startGame() {
        // Check if this is a completed game
        if let completion = currentGameCompletion, completion.isCompleted {
            if completion.didWin {
                // Show victory message for completed game
                let randomVictory = getRandomMessage(from: victoryMessages, excluding: lastVictoryMessage)
                lastVictoryMessage = randomVictory
                animateMessageChange(to: randomVictory) {
                    self.startGameOverSequence()
                }
                print("🎉 SHOWING COMPLETED VICTORY STATE")
            } else {
                // Show game over message for failed game
                let randomGameOver = getRandomMessage(from: gameOverMessages, excluding: lastGameOverMessage)
                lastGameOverMessage = randomGameOver
                animateMessageChange(to: randomGameOver) {
                    self.startGameOverSequence()
                }
                print("💀 SHOWING COMPLETED GAME OVER STATE")
            }
        } else {
            // Active game - show prompt appropriate for current state
            let hostMessage: String
            if currentWordIndex == 1 {
                // First guess - asking about what comes after the first word
                hostMessage = "🤔 What word comes after \(fullWords[0])?"
            } else {
                // Restored game in progress - asking about what comes after the previous correctly guessed word
                let previousWord = fullWords[currentWordIndex - 1]
                let randomMessage = getRandomMessage(from: nextWordMessages, excluding: lastNextWordMessage)
                lastNextWordMessage = randomMessage
                hostMessage = "\(randomMessage) \(previousWord)?"
            }
            
            animateMessageChange(to: hostMessage, speed: .normal) {
                // After host message completes, activate the game
                self.isGameActive = true
                print("🎮 Game is now active and ready for input")
            }
        }
    }
    
    // MARK: - Business Logic
    func submitGuess() {
        // Don't submit if animating
        guard !isAnimating else {
            print("⚠️ Guess blocked during animation")
            return
        }
        
        // Don't submit empty or whitespace-only guesses
        let trimmedGuess = currentGuess.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGuess.isEmpty else {
            print("⚠️ Empty guess blocked")
            return
        }
        
        print("=== GUESS SUBMITTED ===")
        print("User guessed: '\(trimmedGuess)'")
        print("Current word index: \(currentWordIndex)")
        print("Expected word: \(fullWords[currentWordIndex])")
        print("Lives remaining: \(currentLives)")
        
        // First check if the word is valid
        if !isValidWord(trimmedGuess) {
            print("📚 Invalid word!")
            handleInvalidWord()
        } else {
            let targetWord = fullWords[currentWordIndex]
            
            if trimmedGuess.uppercased() == targetWord {
                print("✅ Correct guess!")
                handleCorrectGuess()
            } else {
                print("❌ Incorrect guess!")
                handleIncorrectGuess()
            }
        }
        
        // Clear the guess
        currentGuess = ""
        print("========================")
    }
    
    private func handleCorrectGuess() {
        print("Revealing word: \(fullWords[currentWordIndex])")
        
        // Reveal the full word
        wordChain[currentWordIndex] = fullWords[currentWordIndex]
        
        // Move to next word
        currentWordIndex += 1
        
        // Update completion tracking
        updateGameProgress()
        
        if currentWordIndex < fullWords.count - 1 {
            let previousWord = fullWords[currentWordIndex - 1]
            let randomMessage = getRandomMessage(from: nextWordMessages, excluding: lastNextWordMessage)
            lastNextWordMessage = randomMessage
            let newPrompt = "\(randomMessage) \(previousWord)?"
            animateMessageChange(to: newPrompt)
            print("New prompt: \(newPrompt)")
        } else {
            // Game completed!
            completeGame()
            let randomVictory = getRandomMessage(from: victoryMessages, excluding: lastVictoryMessage)
            lastVictoryMessage = randomVictory
            animateMessageChange(to: randomVictory)
            isGameActive = false
            startGameOverSequence()
            print("🎉 PUZZLE COMPLETE!")
        }
    }
    
    private func handleIncorrectGuess() {
        currentLives -= 1
        print("Lives lost! Now at: \(currentLives)/\(maxLives)")
        
        // Update lives used in completion tracking
        updateLivesUsed()
        
        if currentLives <= 0 {
            // Game failed! Update final progress and mark as completed
            updateGameProgress()
            completeGame()
            
            let randomGameOver = getRandomMessage(from: gameOverMessages, excluding: lastGameOverMessage)
            lastGameOverMessage = randomGameOver
            animateMessageChange(to: randomGameOver)
            isGameActive = false
            startGameOverSequence()
            print("💀 GAME OVER!")
        } else {
            // Give a hint by revealing the next letter
            giveHint()
            
            // Check if the word is now fully revealed through hints
            let targetWord = fullWords[currentWordIndex]
            let revealedCount = revealedLetters[currentWordIndex] ?? 1
            
            if revealedCount >= targetWord.count {
                // Word is fully revealed through hints - automatically advance
                print("🎯 Word '\(targetWord)' fully revealed through hints - auto-advancing!")
                
                // Move to next word (same logic as handleCorrectGuess)
                currentWordIndex += 1
                
                // Update progress
                updateGameProgress()
                
                if currentWordIndex < fullWords.count - 1 {
                    let previousWord = fullWords[currentWordIndex - 1]
                    let randomMessage = getRandomMessage(from: nextWordMessages, excluding: lastNextWordMessage)
                    lastNextWordMessage = randomMessage
                    let newPrompt = "\(randomMessage) \(previousWord)?"
                    animateMessageChange(to: newPrompt)
                    print("New prompt: \(newPrompt)")
                } else {
                    // Game completed!
                    completeGame()
                    let randomVictory = getRandomMessage(from: victoryMessages, excluding: lastVictoryMessage)
                    lastVictoryMessage = randomVictory
                    animateMessageChange(to: randomVictory)
                    isGameActive = false
                    startGameOverSequence()
                    print("🎉 PUZZLE COMPLETE!")
                }
            } else {
                // Word not fully revealed yet - show incorrect message and continue
                let randomIncorrect = getRandomMessage(from: incorrectMessages, excluding: lastIncorrectMessage)
                lastIncorrectMessage = randomIncorrect
                animateMessageChange(to: randomIncorrect)
                print("Giving hint - revealed another letter")
            }
            
            // Update progress with new revealed letters
            updateGameProgress()
        }
    }
    
    private func handleInvalidWord() {
        print("📚 Invalid word - no life lost")
        let randomInvalidMessage = getRandomMessage(from: invalidWordMessages, excluding: lastInvalidWordMessage)
        lastInvalidWordMessage = randomInvalidMessage
        animateMessageChange(to: randomInvalidMessage)
    }
    
    private func giveHint() {
        let currentRevealed = revealedLetters[currentWordIndex] ?? 1
        let targetWord = fullWords[currentWordIndex]
        
        if currentRevealed < targetWord.count {
            let newRevealed = min(currentRevealed + 1, targetWord.count)
            revealedLetters[currentWordIndex] = newRevealed
            
            // Update the word chain with more letters revealed
            let revealedPart = String(targetWord.prefix(newRevealed))
            let hiddenPart = String(repeating: "_", count: targetWord.count - newRevealed)
            wordChain[currentWordIndex] = revealedPart + hiddenPart
            
            print("Hint: Word is now shown as: \(wordChain[currentWordIndex])")
            
            // Check if word is now fully revealed through hints
            if newRevealed >= targetWord.count {
                print("🎯 Word '\(targetWord)' is now fully revealed through hints!")
                // The status indicator will automatically update through getWordStatus()
                // and the UI will refresh to show the checkmark
            }
        }
    }
    
    // MARK: - Word Validation
    private func isValidWord(_ word: String) -> Bool {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic checks - must be at least minimum length and contain only letters
        guard trimmedWord.count >= GameConstants.Validation.minimumWordLength && trimmedWord.allSatisfy({ $0.isLetter }) else {
            return false
        }
        
        // Use iOS spell checker to validate the word
        let textChecker = UITextChecker()
        let range = NSRange(location: 0, length: trimmedWord.utf16.count)
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: trimmedWord,
            range: range,
            startingAt: 0,
            wrap: false,
            language: GameConstants.Validation.spellCheckLanguage
        )
        
        // If rangeOfMisspelledWord returns NSNotFound, the word is valid
        return misspelledRange.location == NSNotFound
    }
    
    // MARK: - Game Completion Tracking Methods
    private func updateGameProgress() {
        guard let completion = currentGameCompletion else { return }
        
        let wordsCompleted = currentWordIndex - 1 // Subtract 1 because index is for next word
        print("📈 Updating progress: \(wordsCompleted) words completed, currentWordIndex: \(currentWordIndex)")
        
        completionService.updateProgress(
            for: completion.gameDate,
            wordsCompleted: wordsCompleted,
            currentWordIndex: currentWordIndex,
            revealedLetters: revealedLetters
        )
    }
    
    private func updateLivesUsed() {
        guard let completion = currentGameCompletion else { return }
        
        let livesUsed = maxLives - currentLives
        completionService.updateLivesUsed(for: completion.gameDate, livesUsed: livesUsed)
    }
    
    private func completeGame() {
        guard let completion = currentGameCompletion else { return }
        
        let livesUsed = maxLives - currentLives
        // Win if we completed all words, lose if we ran out of lives
        let didWin = currentWordIndex >= fullWords.count - 1 && currentLives > 0
        
        print("🏁 Completing game: \(completion.wordsCompleted)/\(completion.totalWords) words, \(livesUsed) lives used")
        print("📊 Result: \(didWin ? "VICTORY" : "DEFEAT")")
        
        completionService.markGameCompleted(for: completion.gameDate, livesUsed: livesUsed, didWin: didWin)
        
        // Update the local completion object
        completion.markCompleted(livesUsed: livesUsed, didWin: didWin)
        
        // Cancel today's reminder notification since game is completed
        Task {
            await NotificationManager.shared.onGameCompleted()
        }
    }
    
    // MARK: - Debug Methods
    func wipeAllDataAndReset() {
        print("🧨 DEBUG: Wiping all data and completely reinitializing app...")
        
        // Stop all timers and animations first
        readinessTimer?.invalidate()
        gameOverTimer?.invalidate()
        countdownTimer?.invalidate()
        typewriterTimer?.invalidate()
        isAnimating = false
        
        // Wipe all SwiftData
        completionService.wipeAllData()
        
        // Clear all notifications
        Task {
            await NotificationManager.shared.clearAllNotifications()
        }
        
        // Completely reset to initial state
        completelyResetToInitialState()
        
        // Clear any cached puzzle data in the service
        puzzleService.clearCache()
        
        // Give a brief moment for everything to settle, then restart fresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.waitForSwiftDataAndLoadPuzzle()
            
            // Reschedule notifications after reset
            Task {
                await NotificationManager.shared.requestPermissionAndSchedule()
            }
        }
        
        print("🔄 Complete app reinitialization initiated!")
    }
    
    // MARK: - Complete State Reset
    private func completelyResetToInitialState() {
        print("🔄 COMPLETELY RESETTING TO INITIAL STATE")
        
        // Reset all @Published properties to initial values
        currentGuess = ""
        currentLives = maxLives
        currentPrompt = ""
        displayedPrompt = ""
        displayedFirstLine = ""
        wordChain = []
        isGameActive = false
        isAnimating = false
        isContentReady = false
        showFirstLine = false
        hasServerError = false
        
        // Reset game data
        fullWords = []
        currentWordIndex = GameConstants.startingWordIndex
        revealedLetters = [:]
        
        // Reset message tracking
        lastNextWordMessage = ""
        lastIncorrectMessage = ""
        lastGameOverMessage = ""
        lastVictoryMessage = ""
        lastInvalidWordMessage = ""
        
        // Reset completion tracking
        currentGameCompletion = nil
        isPlayingPreviousGame = false
        
        // Clear target message for typewriter
        targetMessage = ""
        
        // Invalidate any remaining timers (defensive)
        readinessTimer?.invalidate()
        gameOverTimer?.invalidate()
        countdownTimer?.invalidate()
        typewriterTimer?.invalidate()
        
        // Clear all timer references
        readinessTimer = nil
        gameOverTimer = nil
        countdownTimer = nil
        typewriterTimer = nil
    }
    
    // MARK: - Helper Methods
    func resetGame() {
        print("🔄 RESETTING GAME")
        currentGuess = ""
        currentLives = maxLives
        currentWordIndex = GameConstants.startingWordIndex
        
        // Reset prompt state - will be set through animation later
        currentPrompt = ""
        displayedPrompt = ""
        isGameActive = false
        isContentReady = false
        showFirstLine = false
        displayedFirstLine = ""
        hasServerError = false
        // Reset message tracking
        lastNextWordMessage = ""
        lastIncorrectMessage = ""
        lastGameOverMessage = ""
        lastVictoryMessage = ""
        lastInvalidWordMessage = ""
        // Clear any existing timers
        gameOverTimer?.invalidate()
        countdownTimer?.invalidate()
        typewriterTimer?.invalidate()
        readinessTimer?.invalidate()
        isAnimating = false
        
        // Reset completion tracking for new game
        currentGameCompletion = nil
        isPlayingPreviousGame = false
        
        setupInitialWordChain()
    }
    
    // MARK: - Helper for Non-Repeating Messages
    private func getRandomMessage(from messages: [String], excluding lastMessage: String) -> String {
        let availableMessages = messages.filter { $0 != lastMessage }
        return availableMessages.randomElement() ?? messages.randomElement() ?? messages[0]
    }
    
    func getCurrentWordToGuess() -> String {
        guard currentWordIndex < fullWords.count else { return "" }
        return fullWords[currentWordIndex]
    }
    
    func isGameComplete() -> Bool {
        return currentWordIndex >= fullWords.count - 1
    }
    
    func isGameOver() -> Bool {
        return currentLives <= 0
    }
    
    // MARK: - Game Over Sequence
    private func startGameOverSequence() {
        // Wait before starting countdown
        gameOverTimer = Timer.scheduledTimer(withTimeInterval: GameConstants.Animation.gameOverSequenceDelay, repeats: false) { [weak self] _ in
            self?.startCountdownToMidnight()
        }
    }
    
    private func startCountdownToMidnight() {
        // Animate the initial countdown message
        let timeUntilMidnight = getTimeUntilMidnight()
        let initialMessage = "⏰ Next puzzle in \(formatTime(timeUntilMidnight))"
        animateMessageChange(to: initialMessage)
        
        // Update countdown regularly
        countdownTimer = Timer.scheduledTimer(withTimeInterval: GameConstants.Animation.countdownUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateCountdownMessage()
        }
    }
    
    private func updateCountdownMessage() {
        let timeUntilMidnight = getTimeUntilMidnight()
        let newMessage: String
        
        if timeUntilMidnight.hours == 0 && timeUntilMidnight.minutes == 0 && timeUntilMidnight.seconds == 0 {
            newMessage = "🎯 New puzzle available! Restart the app."
            countdownTimer?.invalidate()
            // Animate the final message since it's a different type
            animateMessageChange(to: newMessage)
        } else {
            newMessage = "⏰ Next puzzle in \(formatTime(timeUntilMidnight))"
            // Update countdown time directly without animation
            currentPrompt = newMessage
            displayedPrompt = newMessage
        }
    }
    
    private func getTimeUntilMidnight() -> (hours: Int, minutes: Int, seconds: Int) {
        let now = Date()
        let calendar = Calendar.current
        
        // Get tomorrow's midnight
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
    
    // MARK: - Typewriter Animation
    enum AnimationSpeed {
        case fast, normal
        
        var wipeInterval: TimeInterval {
            switch self {
            case .fast: return GameConstants.Animation.messageWipeSpeedFast
            case .normal: return GameConstants.Animation.messageWipeSpeedNormal
            }
        }
        
        var typeInterval: TimeInterval {
            switch self {
            case .fast: return GameConstants.Animation.messageTypeSpeedFast
            case .normal: return GameConstants.Animation.messageTypeSpeedNormal
            }
        }
    }
    
    private func animateMessageChange(to newMessage: String, speed: AnimationSpeed = .normal, completion: (() -> Void)? = nil) {
        // Don't animate if already animating or if message is the same
        guard !isAnimating && newMessage != displayedPrompt else { 
            completion?()
            return 
        }
        
        isAnimating = true
        targetMessage = newMessage
        currentPrompt = newMessage // Update the internal state
        
        // Start with wiping the current text
        wipeCurrentText(speed: speed, completion: completion)
    }
    
    private func wipeCurrentText(speed: AnimationSpeed, completion: (() -> Void)?) {
        let currentText = displayedPrompt
        var index = currentText.count
        
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: speed.wipeInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if index > 0 {
                index -= 1
                self.displayedPrompt = String(currentText.prefix(index))
            } else {
                timer.invalidate()
                // Start typing the new message
                self.typeNewText(speed: speed, completion: completion)
            }
        }
    }
    
    private func typeNewText(speed: AnimationSpeed, completion: (() -> Void)?) {
        var index = 0
        
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: speed.typeInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if index < self.targetMessage.count {
                index += 1
                self.displayedPrompt = String(self.targetMessage.prefix(index))
            } else {
                timer.invalidate()
                self.isAnimating = false
                self.displayedPrompt = self.targetMessage
                completion?()
            }
        }
    }
    
    // MARK: - Word Status Helpers
    enum WordStatus {
        case completed
        case incomplete
        case inProgress
        case notStarted
    }
    
    func getWordStatus(for index: Int) -> WordStatus {
        // First and last words are always fully revealed, so don't show indicators for them
        if index == 0 || index == fullWords.count - 1 {
            return .notStarted
        }
        
        // Check if all letters of this word are revealed
        func isWordFullyRevealed(at wordIndex: Int) -> Bool {
            guard wordIndex < fullWords.count else { return false }
            let word = fullWords[wordIndex]
            let revealedCount = revealedLetters[wordIndex] ?? 1 // Default to 1 for middle words
            return revealedCount >= word.count
        }
        
        // If the game is completed, determine status based on final state
        if let completion = currentGameCompletion, completion.isCompleted {
            if index < currentWordIndex {
                // Word was correctly guessed (moved past it)
                return .completed
            } else if isWordFullyRevealed(at: index) {
                // Word had all letters revealed through hints
                return .completed
            } else {
                // Word was incomplete
                return .incomplete
            }
        }
        
        // For active games
        if index < currentWordIndex {
            // Word was correctly guessed (moved past it)
            return .completed
        } else if isWordFullyRevealed(at: index) {
            // Word is fully revealed through hints during active game
            return .completed
        } else if index == currentWordIndex {
            return .inProgress
        } else {
            return .notStarted
        }
    }
    
    deinit {
        // Clean up timers
        readinessTimer?.invalidate()
        gameOverTimer?.invalidate()
        countdownTimer?.invalidate()
        typewriterTimer?.invalidate()
    }
}