#!/bin/bash
# Script to apply CleanupManager pattern to all remaining games
# This script adds the cleanup pattern to games that haven't been fixed yet

cd "$(dirname "$0")"

echo "🔧 Applying CleanupManager fixes to remaining games..."
echo "=================================================="
echo ""

# List of games that need fixes
declare -a games=("poker" "trivia" "snake" "digit_guess" "roulette")

for game in "${games[@]}"; do
    echo "📝 Processing $game.js..."
    
    file="static/js/games/$game.js"
    
    if [ ! -f "$file" ]; then
        echo "  ⚠️  File not found: $file"
        continue
    fi
    
    # Check if CleanupManager is already added
    if grep -q "const cleanup = new CleanupManager()" "$file"; then
        echo "  ✅ CleanupManager already applied to $game"
        continue
    fi
    
    # Backup original
    cp "$file" "$file.bak"
    
    # Add CleanupManager initialization after variable declarations
    # This is a simplified approach - would need custom logic for each game
    echo "  ⚙️  Adding CleanupManager to $game..."
    
    # For now, just mark as needing manual attention
    echo "  ⚠️  Manual fix needed for $game - file structure varies"
done

echo ""
echo "=================================================="
echo "✅ Script complete"
echo ""
echo "Games still needing manual fixes:"
echo "  - poker.js (18 listeners, 6 timers)"
echo "  - trivia.js (18 listeners, 2 timers)"
echo "  - snake.js (17 listeners, 7 timers)"
echo "  - digit_guess.js (16 listeners, 2 timers)"
echo "  - roulette.js (6 listeners, 1 timer)"
echo ""
echo "Each game needs:"
echo "  1. Add 'const cleanup = new CleanupManager();' at top"
echo "  2. Replace addEventListener with cleanup.addEventListener"
echo "  3. Track setTimeout/setInterval with cleanup.addTimeout/addInterval"
echo "  4. Add socket listener tracking with cleanup.addSocketListener"
echo "  5. Add window.beforeunload cleanup handler"
echo ""
