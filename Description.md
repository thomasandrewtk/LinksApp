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
- Players start with 10 lives (♥ counter in top-right)
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
Links/daily                    ♥ 10
─────────────────────────────────
```
- **Title**: "Links/daily" with monospace font
- **Triple-tap Feature**: Triple-tapping the title triggers a data wipe with visual feedback
- **Lives Counter**: Red heart symbol with remaining lives count
- **Divider**: Separates header from game content

#### Main Content Area (Terminal Display)
- **30-Line Terminal**: Fixed-position terminal with consistent line spacing
- **Line 1**: Animated intro text ("Can you solve today's links? [date]")
- **Lines 3-14**: Word chain display with typewriter animations
- **Line 18**: Host messages and game prompts
- **Line 20**: Streak/score information after completion
- **Line 22**: Navigation links (yesterday's game, etc.)

#### Input Area (Bottom)
- **Text Field**: Monospace input for word guesses
- **Submit Button**: Arrow-up circle button (enabled only when guess is valid)
- **Auto-focus**: Text field gains focus when game becomes active

### Visual Design
- **Color Scheme**: Always dark mode with black background
- **Text Color**: Terminal green (#00FF00 style)
- **Typography**: Monospace fonts throughout for authentic terminal feel
- **Animations**: Typewriter effects and smooth transitions

## Component-Based Architecture

The game uses a modern component-based architecture that replaced the monolithic GameViewModel with specialized, focused components.

### Core Components

#### TodayGameContent.swift - Game Logic Controller
**Role**: Manages game state, puzzle loading, and business logic
**Published Properties**:
- `isActive`: Whether player can make guesses
- `currentLives`: Remaining lives (0-10)
- `hasServerError`: Whether to show error state instead of game

**Private State**:
- `fullWords`: Complete word chain from puzzle service
- `currentWordIndex`: Index of word player is currently guessing
- `revealedLetters`: Dictionary tracking revealed letters per word
- `currentGameCompletion`: SwiftData record for persistence

#### TerminalViewModel.swift - Display Controller
**Role**: Manages the 30-line terminal display and animation queue system
**Configuration**:
- `totalLines`: 30 fixed terminal lines
- `visibleLines`: 25 lines reserved for content display

**Published Properties**:
- `lines`: Array of TerminalLine objects (one per line)
- `isProcessingQueue`: Whether animations are currently running

**Animation System**:
- Queue-based command processing (writeLine, replaceLine, parallel, completion)
- Robust error handling and state management
- Thread-safe animation sequencing

#### TerminalLine.swift - Individual Line Management
**Role**: Handles typewriter animation and content for a single terminal line
**Published Properties**:
- `content`: Full line content
- `displayedContent`: Currently visible content during animation
- `isAnimating`: Whether this line is currently animating

**Animation Features**:
- Character-by-character typewriter effects
- Wipe-and-replace animations for content updates
- Completion callback system for chaining animations

### SwiftUI View Architecture

#### TerminalView.swift - Display Components
**TerminalView**: Full terminal view with line numbers (for debugging)
**TerminalViewSimple**: Clean terminal display used in game (no line numbers)
**TerminalLineView**: Individual line component with proper SwiftUI binding

**Critical SwiftUI Fix**:
```swift
// BEFORE (broken): Direct property access in ForEach
ForEach(viewModel.lines, id: \.id) { line in
    Text(line.displayedContent)  // SwiftUI doesn't observe this
}

// AFTER (fixed): Dedicated view component  
ForEach(viewModel.lines, id: \.id) { line in
    TerminalLineView(line: line)  // @ObservedObject ensures updates
}
```

### Terminal Display System

#### Line Layout
The 30-line terminal uses fixed positioning for consistent display:
- **Line 1**: Intro message ("Can you solve today's links? [date]")
- **Lines 3-14**: Word chain display (12 words maximum)
- **Line 18**: Game prompts and host messages
- **Line 20**: Streak/score information
- **Line 22**: Navigation links (yesterday's game, etc.)

#### Animation Queue Architecture
**Command Types**:
- `writeLine`: Animate text appearing on a specific line
- `replaceLine`: Wipe existing text and type new content
- `parallel`: Execute multiple animations simultaneously
- `completion`: Chain callback functions for sequence control
- `delay`: Add pauses between animations

**Animation Sequence on Game Start**:
1. **Queue Commands**: First line animation + completion handler
2. **Execute First Line**: "Can you solve today's links? [date]"
3. **Completion Trigger**: Automatically starts word chain animation
4. **Parallel Word Display**: All 12 words animate simultaneously
5. **Final Prompt**: Show game prompt and activate input

#### SwiftUI Integration
**Critical Fix Applied**: `TerminalLineView` component with `@ObservedObject` binding ensures SwiftUI properly observes changes to individual `TerminalLine` objects. Previous architecture failed because `ForEach` didn't automatically observe nested `ObservableObject` changes.

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

### Component Coordination

#### Inter-Component Communication
- **GameView**: Orchestrates `TodayGameContent` and `TerminalViewModel`
- **Configuration**: `TodayGameContent.configure(with: terminalViewModel)` establishes connection
- **Animation Flow**: `TodayGameContent` queues commands to `TerminalViewModel`
- **State Sync**: Published properties trigger UI updates through SwiftUI's reactive system

#### Timer Management
**TodayGameContent Timers**:
- **Readiness Timer**: Polls for SwiftData availability
- **Game Over Timer**: Delays countdown start after game completion
- **Countdown Timer**: Updates time until next puzzle

**TerminalLine Timers**:
- **Animation Timers**: Individual timers per line for typewriter effects
- **Automatic Cleanup**: Proper invalidation and memory management
- **Completion Callbacks**: Trigger next animation in queue

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

### SwiftUI Binding Architecture
**Key Fix**: `TerminalLineView` component ensures proper observation of nested `ObservableObject` instances
```swift
struct TerminalLineView: View {
    @ObservedObject var line: TerminalLine  // Critical for UI updates
    // ... styling properties
}
```
**Problem Solved**: SwiftUI's `ForEach` doesn't automatically observe `@Published` properties of objects passed to closures. The dedicated view component with `@ObservedObject` binding resolves this.

### State Synchronization
- **Component Isolation**: Each component manages its own `@Published` properties
- **Reactive Updates**: SwiftUI automatically updates when `TerminalLine.displayedContent` changes
- **Combine Framework**: Puzzle service subscriptions for midnight refresh
- **Main Actor Usage**: All UI updates properly dispatched to main thread

### Performance Considerations
- **30-Line Limit**: Fixed terminal size prevents unbounded UI complexity
- **Individual Timers**: Each line manages its own animation independently
- **Efficient Updates**: Only animating lines trigger UI refreshes
- **Queue Management**: Animation commands processed sequentially for consistency

### Animation Robustness
**Critical Bug Fixed**: Completion callback preservation in `TerminalLine.finishAnimation()`
```swift
// BEFORE (broken): cancelAnimation() cleared callback
// AFTER (fixed): Save callback before cleanup
let completion = animationCompletion
cancelAnimation()
completion?()
```

### Memory Management
- **Weak References**: All timer closures use `[weak self]` pattern
- **Automatic Cleanup**: `deinit` methods properly invalidate timers
- **Component Lifecycle**: Each component manages its own resources independently

## Game Flow Summary

1. **App Launch**: Initialize SwiftData, configure component connections
2. **Component Setup**: `GameView` creates `TerminalViewModel` and `TodayGameContent`
3. **Content Loading**: `TodayGameContent` loads puzzle and configures terminal
4. **Animation Sequence**: Queue-based system animates intro → word chain → prompt
5. **Game Activation**: Terminal animations complete, input field becomes active
6. **Guess Processing**: `TodayGameContent` handles logic, `TerminalViewModel` shows results
7. **Game End**: Show victory/defeat through terminal, start countdown to next puzzle
8. **Persistence**: `GameCompletionService` saves progress throughout session

This component-based architecture creates a polished, engaging word puzzle experience with authentic terminal aesthetics, robust animation systems, and maintainable code separation.