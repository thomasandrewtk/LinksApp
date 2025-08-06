//
//  TerminalView.swift
//  Links
//
//  Created by Assistant on 2025-01-14.
//

import SwiftUI

/// A terminal-style view with fixed line positions and consistent animations
struct TerminalView: View {
    @ObservedObject var viewModel: TerminalViewModel
    
    // Terminal styling
    private let backgroundColor = Color.black
    private let textColor = Color.green
    private let lineHeight: CGFloat = 20
    private let fontSize: CGFloat = 14
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.lines.enumerated()), id: \.element.id) { index, line in
                        HStack(spacing: 8) {
                            // Line number
                            Text(String(format: "%3d", index + 1))
                                .font(.system(size: fontSize - 2, design: .monospaced))
                                .foregroundColor(textColor.opacity(0.3))
                                .frame(width: 30, alignment: .trailing)
                            
                            // Line content - using TerminalLineView for proper observation
                            TerminalLineView(line: line, fontSize: fontSize, textColor: textColor, lineHeight: lineHeight)
                        }
                        .frame(height: lineHeight)
                        .frame(maxWidth: .infinity)
                        .id(index)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(backgroundColor)
            .onAppear {
                // Scroll to top on appear
                withAnimation {
                    proxy.scrollTo(0, anchor: .top)
                }
            }
        }
    }
}

/// A simplified terminal view without line numbers
struct TerminalViewSimple: View {
    @ObservedObject var viewModel: TerminalViewModel
    
    // Terminal styling
    private let backgroundColor = Color.black
    private let textColor = Color.green
    private let lineHeight: CGFloat = 20
    private let fontSize: CGFloat = 14
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.lines, id: \.id) { line in
                        TerminalLineView(line: line, fontSize: fontSize, textColor: textColor, lineHeight: lineHeight)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(backgroundColor)
        }
    }
}

/// Individual line view that properly observes TerminalLine changes
struct TerminalLineView: View {
    @ObservedObject var line: TerminalLine
    let fontSize: CGFloat
    let textColor: Color
    let lineHeight: CGFloat
    
    var body: some View {
        Text(line.displayedContent)
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: lineHeight)
    }
}

// MARK: - Preview
#Preview("Terminal with Line Numbers") {
    let viewModel = TerminalViewModel()
    
    // Demo content
    viewModel.setImmediate(lineIndex: 0, content: "Welcome to Links Terminal")
    viewModel.setImmediate(lineIndex: 1, content: "=======================")
    viewModel.setImmediate(lineIndex: 3, content: "Loading today's puzzle...")
    
    return TerminalView(viewModel: viewModel)
}

#Preview("Simple Terminal") {
    let viewModel = TerminalViewModel()
    
    viewModel.setImmediate(lineIndex: 0, content: "Links/daily")
    viewModel.setImmediate(lineIndex: 2, content: "Can you solve today's links?")
    
    return TerminalViewSimple(viewModel: viewModel)
}