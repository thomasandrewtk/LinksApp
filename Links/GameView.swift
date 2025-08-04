//
//  GameView.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import SwiftUI
import UIKit

struct GameView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = GameViewModel()
    @FocusState private var isTextFieldFocused: Bool
    @State private var isWiping = false
    @State private var showingInfo = false
    
    // MARK: - Color Scheme (Always Dark Mode)
    private var backgroundColor: Color {
        Color.black
    }
    
    private var textColor: Color {
        Color.green
    }
    
    // MARK: - Computed Properties
    private var canSubmit: Bool {
        viewModel.isGameActive && 
        viewModel.isContentReady &&
        !viewModel.isAnimating && 
        !viewModel.hasServerError &&
        !viewModel.currentGuess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header anchored to top
            headerView
            
            // Game content starts right below header
            puzzleContentView
            
            // Spacer pushes input to bottom
            Spacer()
            
            // Input area anchored to bottom
            inputArea
        }
        .background(backgroundColor)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingInfo) {
            InfoView()
        }
        .onAppear {
            isTextFieldFocused = false // Start unfocused
        }
        .onChange(of: viewModel.isGameActive) { _, isActive in
            if isActive {
                // Focus text field when game becomes active
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
                Text("Links/daily")
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
                        viewModel.wipeAllDataAndReset()
                    }
                
                Spacer()
                
                // Lives counter with pixelated heart
                HStack(spacing: 2) {
                    Text("♥")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.red)
                    Text("\(viewModel.currentLives)")
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
    
    // MARK: - Main Puzzle Content
    private var puzzleContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show the first line once content is ready
            if viewModel.showFirstLine {
                // First line (typewritten) - could be puzzle intro or server error
                Text(viewModel.displayedFirstLine)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(textColor)
                
                // Only show game content if no server error
                if !viewModel.hasServerError {
                    // Show word chain if it has content (starts animating after first line)
                    if !viewModel.wordChain.isEmpty {
                        // Empty line for spacing
                        Text("")
                        
                        // Word chain display
                        ForEach(Array(viewModel.wordChain.enumerated()), id: \.offset) { index, word in
                            HStack(spacing: 4) {
                                Text(word)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(textColor)
                                
                                // Status indicator
                                statusIndicator(for: index)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Show host message when there's content to display
                        if !viewModel.displayedPrompt.isEmpty {
                            // Empty line for spacing
                            Text("")
                            
                            // Host message (typewritten)
                            Text(viewModel.displayedPrompt)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(textColor)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Status Indicator
    @ViewBuilder
    private func statusIndicator(for index: Int) -> some View {
        let status = viewModel.getWordStatus(for: index)
        
        switch status {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 12))
                .foregroundColor(.green)
        case .incomplete:
            Image(systemName: "xmark")
                .font(.system(size: 12))
                .foregroundColor(.red)
        case .inProgress, .notStarted:
            EmptyView()
        }
    }
    
    // MARK: - Input Area
    private var inputArea: some View {
        HStack(alignment: .center, spacing: 4) {
            TextField("type a message...", text: $viewModel.currentGuess)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(textColor)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .keyboardType(.asciiCapable)
                .focused($isTextFieldFocused)
                .disabled(!viewModel.isGameActive || !viewModel.isContentReady || viewModel.hasServerError)
                .onSubmit {
                    if canSubmit {
                        viewModel.submitGuess()
                        isTextFieldFocused = true
                    }
                }
                .padding(.leading, 12)
            
            Button(action: {
                if canSubmit {
                    viewModel.submitGuess()
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

}

// MARK: - Preview
#Preview {
    GameView()
}