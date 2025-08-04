//
//  GameCompletionService.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
class GameCompletionService: ObservableObject {
    static let shared = GameCompletionService()
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    // Call this when the model context is available
    func configure(with context: ModelContext) {
        self.modelContext = context
        print("🔗 GameCompletionService configured with SwiftData context")
    }
    
    // Check if the service is ready to use
    var isReady: Bool {
        return modelContext != nil
    }
    
    // MARK: - Game Completion Management
    
    /// Get or create a game completion record for a specific date
    func getGameCompletion(for gameDate: String) -> GameCompletion? {
        guard let context = modelContext else { return nil }
        
        let predicate = #Predicate<GameCompletion> { completion in
            completion.gameDate == gameDate
        }
        
        let descriptor = FetchDescriptor<GameCompletion>(predicate: predicate)
        
        do {
            let completions = try context.fetch(descriptor)
            return completions.first
        } catch {
            print("❌ Error fetching game completion: \(error)")
            return nil
        }
    }
    
    /// Create a new game completion record for a date
    func createGameCompletion(for gameDate: String, totalWords: Int) -> GameCompletion {
        guard let context = modelContext else {
            // Return a temporary object if context not available
            return GameCompletion(gameDate: gameDate, totalWords: totalWords)
        }
        
        let completion = GameCompletion(gameDate: gameDate, totalWords: totalWords)
        context.insert(completion)
        
        do {
            try context.save()
            print("✅ Created game completion record for \(gameDate)")
        } catch {
            print("❌ Error saving game completion: \(error)")
        }
        
        return completion
    }
    
    /// Update game progress (called after each correct guess)
    func updateProgress(for gameDate: String, wordsCompleted: Int, currentWordIndex: Int, revealedLetters: [Int: Int] = [:]) {
        guard let context = modelContext,
              let completion = getGameCompletion(for: gameDate) else { return }
        
        completion.wordsCompleted = wordsCompleted
        completion.currentWordIndex = currentWordIndex
        completion.revealedLetters = revealedLetters
        
        do {
            try context.save()
            print("📝 Updated progress for \(gameDate): \(wordsCompleted)/\(completion.totalWords) words")
        } catch {
            print("❌ Error updating progress: \(error)")
        }
    }
    
    /// Mark a game as completed
    func markGameCompleted(for gameDate: String, livesUsed: Int, didWin: Bool) {
        guard let context = modelContext,
              let completion = getGameCompletion(for: gameDate) else { return }
        
        completion.markCompleted(livesUsed: livesUsed, didWin: didWin)
        
        do {
            try context.save()
            print("🎉 Marked game completed for \(gameDate) with \(livesUsed) lives used - \(didWin ? "VICTORY" : "DEFEAT")")
        } catch {
            print("❌ Error marking game completed: \(error)")
        }
    }
    
    /// Update lives used (called when lives are lost)
    func updateLivesUsed(for gameDate: String, livesUsed: Int) {
        guard let context = modelContext,
              let completion = getGameCompletion(for: gameDate) else { return }
        
        completion.livesUsed = livesUsed
        
        do {
            try context.save()
            print("💔 Updated lives used for \(gameDate): \(livesUsed)")
        } catch {
            print("❌ Error updating lives used: \(error)")
        }
    }
    
    // MARK: - Query Methods
    
    /// Check if today's game is completed
    func isTodayGameCompleted() -> Bool {
        let todayDate = GameCompletion.todayDateString()
        return getGameCompletion(for: todayDate)?.isCompleted ?? false
    }
    
    /// Check if yesterday's game is completed
    func isYesterdayGameCompleted() -> Bool {
        let yesterdayDate = GameCompletion.yesterdayDateString()
        return getGameCompletion(for: yesterdayDate)?.isCompleted ?? false
    }
    
    /// Get all incomplete games (for showing available games to play)
    func getIncompleteGames() -> [GameCompletion] {
        guard let context = modelContext else { return [] }
        
        let predicate = #Predicate<GameCompletion> { completion in
            !completion.isCompleted
        }
        
        let descriptor = FetchDescriptor<GameCompletion>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.gameDate, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ Error fetching incomplete games: \(error)")
            return []
        }
    }
    
    /// Get recent completed games (for stats/history)
    func getRecentCompletedGames(limit: Int = 10) -> [GameCompletion] {
        guard let context = modelContext else { return [] }
        
        let predicate = #Predicate<GameCompletion> { completion in
            completion.isCompleted
        }
        
        var descriptor = FetchDescriptor<GameCompletion>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.gameDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ Error fetching completed games: \(error)")
            return []
        }
    }
    
    /// Get yesterday's game if it exists and is incomplete
    func getYesterdayGameIfIncomplete() -> GameCompletion? {
        let yesterdayDate = GameCompletion.yesterdayDateString()
        let completion = getGameCompletion(for: yesterdayDate)
        return completion?.isCompleted == false ? completion : nil
    }
    
    // MARK: - Statistics
    
    /// Get completion statistics
    func getCompletionStats() -> (totalCompletedGames: Int, gamesWon: Int, winRate: Double) {
        guard let context = modelContext else { return (0, 0, 0.0) }
        
        let completedPredicate = #Predicate<GameCompletion> { completion in
            completion.isCompleted
        }
        let completedDescriptor = FetchDescriptor<GameCompletion>(predicate: completedPredicate)
        
        let wonPredicate = #Predicate<GameCompletion> { completion in
            completion.isCompleted && completion.didWin
        }
        let wonDescriptor = FetchDescriptor<GameCompletion>(predicate: wonPredicate)
        
        do {
            let totalCompletedGames = try context.fetch(completedDescriptor).count
            let gamesWon = try context.fetch(wonDescriptor).count
            let winRate = totalCompletedGames > 0 ? Double(gamesWon) / Double(totalCompletedGames) : 0.0
            
            return (totalCompletedGames, gamesWon, winRate)
        } catch {
            print("❌ Error fetching stats: \(error)")
            return (0, 0, 0.0)
        }
    }
    
    // MARK: - Cleanup
    
    /// WIPE ALL DATA - Debug only!
    func wipeAllData() {
        guard let context = modelContext else { return }
        
        print("🧨 WIPING ALL SWIFTDATA...")
        
        let descriptor = FetchDescriptor<GameCompletion>()
        
        do {
            let allRecords = try context.fetch(descriptor)
            for record in allRecords {
                context.delete(record)
            }
            try context.save()
            print("🗑️ Wiped \(allRecords.count) game completion records")
        } catch {
            print("❌ Error wiping data: \(error)")
        }
    }
    
    /// Clean up old game records (keep last 30 days)
    func cleanupOldRecords() {
        guard let context = modelContext else { return }
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let cutoffDateString = GameCompletion.dateString(for: thirtyDaysAgo)
        
        let predicate = #Predicate<GameCompletion> { completion in
            completion.gameDate < cutoffDateString
        }
        
        let descriptor = FetchDescriptor<GameCompletion>(predicate: predicate)
        
        do {
            let oldRecords = try context.fetch(descriptor)
            for record in oldRecords {
                context.delete(record)
            }
            try context.save()
            print("🧹 Cleaned up \(oldRecords.count) old game records")
        } catch {
            print("❌ Error cleaning up old records: \(error)")
        }
    }
}