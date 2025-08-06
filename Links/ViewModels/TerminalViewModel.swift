//
//  TerminalViewModel.swift
//  Links
//
//  Created by Assistant on 2025-01-14.
//

import SwiftUI
import Combine

/// Manages the terminal display state and animation queue
class TerminalViewModel: ObservableObject {
    // MARK: - Terminal Configuration
    static let totalLines = 30
    static let visibleLines = 25 // Reserve some for scrolling
    
    // MARK: - Published Properties
    @Published var lines: [TerminalLine] = []
    @Published var isProcessingQueue: Bool = false
    
    // MARK: - Animation Queue
    private var animationQueue: [AnimationCommand] = []
    private var currentAnimationCompletion: (() -> Void)?
    
    // MARK: - Animation Commands
    enum AnimationCommand {
        case writeLine(lineIndex: Int, content: String, speed: TimeInterval)
        case replaceLine(lineIndex: Int, content: String, wipeSpeed: TimeInterval, typeSpeed: TimeInterval)
        case clearLine(lineIndex: Int)
        case clearRange(startLine: Int, endLine: Int)
        case clearAll
        case delay(TimeInterval)
        case parallel([AnimationCommand])
        case completion(() -> Void)
    }
    
    init() {
        print("🖥️ TerminalViewModel: Initializing with \(Self.totalLines) lines")
        // Initialize all lines
        for lineNumber in 0..<Self.totalLines {
            lines.append(TerminalLine(lineNumber: lineNumber))
        }
        print("✅ TerminalViewModel: Initialized successfully")
    }
    
    // MARK: - Public API
    
    /// Write content to a specific line with animation
    func writeLine(_ lineIndex: Int, content: String, speed: TimeInterval = GameConstants.Animation.firstLineTypewriterSpeed) {
        enqueueCommand(.writeLine(lineIndex: lineIndex, content: content, speed: speed))
    }
    
    /// Replace content on a line with wipe/type animation
    func replaceLine(_ lineIndex: Int, content: String, wipeSpeed: TimeInterval = GameConstants.Animation.messageWipeSpeedNormal, typeSpeed: TimeInterval = GameConstants.Animation.messageTypeSpeedNormal) {
        enqueueCommand(.replaceLine(lineIndex: lineIndex, content: content, wipeSpeed: wipeSpeed, typeSpeed: typeSpeed))
    }
    
    /// Clear a specific line immediately
    func clearLine(_ lineIndex: Int) {
        enqueueCommand(.clearLine(lineIndex: lineIndex))
    }
    
    /// Clear a range of lines
    func clearRange(from startLine: Int, to endLine: Int) {
        enqueueCommand(.clearRange(startLine: startLine, endLine: endLine))
    }
    
    /// Clear entire terminal
    func clearAll() {
        enqueueCommand(.clearAll)
    }
    
    /// Add a delay to the animation queue
    func delay(_ duration: TimeInterval) {
        enqueueCommand(.delay(duration))
    }
    
    /// Execute multiple commands in parallel
    func parallel(_ commands: [AnimationCommand]) {
        enqueueCommand(.parallel(commands))
    }
    
    /// Add a completion handler to the queue
    func onCompletion(_ handler: @escaping () -> Void) {
        enqueueCommand(.completion(handler))
    }
    
    /// Write multiple lines sequentially starting from a line index
    func writeLines(startingAt lineIndex: Int, lines content: [String], speed: TimeInterval = GameConstants.Animation.firstLineTypewriterSpeed) {
        for (index, line) in content.enumerated() {
            let targetLine = lineIndex + index
            guard targetLine < Self.totalLines else { break }
            writeLine(targetLine, content: line, speed: speed)
        }
    }
    
    /// Get the content at a specific line
    func getContent(at lineIndex: Int) -> String {
        guard lineIndex >= 0 && lineIndex < lines.count else { return "" }
        return lines[lineIndex].content
    }
    
    /// Check if a line is currently animating
    func isLineAnimating(_ lineIndex: Int) -> Bool {
        guard lineIndex >= 0 && lineIndex < lines.count else { return false }
        return lines[lineIndex].isAnimating
    }
    
    /// Check if any animation is in progress
    var isAnimating: Bool {
        isProcessingQueue || lines.contains { $0.isAnimating }
    }
    
    // MARK: - Animation Queue Management
    
    private func enqueueCommand(_ command: AnimationCommand) {
        switch command {
        case .writeLine(let lineIndex, let content, _):
            print("🧪 DEBUG: Enqueuing writeLine for line \(lineIndex): '\(content)'")
        case .completion:
            print("🧪 DEBUG: Enqueuing completion handler")
        default:
            print("🧪 DEBUG: Enqueuing command: \(command)")
        }
        animationQueue.append(command)
        print("🧪 DEBUG: Queue size now: \(animationQueue.count)")
        processQueueIfNeeded()
    }
    
    private func processQueueIfNeeded() {
        guard !isProcessingQueue && !animationQueue.isEmpty else { 
            return 
        }
        
        print("🧪 DEBUG: Starting queue processing")
        isProcessingQueue = true
        processNextCommand()
    }
    
    private func processNextCommand() {
        guard !animationQueue.isEmpty else {
            print("🧪 DEBUG: Queue empty, setting isProcessingQueue = false")
            isProcessingQueue = false
            return
        }
        
        let command = animationQueue.removeFirst()
        print("🧪 DEBUG: Processing next command, queue size now: \(animationQueue.count)")
        executeCommand(command)
    }
    
    private func executeCommand(_ command: AnimationCommand) {
        switch command {
        case .writeLine(let lineIndex, let content, let speed):
            print("🧪 DEBUG: Executing writeLine for line \(lineIndex): '\(content)'")
            guard lineIndex >= 0 && lineIndex < lines.count else {
                print("🧪 DEBUG: Invalid line index \(lineIndex), skipping")
                processNextCommand()
                return
            }
            
            lines[lineIndex].typewrite(content, speed: speed) { [weak self] in
                print("🧪 DEBUG: WriteLine completed for line \(lineIndex)")
                self?.processNextCommand()
            }
            
        case .replaceLine(let lineIndex, let content, let wipeSpeed, let typeSpeed):
            guard lineIndex >= 0 && lineIndex < lines.count else {
                processNextCommand()
                return
            }
            
            lines[lineIndex].replace(with: content, wipeSpeed: wipeSpeed, typeSpeed: typeSpeed) { [weak self] in
                self?.processNextCommand()
            }
            
        case .clearLine(let lineIndex):
            guard lineIndex >= 0 && lineIndex < lines.count else {
                processNextCommand()
                return
            }
            
            lines[lineIndex].clear()
            processNextCommand()
            
        case .clearRange(let startLine, let endLine):
            for lineIndex in startLine...min(endLine, lines.count - 1) {
                lines[lineIndex].clear()
            }
            processNextCommand()
            
        case .clearAll:
            for line in lines {
                line.clear()
            }
            processNextCommand()
            
        case .delay(let duration):
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.processNextCommand()
            }
            
        case .parallel(let commands):
            executeParallelCommands(commands)
            
        case .completion(let handler):
            print("🧪 DEBUG: Executing completion handler")
            handler()
            print("🧪 DEBUG: Completion handler finished")
            processNextCommand()
        }
    }
    
    private func executeParallelCommands(_ commands: [AnimationCommand]) {
        guard !commands.isEmpty else {
            processNextCommand()
            return
        }
        
        let group = DispatchGroup()
        
        for command in commands {
            group.enter()
            
            // Execute each command with a completion wrapper
            switch command {
            case .writeLine(let lineIndex, let content, let speed):
                guard lineIndex >= 0 && lineIndex < lines.count else {
                    group.leave()
                    continue
                }
                
                lines[lineIndex].typewrite(content, speed: speed) {
                    group.leave()
                }
                
            case .replaceLine(let lineIndex, let content, let wipeSpeed, let typeSpeed):
                guard lineIndex >= 0 && lineIndex < lines.count else {
                    group.leave()
                    continue
                }
                
                lines[lineIndex].replace(with: content, wipeSpeed: wipeSpeed, typeSpeed: typeSpeed) {
                    group.leave()
                }
                
            case .clearLine(let lineIndex):
                if lineIndex >= 0 && lineIndex < lines.count {
                    lines[lineIndex].clear()
                }
                group.leave()
                
            default:
                // Other commands not supported in parallel
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.processNextCommand()
        }
    }
    
    // MARK: - Immediate Operations (bypass queue)
    
    /// Set content immediately without animation or queue
    func setImmediate(lineIndex: Int, content: String) {
        guard lineIndex >= 0 && lineIndex < lines.count else { return }
        lines[lineIndex].setImmediate(content)
    }
    
    /// Clear all content immediately
    func clearAllImmediate() {
        for line in lines {
            line.clear()
        }
        animationQueue.removeAll()
        isProcessingQueue = false
    }
}