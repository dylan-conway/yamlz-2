#!/bin/bash

# Get the current directory
BASE_DIR=$(pwd)

# First, make sure main is up to date
echo "Ensuring main branch is current..."
git checkout main
MAIN_COMMIT=$(git rev-parse HEAD)
echo "Main branch is at commit: $MAIN_COMMIT"
echo ""

# Read failing tests and reset each worktree to main
echo "Resetting all worktree branches to main..."
echo ""

while IFS= read -r test; do
    # Skip empty lines
    if [ -z "$test" ]; then
        continue
    fi
    
    # Replace / with - for directory names (for tests like DK95/01)
    dir_name=$(echo "$test" | sed 's/\//-/')
    branch_name="fix-$dir_name"
    worktree_path="$BASE_DIR/worktrees/$test"
    
    if [ -d "$worktree_path" ]; then
        echo "Resetting worktree for test $test..."
        
        # Go to the worktree
        cd "$worktree_path"
        
        # Reset hard to main
        git reset --hard main
        
        # Check the current commit
        current_commit=$(git rev-parse --short HEAD)
        echo "  ✓ Branch $branch_name reset to main at commit $current_commit"
        
        cd "$BASE_DIR"
    else
        echo "Worktree for $test doesn't exist, skipping..."
    fi
done < failing_tests.txt

echo ""
echo "All worktrees reset to main!"
echo ""
echo "Summary of worktree status:"
git worktree list | head -10
echo "..."
echo "Total worktrees: $(git worktree list | wc -l)"