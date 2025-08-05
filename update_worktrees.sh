#!/bin/bash

# Get the current directory
BASE_DIR=$(pwd)

# First, make sure main is up to date
echo "Ensuring main branch is current..."
git checkout main
git pull origin main 2>/dev/null || true

# Get list of all worktree branches
echo "Updating all worktree branches with latest main..."
echo ""

# Read failing tests and update each worktree
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
        echo "Updating worktree for test $test..."
        
        # Go to the worktree
        cd "$worktree_path"
        
        # Merge main into this branch
        git merge main --no-edit -m "Merge latest main into $branch_name" || {
            echo "  ⚠️  Merge conflict in $test - manual resolution needed"
            git merge --abort 2>/dev/null
        }
        
        # Check the current commit
        current_commit=$(git rev-parse --short HEAD)
        echo "  ✓ Branch $branch_name now at commit $current_commit"
        
        cd "$BASE_DIR"
    else
        echo "Worktree for $test doesn't exist, skipping..."
    fi
done < failing_tests.txt

echo ""
echo "All worktrees updated!"
echo ""
echo "Summary of worktree status:"
git worktree list | head -10
echo "..."
echo "Total worktrees: $(git worktree list | wc -l)"