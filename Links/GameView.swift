//
//  GameView.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import SwiftUI

struct GameView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = GameViewModel()
    @FocusState private var isTextFieldFocused: Bool
    
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
        .onAppear {
            isTextFieldFocused = false // Start unfocused
        }
        .onChange(of: viewModel.isGameActive) { _, isActive in
            if isActive {
                // Focus text field when game becomes active
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
                    .foregroundColor(textColor)
                
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
                // First line (typewritten)
                Text(viewModel.displayedFirstLine)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(textColor)
                
                // Show word chain if it has content (starts animating after first line)
                if !viewModel.wordChain.isEmpty {
                    // Empty line for spacing
                    Text("")
                    
                    // Word chain display
                    ForEach(Array(viewModel.wordChain.enumerated()), id: \.offset) { index, word in
                        Text(word)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(textColor)
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
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .disabled(!viewModel.isGameActive || !viewModel.isContentReady)
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