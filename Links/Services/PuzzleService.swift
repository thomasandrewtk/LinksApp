//
//  PuzzleService.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import Foundation
import Combine

class PuzzleService: ObservableObject {
    static let shared = PuzzleService()
    
    @Published var todaysPuzzle: DailyPuzzle?
    @Published var isLoading: Bool = false
    @Published var lastFetchError: String?
    
    private let serverURL = "https://links-api.tandrewtk.workers.dev/api/puzzles"
    private var midnightTimer: Timer?
    
    private init() {
        setupMidnightTimer()
    }
    
    // MARK: - Public Methods
    func clearCache() {
        print("🗑️ Clearing puzzle cache")
        todaysPuzzle = nil
        lastFetchError = nil
        isLoading = false
    }
    
    func fetchTodaysPuzzle() async {
        await MainActor.run {
            isLoading = true
            lastFetchError = nil
        }
        
        do {
            let puzzle = try await fetchPuzzleFromServer()
            await MainActor.run {
                self.todaysPuzzle = puzzle
                self.isLoading = false
                print("✅ Fetched today's puzzle: \(puzzle.date)")
            }
        } catch {
            await MainActor.run {
                self.lastFetchError = error.localizedDescription
                self.todaysPuzzle = DailyPuzzle.fallback // Use fallback puzzle
                self.isLoading = false
                print("❌ Failed to fetch puzzle, using fallback: \(error)")
            }
        }
    }
    
    func fetchPuzzleForDate(_ dateString: String) async throws -> DailyPuzzle {
        do {
            let puzzle = try await fetchPuzzleFromServer(for: dateString)
            print("✅ Fetched puzzle for \(dateString): \(puzzle.date)")
            return puzzle
        } catch {
            print("❌ Failed to fetch puzzle for \(dateString): \(error)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    private func fetchPuzzleFromServer(for dateString: String? = nil) async throws -> DailyPuzzle {
        // Use provided date or default to today
        let targetDate: String
        if let dateString = dateString {
            targetDate = dateString
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            targetDate = formatter.string(from: Date())
        }
        
        // Build URL with date query parameter
        guard var urlComponents = URLComponents(string: serverURL) else {
            throw PuzzleError.invalidURL
        }
        urlComponents.queryItems = [URLQueryItem(name: "date", value: targetDate)]
        
        guard let url = urlComponents.url else {
            throw PuzzleError.invalidURL
        }
        
        print("🌐 Fetching puzzle from: \(url)")
        
        // Make network request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PuzzleError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PuzzleError.serverError(httpResponse.statusCode)
        }
        
        // Parse JSON response
        let puzzleResponse = try JSONDecoder().decode(PuzzleResponse.self, from: data)
        
        // Find the puzzle for the target date
        guard let targetPuzzle = puzzleResponse.puzzles.first(where: { $0.date == targetDate }) else {
            throw PuzzleError.noPuzzleForToday
        }
        
        // Validate puzzle has expected number of words
        guard targetPuzzle.words.count == GameConstants.expectedWordCount else {
            throw PuzzleError.invalidPuzzleFormat
        }
        
        return targetPuzzle
    }
    
    private func setupMidnightTimer() {
        // Calculate time until next midnight
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let midnight = calendar.startOfDay(for: tomorrow)
        
        // Schedule timer for midnight
        midnightTimer = Timer(fireAt: midnight, interval: 24 * 60 * 60, target: self, selector: #selector(midnightTriggered), userInfo: nil, repeats: true)
        RunLoop.main.add(midnightTimer!, forMode: .common)
        
        print("⏰ Midnight timer set for: \(midnight)")
    }
    
    @objc private func midnightTriggered() {
        print("🕛 Midnight! Fetching new puzzle...")
        Task {
            await fetchTodaysPuzzle()
        }
    }
    
    deinit {
        midnightTimer?.invalidate()
    }
}

// MARK: - Error Types
enum PuzzleError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case noPuzzleForToday
    case invalidPuzzleFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .noPuzzleForToday:
            return "No puzzle available for today"
        case .invalidPuzzleFormat:
            return "Puzzle format is invalid"
        }
    }
}