//
//  GameView.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import SwiftUI
import UIKit

enum GameMode {
    case today
    case yesterday
}

struct GameView: View {
    // MARK: - ViewModels
    @StateObject private var terminalViewModel = TerminalViewModel()
    @StateObject private var todayGameContent = TodayGameContent()
    @StateObject private var yesterdayGameContent = YesterdayGameContent()
    @FocusState private var isTextFieldFocused: Bool
    @State private var isWiping = false
    @State private var showingInfo = false
    @State private var currentInput: String = ""
    @State private var currentMode: GameMode = .today
    
    // MARK: - Color Scheme (Always Dark Mode)
    private var backgroundColor: Color {
        Color.black
    }
    
    private var textColor: Color {
        Color.green
    }
    
    // MARK: - Computed Properties
    private var canSubmit: Bool {
        switch currentMode {
        case .today:
            return todayGameContent.isActive &&
                   !terminalViewModel.isAnimating &&
                   !todayGameContent.hasServerError &&
                   !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .yesterday:
            return yesterdayGameContent.isActive &&
                   !terminalViewModel.isAnimating &&
                   !yesterdayGameContent.hasServerError &&
                   !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header anchored to top
            headerView
            
            // Terminal content with tap detection
            TerminalViewSimple(viewModel: terminalViewModel)
                .frame(maxHeight: .infinity)
                .onTapGesture(count: 1, perform: handleTerminalTap)
            
            // Input area anchored to bottom
            inputArea
        }
        .background(backgroundColor)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingInfo) {
            InfoView()
        }
        .onAppear {
            print("🎮 GameView appeared")
            isTextFieldFocused = false
            todayGameContent.configure(with: terminalViewModel)
            yesterdayGameContent.configure(with: terminalViewModel)
            startCurrentGame()
        }
        .onChange(of: todayGameContent.isActive) { _, isActive in
            if currentMode == .today && isActive && !todayGameContent.isGameCompleted {
                // Focus text field when today's game becomes active (only for incomplete games)
                DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.Animation.gameActivationDelay) {
                    isTextFieldFocused = true
                }
            }
        }
        .onChange(of: yesterdayGameContent.isActive) { _, isActive in
            if currentMode == .yesterday && isActive && !yesterdayGameContent.isGameCompleted {
                // Focus text field when yesterday's game becomes active (only for incomplete games)
                DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.Animation.gameActivationDelay) {
                    isTextFieldFocused = true
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(currentMode == .today ? "Links/daily" : "Links/yesterday")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(isWiping ? .red : textColor)
                    .scaleEffect(isWiping ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isWiping)
                    .onTapGesture(count: 1) {
                        // Single tap shows info screen
                        showingInfo = true
                    }
                    .onTapGesture(count: 3) {
                        print("🧨 Triple-tap detected! Wiping all data...")
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                        
                        // Visual feedback
                        withAnimation {
                            isWiping = true
                        }
                        
                        // Reset visual after a moment
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                isWiping = false
                            }
                        }
                        
                        // Wipe data
                        wipeAllDataAndReset()
                    }
                
                Spacer()
                
                // Lives counter with pixelated heart
                HStack(spacing: 2) {
                    Text("♥")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.red)
                    Text("\(currentMode == .today ? todayGameContent.currentLives : yesterdayGameContent.currentLives)")
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
                .background(textColor)
        }
        .background(backgroundColor)
    }

    
    // MARK: - Input Area
    private var inputArea: some View {
        HStack(alignment: .center, spacing: 4) {
            TextField("type a message...", text: $currentInput)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(textColor)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .keyboardType(.asciiCapable)
                .focused($isTextFieldFocused)
                .disabled({
                    switch currentMode {
                    case .today:
                        return !todayGameContent.isActive || todayGameContent.hasServerError
                    case .yesterday:
                        return !yesterdayGameContent.isActive || yesterdayGameContent.hasServerError
                    }
                }())
                .onSubmit {
                    if canSubmit {
                        submitGuess()
                        isTextFieldFocused = true
                    }
                }
                .padding(.leading, 12)
            
            Button(action: {
                if canSubmit {
                    submitGuess()
                    isTextFieldFocused = true
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(canSubmit ? textColor : textColor.opacity(0.3))
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 8)
        .background(backgroundColor)
        .onTapGesture {
            isTextFieldFocused = true
        }
    }
    
    // MARK: - Actions
    private func submitGuess() {
        switch currentMode {
        case .today:
            todayGameContent.handleInput(currentInput)
        case .yesterday:
            yesterdayGameContent.handleInput(currentInput)
        }
        currentInput = ""
    }
    
    private func startCurrentGame() {
        switch currentMode {
        case .today:
            todayGameContent.start()
        case .yesterday:
            yesterdayGameContent.start()
        }
    }
    
    private func handleTerminalTap() {
        print("🧪 DEBUG: Terminal tap detected")
        print("🧪 DEBUG: Current mode: \(currentMode)")
        
        // Debug: Show content of lines around the navigation area
        for i in 18...25 {
            let content = terminalViewModel.getContent(at: i)
            if !content.isEmpty {
                print("🧪 DEBUG: Line \(i+1): '\(content)'")
            }
        }
        
        // Check navigation line (Line 22, 0-indexed is 21)
        let navigationLineContent = terminalViewModel.getContent(at: 21)
        print("🧪 DEBUG: Navigation line content: '\(navigationLineContent)'")
        
        // Check navigation line first
        if navigationLineContent.lowercased().contains("[yesterday]") && currentMode == .today {
            print("🔗 Navigating to yesterday's game")
            switchToYesterday()
            return
        } else if navigationLineContent.lowercased().contains("[today]") && currentMode == .yesterday {
            print("🔗 Navigating to today's game")
            switchToToday()
            return
        }
        
        // If navigation line doesn't match, check all terminal content for navigation links
        let allTerminalContent = (0..<30).map { terminalViewModel.getContent(at: $0) }.joined(separator: " ")
        print("🧪 DEBUG: Checking all terminal content for navigation...")
        
        if allTerminalContent.lowercased().contains("[yesterday]") && currentMode == .today {
            print("🔗 Found [yesterday] in terminal, navigating to yesterday's game")
            switchToYesterday()
        } else if allTerminalContent.lowercased().contains("[today]") && currentMode == .yesterday {
            print("🔗 Found [today] in terminal, navigating to today's game")
            switchToToday()
        } else {
            print("🧪 DEBUG: No navigation match found in any content")
            print("🧪 DEBUG: Looking for '[yesterday]' in today mode or '[today]' in yesterday mode")
        }
    }
    
    private func switchToYesterday() {
        print("🔄 Switching to yesterday mode")
        currentMode = .yesterday
        todayGameContent.pauseTimers()  // Stop today's timers to prevent interference
        terminalViewModel.clearAllImmediate()
        yesterdayGameContent.start()
    }
    
    private func switchToToday() {
        print("🔄 Switching to today mode")
        currentMode = .today
        todayGameContent.resumeTimers()  // IMPORTANT: Resume timers BEFORE clearing terminal
        terminalViewModel.clearAllImmediate()
        todayGameContent.start()
    }
    
    private func wipeAllDataAndReset() {
        print("🧨 DEBUG: Wiping all data and completely reinitializing app...")
        
        // Clear the terminal
        terminalViewModel.clearAllImmediate()
        
        // Wipe all SwiftData
        GameCompletionService.shared.wipeAllData()
        
        // Clear all notifications
        Task {
            await NotificationManager.shared.clearAllNotifications()
        }
        
        // Clear cache
        PuzzleService.shared.clearCache()
        
        // Reset game content
        todayGameContent.reset()
        yesterdayGameContent.reset()
        currentMode = .today
        
        // Give a brief moment for everything to settle, then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.startCurrentGame()
            
            // Reschedule notifications
            Task {
                await NotificationManager.shared.requestPermissionAndSchedule()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    GameView()
}