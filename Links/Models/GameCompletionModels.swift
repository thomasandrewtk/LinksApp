//
//  GameCompletionModels.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import Foundation
import SwiftData

@Model
class GameCompletion {
    var gameDate: String = "" // Format: "yyyy-MM-dd" to match DailyPuzzle
    var isCompleted: Bool = false
    var didWin: Bool = false // Explicitly track whether the player won or lost
    var completionDate: Date?
    var livesUsed: Int = 0
    var totalWords: Int = 0
    var wordsCompleted: Int = 0
    var currentWordIndex: Int = 1 // For resuming incomplete games
    var revealedLetters: [Int: Int] = [:] // wordIndex: number of letters revealed
    
    init(gameDate: String, isCompleted: Bool = false, didWin: Bool = false, livesUsed: Int = 0, totalWords: Int = 0, wordsCompleted: Int = 0, currentWordIndex: Int = 1) {
        self.gameDate = gameDate
        self.isCompleted = isCompleted
        self.didWin = didWin
        self.completionDate = isCompleted ? Date() : nil
        self.livesUsed = livesUsed
        self.totalWords = totalWords
        self.wordsCompleted = wordsCompleted
        self.currentWordIndex = currentWordIndex
        self.revealedLetters = [:]
    }
    
    // Helper to mark game as completed
    func markCompleted(livesUsed: Int, didWin: Bool) {
        self.isCompleted = true
        self.didWin = didWin
        self.completionDate = Date()
        self.livesUsed = livesUsed
        // Keep the current wordsCompleted value - don't assume total completion
    }
    
    // Helper to check if this is today's game
    var isToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        return gameDate == todayString
    }
    
    // Helper to check if this is yesterday's game
    var isYesterday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayString = formatter.string(from: yesterday)
        return gameDate == yesterdayString
    }
    
    // Helper to get formatted date for display
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: gameDate) {
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
        return gameDate
    }
    
    // Helper to get how many days ago this was
    var daysAgo: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let gameDate = formatter.date(from: self.gameDate) else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: gameDate, to: Date()).day ?? 0
        return days
    }
}

// MARK: - Helper Extensions
extension GameCompletion {
    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    static func yesterdayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return formatter.string(from: yesterday)
    }
    
    static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}