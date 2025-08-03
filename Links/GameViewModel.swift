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
    
    // MARK: - Game Configuration
    let maxLives: Int = 5
    var puzzleDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy"
        return formatter.string(from: Date())
    }
    
    // MARK: - Game Data
    @Published var fullWords: [String] = []
    private let puzzleService = PuzzleService.shared
    
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
    private var currentWordIndex: Int = 1 // Starting at second word (first guess)
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
    
    init() {
        // Start completely blank, load content silently
        loadTodaysPuzzle()
    }
    
    // MARK: - Content Ready
    private func markContentReady() {
        isContentReady = true
        showFirstLine = true
        print("✅ Content loaded and ready")
        
        // Typewrite the first line, then animate word chain
        let firstLine = "Can you solve today's links? \(puzzleDate)"
        animateFirstLine(to: firstLine) {
            // After first line completes, animate word chain
            self.animateWordChainSimultaneous()
        }
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
                        self.finishLoadingWithPuzzle(puzzle)
                        print("✅ Loaded puzzle for \(puzzle.date)")
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
        fullWords = puzzle.words
        setupInitialWordChain()
        markContentReady()
    }
    
    // MARK: - Setup
    private func setupInitialWordChain() {
        // Don't setup if we don't have words yet
        guard !fullWords.isEmpty else { return }
        
        // Initialize empty word chain for animation, but setup revealed letters
        wordChain = Array(repeating: "", count: fullWords.count)
        revealedLetters = [:]
        
        // Set up revealed letters tracking for middle words
        for (index, word) in fullWords.enumerated() {
            if index != 0 && index != fullWords.count - 1 {
                revealedLetters[index] = 1 // First letter is revealed for middle words
            }
        }
    }
    
    // MARK: - Word Chain Animation
    private func animateWordChainSimultaneous() {
        // Prepare target words for animation
        var targetWords: [String] = []
        
        for (index, word) in fullWords.enumerated() {
            if index == 0 || index == fullWords.count - 1 {
                // First and last words are fully revealed
                targetWords.append(word)
            } else {
                // Middle words show first letter + underscores
                let hiddenWord = String(word.prefix(1)) + String(repeating: "_", count: word.count - 1)
                targetWords.append(hiddenWord)
            }
        }
        
        // Find the maximum word length to know when to stop
        let maxLength = targetWords.map { $0.count }.max() ?? 0
        var currentCharIndex = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
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
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self] timer in
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
        // Typewrite the host message
        let hostMessage = "🤔 What word comes after \(fullWords[0])?"
        animateMessageChange(to: hostMessage, speed: .normal) {
            // After host message completes, activate the game
            self.isGameActive = true
            print("🎮 Game is now active and ready for input")
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
        
        if currentWordIndex < fullWords.count - 1 {
            let previousWord = fullWords[currentWordIndex - 1]
            let randomMessage = getRandomMessage(from: nextWordMessages, excluding: lastNextWordMessage)
            lastNextWordMessage = randomMessage
            let newPrompt = "\(randomMessage) \(previousWord)?"
            animateMessageChange(to: newPrompt)
            print("New prompt: \(newPrompt)")
        } else {
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
        
        if currentLives <= 0 {
            let randomGameOver = getRandomMessage(from: gameOverMessages, excluding: lastGameOverMessage)
            lastGameOverMessage = randomGameOver
            animateMessageChange(to: randomGameOver)
            isGameActive = false
            startGameOverSequence()
            print("💀 GAME OVER!")
        } else {
            // Give a hint by revealing the next letter
            giveHint()
            let randomIncorrect = getRandomMessage(from: incorrectMessages, excluding: lastIncorrectMessage)
            lastIncorrectMessage = randomIncorrect
            animateMessageChange(to: randomIncorrect)
            print("Giving hint - revealed another letter")
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
        }
    }
    
    // MARK: - Word Validation
    private func isValidWord(_ word: String) -> Bool {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic checks - must be at least 2 characters and contain only letters
        guard trimmedWord.count >= 2 && trimmedWord.allSatisfy({ $0.isLetter }) else {
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
            language: "en"
        )
        
        // If rangeOfMisspelledWord returns NSNotFound, the word is valid
        return misspelledRange.location == NSNotFound
    }
    
    // MARK: - Helper Methods
    func resetGame() {
        print("🔄 RESETTING GAME")
        currentGuess = ""
        currentLives = maxLives
        currentWordIndex = 1
        let initialPrompt = "🤔 What word comes after ROAD?"
        currentPrompt = initialPrompt
        displayedPrompt = initialPrompt
        isGameActive = false
        isContentReady = false
        showFirstLine = false
        displayedFirstLine = ""
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
        isAnimating = false
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
        // Wait 2.5 seconds, then start countdown
        gameOverTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.startCountdownToMidnight()
        }
    }
    
    private func startCountdownToMidnight() {
        // Animate the initial countdown message
        let timeUntilMidnight = getTimeUntilMidnight()
        let initialMessage = "⏰ Next puzzle in \(formatTime(timeUntilMidnight))"
        animateMessageChange(to: initialMessage)
        
        // Update every second
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
            case .fast: return 0.005
            case .normal: return 0.015
            }
        }
        
        var typeInterval: TimeInterval {
            switch self {
            case .fast: return 0.008
            case .normal: return 0.025
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
}