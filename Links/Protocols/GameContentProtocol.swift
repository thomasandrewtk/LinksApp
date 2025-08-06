//
//  GameContentProtocol.swift
//  Links
//
//  Created by Assistant on 2025-01-14.
//

import Foundation

/// Protocol for providing content to the terminal display
protocol GameContentProtocol {
    /// The terminal view model to write content to
    var terminal: TerminalViewModel { get }
    
    /// Start displaying content
    func start()
    
    /// Handle user input
    func handleInput(_ input: String)
    
    /// Reset the content
    func reset()
    
    /// Whether the content is currently active and accepting input
    var isActive: Bool { get }
}

/// Base content provider with common functionality
class BaseGameContent: GameContentProtocol {
    let terminal: TerminalViewModel
    var isActive: Bool = false
    
    init(terminal: TerminalViewModel) {
        self.terminal = terminal
    }
    
    func start() {
        isActive = true
    }
    
    func handleInput(_ input: String) {
        // Override in subclasses
    }
    
    func reset() {
        isActive = false
        terminal.clearAllImmediate()
    }
    
    // MARK: - Helper Methods
    
    /// Get a random message avoiding the last used one
    func getRandomMessage(from messages: [String], excluding lastMessage: String) -> String {
        let availableMessages = messages.filter { $0 != lastMessage }
        return availableMessages.randomElement() ?? messages.randomElement() ?? messages[0]
    }
}