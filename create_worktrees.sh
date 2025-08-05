#!/bin/bash

# Create a worktrees directory if it doesn't exist
mkdir -p worktrees

# Read failing tests and create worktrees
while read test_name; do
    # Skip empty lines
    if [ -z "$test_name" ]; then
        continue
    fi
    
    # Replace slash with dash for branch name (for subtests like 2G84/00)
    branch_name="fix-${test_name//\//-}"
    worktree_path="worktrees/$test_name"
    
    echo "Creating worktree for test $test_name..."
    
    # Create branch if it doesn't exist
    if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
        git branch "$branch_name"
    fi
    
    # Create worktree
    if [ ! -d "$worktree_path" ]; then
        git worktree add "$worktree_path" "$branch_name"
        echo "  Created worktree at $worktree_path on branch $branch_name"
        
        # Create symlinks to required directories
        cd "$worktree_path"
        ln -sf ../../yaml-test-suite yaml-test-suite
        ln -sf ../../yaml-rs yaml-rs  
        ln -sf ../../yaml-ts yaml-ts
        ln -sf ../../zig zig
        ln -sf ../../yaml-rs-test yaml-rs-test
        ln -sf ../../yaml-spec-compressed.md yaml-spec-compressed.md
        ln -sf ../../yaml-spec.md yaml-spec.md
        cd - > /dev/null
        echo "  Created symlinks to shared resources"
    else
        echo "  Worktree already exists at $worktree_path"
    fi
done < failing_tests.txt

echo ""
echo "Created worktrees for all failing tests in worktrees/ directory"
echo "To work on a test, cd to worktrees/<test_name>"
echo ""
echo "Summary:"
git worktree list | head -20
echo "..."
echo "Total worktrees: $(git worktree list | wc -l)"