//
//  PuzzleModels.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import Foundation

struct PuzzleResponse: Codable {
    let puzzles: [DailyPuzzle]
}

struct DailyPuzzle: Codable {
    let date: String // Format: "2025-01-08"
    let words: [String]
    
    // Helper to check if this puzzle is for today
    var isToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        return date == todayString
    }
}

// Fallback puzzle marker for server failures - no actual game content
extension DailyPuzzle {
    static let fallback = DailyPuzzle(
        date: "fallback",
        words: [] // Empty words array - server error state will handle the UI
    )
}