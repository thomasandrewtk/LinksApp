//
//  InfoView.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Color Scheme (Always Dark Mode)
    private var backgroundColor: Color {
        Color.black
    }
    
    private var textColor: Color {
        Color.green
    }
    
    private var accentColor: Color {
        Color.green.opacity(0.8)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // How to Play
                    howToPlaySection
                    
                    // Game Features
                    gameFeaturesSection
                    
                    // Privacy & Data
                    privacySection
                    
                    // Tips
                    tipsSection
                    
                    // Debug/Notifications (only in debug builds)
                    #if DEBUG
                    notificationDebugSection
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(backgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(textColor)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("links")
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundColor(textColor)
            
            Text("daily word puzzle")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(accentColor)
        }
        .padding(.top, 16)
    }
    
    // MARK: - How to Play Section
    private var howToPlaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("HOW TO PLAY")
            
            infoItem(
                icon: "link",
                title: "guess the chain",
                description: "find the missing words that connect the first word to the last word in sequence"
            )
            
            infoItem(
                icon: "textformat.abc",
                title: "type your guess",
                description: "enter a valid english word that you think comes next in the chain"
            )
            
            infoItem(
                icon: "lightbulb",
                title: "get hints",
                description: "wrong guesses reveal the next letter of the target word as a hint"
            )
            
            infoItem(
                icon: "target",
                title: "complete the puzzle",
                description: "fill in all the missing words before running out of lives"
            )
        }
    }
    
    // MARK: - Game Features Section
    private var gameFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("FEATURES")
            
            infoItem(
                icon: "heart.fill",
                title: "lives system",
                description: "start with 5 lives. wrong guesses cost 1 life. invalid words don't count."
            )
            
            infoItem(
                icon: "eye",
                title: "progressive hints",
                description: "each wrong guess reveals another letter until the word is complete"
            )
            
            infoItem(
                icon: "checkmark.circle",
                title: "status indicators",
                description: "✓ for correctly guessed words, ✗ for incomplete words"
            )
            
            infoItem(
                icon: "calendar",
                title: "daily puzzles",
                description: "new puzzle every day at midnight. progress saves automatically"
            )
            
            infoItem(
                icon: "clock.arrow.circlepath",
                title: "resume games",
                description: "pick up where you left off, even after closing the app"
            )
            
            infoItem(
                icon: "bell",
                title: "smart reminders",
                description: "snarky notifications at midnight for new puzzles and 3pm reminders if unfinished"
            )
        }
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("PRIVACY")
            
            infoItem(
                icon: "iphone",
                title: "local storage",
                description: "all game progress stored locally on your device using swiftdata"
            )
            
            infoItem(
                icon: "wifi.slash",
                title: "offline capable",
                description: "plays offline with cached puzzles when network unavailable"
            )
            
            infoItem(
                icon: "hand.raised.fill",
                title: "panic mode",
                description: "triple-tap the title to instantly clear all data and reset the app"
            )
        }
    }
    
    // MARK: - Tips Section
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("TIPS")
            
            VStack(alignment: .leading, spacing: 8) {
                tipItem("think about word associations, themes, and categories")
                tipItem("the first and last words are always fully visible")
                tipItem("middle words start with their first letter revealed")
                tipItem("use @mentions to notify specific people... wait, wrong app 😉")
                tipItem("hints accumulate - each wrong guess reveals more letters")
                tipItem("words auto-complete when all letters are revealed through hints")
            }
        }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundColor(textColor)
            .padding(.top, 8)
    }
    
    private func infoItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(textColor)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(accentColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func tipItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(accentColor)
            
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(accentColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    #if DEBUG
    // MARK: - Debug Notification Section
    private var notificationDebugSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("DEBUG - NOTIFICATIONS")
            
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await NotificationManager.shared.printScheduledNotifications()
                    }
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                            .foregroundColor(accentColor)
                        Text("Print Scheduled Notifications")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(textColor)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    Task {
                        await NotificationManager.shared.scheduleNotificationsIfNeeded()
                    }
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(accentColor)
                        Text("Refresh Notifications")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(textColor)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    Task {
                        await NotificationManager.shared.clearAllNotifications()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Clear All Notifications")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    #endif
}

// MARK: - Preview
#Preview {
    InfoView()
}