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
        viewModel.isGameActive && !viewModel.currentGuess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            isTextFieldFocused = viewModel.isGameActive
        }
        .onChange(of: viewModel.isGameActive) { _, isActive in
            if !isActive {
                isTextFieldFocused = false
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
            // Puzzle intro
            Text("Can you solve today's links? \(viewModel.puzzleDate)")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(textColor)
            
            // Empty line for spacing
            Text("")
            
            // Word chain display
            ForEach(Array(viewModel.wordChain.enumerated()), id: \.offset) { index, word in
                Text(word)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(textColor)
            }
            
            // Empty line for spacing
            Text("")
            
            // Current prompt with typewriter animation
            Text(viewModel.displayedPrompt)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(textColor)
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
                .disabled(!viewModel.isGameActive)
                .onSubmit {
                    if viewModel.isGameActive && !viewModel.currentGuess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.submitGuess()
                        isTextFieldFocused = true
                    }
                }
                .padding(.leading, 12)
            
            Button(action: {
                if viewModel.isGameActive && !viewModel.currentGuess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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