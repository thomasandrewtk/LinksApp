# Links Game - Complete System Documentation

## Overview

Links is a daily word puzzle game with a terminal/console aesthetic. Players must guess a sequence of connected words in a chain, with each word linking to the next through some logical connection. The game features a retro green-on-black terminal interface with typewriter animations.

## Game Mechanics

### Core Concept
- Players are presented with a chain of words where most words are hidden
- The first and last words in the chain are always fully visible
- Players must guess the missing words in sequence
- Each word is connected to the next word in some logical way (themes, categories, word associations, etc.)

### Lives System
- Players start with 5 lives (♥ counter in top-right)
- Incorrect guesses cost 1 life
- Invalid words (not in dictionary) don't cost lives
- Game ends when lives reach 0

### Hint System
- When a player makes an incorrect guess, they lose a life AND get a hint
- Hints reveal one additional letter of the target word
- If all letters are revealed through hints, the word is automatically completed
- Words start with their first letter visible (except first/last words)

### Word Chain Display
- First word: Always fully visible
- Middle words: Show revealed letters + underscores for hidden letters
- Last word: Always fully visible
- Current target word: Shows all revealed letters from hints
- Future words: Show only first letter + underscores

### Status Indicators
- ✓ (green checkmark): Word completed correctly
- ✗ (red X): Word not completed
- No indicator: Word in progress or not started

## User Interface Architecture

### GameView.swift Structure

#### Header Section
```
Links/daily                    ♥ 5
─────────────────────────────────
```
- **Title**: "Links/daily" with monospace font
- **Triple-tap Feature**: Triple-tapping the title triggers a data wipe with visual feedback
- **Lives Counter**: Red heart symbol with remaining lives count
- **Divider**: Separates header from game content

#### Main Content Area
- **First Line**: Animated intro text or error message
- **Word Chain**: Vertical list of words showing current game state
- **Host Messages**: Animated prompts and feedback from the game

#### Input Area (Bottom)
- **Text Field**: Monospace input for word guesses
- **Submit Button**: Arrow-up circle button (enabled only when guess is valid)
- **Auto-focus**: Text field gains focus when game becomes active

### Visual Design
- **Color Scheme**: Always dark mode with black background
- **Text Color**: Terminal green (#00FF00 style)
- **Typography**: Monospace fonts throughout for authentic terminal feel
- **Animations**: Typewriter effects and smooth transitions

## GameViewModel.swift - Core Logic

### State Management

#### Published Properties
- `currentGuess`: User's current input
- `currentLives`: Remaining lives (0-5)
- `wordChain`: Array of words showing current reveal state
- `isGameActive`: Whether player can make guesses
- `isAnimating`: Prevents input during animations
- `isContentReady`: Whether game content has loaded
- `showFirstLine`: Controls intro text visibility
- `hasServerError`: Whether to show error state instead of game

#### Game Data
- `fullWords`: Complete word chain from puzzle service
- `currentWordIndex`: Index of word player is currently guessing
- `revealedLetters`: Dictionary tracking revealed letters per word
- `currentGameCompletion`: SwiftData record for persistence

### Animation System

#### Typewriter Effects
The game features sophisticated typewriter animations for authentic terminal feel:

1. **First Line Animation**: Intro text types out character by character
2. **Word Chain Animation**: All words reveal simultaneously, character by character
3. **Message Animation**: Host messages wipe old text then type new text
4. **Two-speed System**: Fast animations for hints, normal for major transitions

#### Animation Sequence on Game Start
1. Show first line: "Can you solve today's links? [date]"
2. Animate word chain appearing simultaneously
3. Show host message asking for first guess
4. Activate game for user input

### Puzzle Loading & Persistence

#### Initialization Process
1. Wait for SwiftData to be ready (polling with timer)
2. Check for cached puzzle or fetch from server
3. Handle server errors with fallback messaging
4. Load or create game completion record
5. Restore previous game state if applicable

#### Game States
- **New Game**: Fresh start with initial word chain setup
- **Resumed Game**: Restore progress from previous session
- **Completed Game**: Show final state (victory/defeat)

#### Error Handling
- Server connectivity issues show snarky error messages
- Fallback puzzle system for offline play
- Graceful handling of malformed puzzle data

### Word Validation System

Uses iOS's built-in spell checker (`UITextChecker`) with these rules:
- Minimum 2 characters (configurable)
- Only alphabetic characters allowed
- English dictionary validation
- Case-insensitive matching

### Game Flow Logic

#### Guess Processing
1. **Input Validation**: Check for empty/whitespace-only input
2. **Animation Check**: Block input during animations
3. **Word Validation**: Use spell checker for dictionary validation
4. **Guess Evaluation**: Compare against target word (case-insensitive)

#### Correct Guess Handling
1. Reveal full word in chain
2. Advance to next word index
3. Update completion tracking
4. Show next prompt or victory message
5. Check for game completion

#### Incorrect Guess Handling
1. Decrease lives counter
2. Reveal next letter as hint
3. Update word display with new hint
4. Check if word is now fully revealed through hints
5. Auto-advance if word is complete, otherwise show hint message
6. Check for game over condition

#### Invalid Word Handling
- Show snarky message about invalid word
- No life penalty
- No hint given
- Allow immediate retry

### Host Personality System

The game features randomized personality messages to avoid repetition:

#### Message Categories
- **Next Word Messages**: "🤔 What word comes after", "🧐 Next up, what follows", etc.
- **Incorrect Messages**: "🙄 Nope! Here's a hint:", "😬 Wrong! Take this hint:", etc.
- **Game Over Messages**: "💀 Game Over! Maybe tomorrow?", "😵 Yikes! Better luck next time.", etc.
- **Victory Messages**: "🎉 Holy cow! You actually did it!", "🤯 Wow! Didn't see that coming!", etc.
- **Invalid Word Messages**: "🤨 That's not a real word! Try again.", etc.

#### Anti-Repetition System
- Tracks last used message for each category
- Excludes recent messages from random selection
- Ensures variety in game feedback

### Game Completion & Persistence

#### SwiftData Integration
- **GameCompletion**: Records for each daily puzzle
- **Progress Tracking**: Words completed, lives used, current state
- **Revealed Letters**: Persists hint progress
- **Win/Loss State**: Final game outcome

#### Daily Puzzle System
- **Date-based Games**: Each puzzle tied to specific date
- **Midnight Reset**: Countdown timer to next puzzle
- **Previous Game Access**: Can replay yesterday's incomplete game

#### Completion States
- **Victory**: All words guessed before running out of lives
- **Defeat**: Lives exhausted before completion
- **Persistence**: State saved between app sessions

### Debug & Development Features

#### Data Wipe Function
- Triple-tap on title triggers complete reset
- Wipes all SwiftData records
- Clears cached puzzles
- Reinitializes entire game state
- Includes haptic feedback and visual indication

#### Comprehensive State Reset
- Resets all published properties to initial values
- Clears all timers and animations
- Resets game progress tracking
- Clears message history to prevent stale state

### Timer Management

The game uses multiple coordinated timers:

#### System Timers
- **Readiness Timer**: Polls for SwiftData availability
- **Typewriter Timer**: Handles character-by-character animations
- **Game Over Timer**: Delays countdown start after game completion
- **Countdown Timer**: Updates time until next puzzle

#### Timer Lifecycle
- Proper invalidation on state changes
- Memory leak prevention with weak self references
- Cleanup in deinit and reset functions

### Error Recovery & Edge Cases

#### Network Issues
- Graceful fallback to cached puzzles
- Server error messages with personality
- Offline play capability

#### Animation Interruption
- Prevents input during critical animations
- Proper cleanup when animations are interrupted
- State consistency maintenance

#### Data Corruption
- Validation of puzzle word counts
- Graceful handling of malformed completion records
- Recovery through game state reset

## Technical Implementation Details

### State Synchronization
- Reactive UI updates through `@Published` properties
- Combine framework for puzzle service subscriptions
- Proper main actor usage for UI updates

### Performance Considerations
- Efficient string manipulation for typewriter effects
- Minimal UI updates during animations
- Proper timer management to prevent memory leaks

### Accessibility
- VoiceOver support through standard SwiftUI components
- High contrast terminal color scheme
- Clear focus management for input field

### Memory Management
- Weak references in timer closures
- Proper cleanup of resources in deinit
- Efficient string operations for large word chains

## Game Flow Summary

1. **App Launch**: Initialize SwiftData, load daily puzzle
2. **Content Animation**: Show intro, animate word chain appearance
3. **Game Activation**: Enable input, show first prompt
4. **Guess Loop**: Process guesses, give hints, advance words
5. **Game End**: Show victory/defeat, start countdown to next puzzle
6. **Persistence**: Save progress throughout, restore on next launch

This architecture creates a polished, engaging word puzzle experience with authentic terminal aesthetics and robust state management.