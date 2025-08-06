//
//  TerminalLine.swift
//  Links
//
//  Created by Assistant on 2025-01-14.
//

import Foundation
import Combine

/// Represents a single line in the terminal display
class TerminalLine: ObservableObject, Identifiable {
    let id = UUID()
    let lineNumber: Int
    
    @Published var content: String = ""
    @Published var displayedContent: String = ""
    @Published var isAnimating: Bool = false
    
    // Animation state
    private var targetContent: String = ""
    private var animationTimer: Timer?
    private var animationCompletion: (() -> Void)?
    
    init(lineNumber: Int) {
        self.lineNumber = lineNumber
    }
    
    /// Set content immediately without animation
    func setImmediate(_ content: String) {
        self.content = content
        self.displayedContent = content
        self.targetContent = content
        cancelAnimation()
    }
    
    /// Clear the line immediately
    func clear() {
        setImmediate("")
    }
    
    /// Animate typing new content
    func typewrite(_ content: String, speed: TimeInterval = GameConstants.Animation.firstLineTypewriterSpeed, completion: (() -> Void)? = nil) {
        print("🧪 DEBUG: TerminalLine.typewrite called with content: '\(content)' on line \(lineNumber)")
        
        // Cancel any existing animation
        cancelAnimation()
        
        // If content is empty, just clear
        if content.isEmpty {
            clear()
            print("🧪 DEBUG: TerminalLine \(lineNumber) - empty content, calling completion immediately")
            completion?()
            return
        }
        
        // Set up new animation
        self.content = content
        self.targetContent = content
        self.displayedContent = ""
        self.isAnimating = true
        self.animationCompletion = completion
        
        print("🧪 DEBUG: TerminalLine \(lineNumber) - starting typewriter animation for \(content.count) characters")
        
        var currentIndex = 0
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { [weak self] timer in
            guard let self = self else {
                print("🧪 DEBUG: TerminalLine timer - self is nil, invalidating")
                timer.invalidate()
                return
            }
            
            if currentIndex < self.targetContent.count {
                currentIndex += 1
                self.displayedContent = String(self.targetContent.prefix(currentIndex))
                // Progress logging only for debugging
                if currentIndex == self.targetContent.count {
                    print("🧪 DEBUG: TerminalLine \(self.lineNumber) - typed \(currentIndex)/\(self.targetContent.count) characters")
                }
            } else {
                print("🧪 DEBUG: TerminalLine \(self.lineNumber) - animation complete, calling finishAnimation()")
                self.finishAnimation()
            }
        }
    }
    
    /// Animate replacing current content with new content (wipe then type)
    func replace(with newContent: String, wipeSpeed: TimeInterval = GameConstants.Animation.messageWipeSpeedNormal, typeSpeed: TimeInterval = GameConstants.Animation.messageTypeSpeedNormal, completion: (() -> Void)? = nil) {
        // Cancel any existing animation
        cancelAnimation()
        
        // If no current content, just typewrite
        if displayedContent.isEmpty {
            typewrite(newContent, speed: typeSpeed, completion: completion)
            return
        }
        
        // Start wipe animation
        self.isAnimating = true
        self.targetContent = newContent
        self.content = newContent
        self.animationCompletion = completion
        
        var currentLength = displayedContent.count
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: wipeSpeed, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if currentLength > 0 {
                currentLength -= 1
                self.displayedContent = String(self.displayedContent.prefix(currentLength))
            } else {
                timer.invalidate()
                // Now typewrite new content
                self.typewrite(self.targetContent, speed: typeSpeed, completion: self.animationCompletion)
            }
        }
    }
    
    private func cancelAnimation() {
        if animationTimer != nil {
            print("🧪 DEBUG: TerminalLine \(lineNumber) - cancelAnimation() called, invalidating timer")
        }
        animationTimer?.invalidate()
        animationTimer = nil
        isAnimating = false
        animationCompletion = nil
    }
    
    private func finishAnimation() {
        print("🧪 DEBUG: TerminalLine \(lineNumber) - finishAnimation() called")
        
        // Save the completion callback before canceling
        let completion = animationCompletion
        
        cancelAnimation()
        displayedContent = targetContent
        
        print("🧪 DEBUG: TerminalLine \(lineNumber) - calling animationCompletion callback")
        completion?()
        print("🧪 DEBUG: TerminalLine \(lineNumber) - animationCompletion callback finished")
    }
    
    deinit {
        cancelAnimation()
    }
}
