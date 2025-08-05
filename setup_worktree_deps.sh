#!/bin/bash

# Get the absolute path of the main repository
MAIN_REPO=$(pwd)

# Directories to link
DEPS=("yaml-test-suite" "yaml-rs" "yaml-ts" "zig")

echo "Setting up dependencies for all worktrees..."

# Process each worktree
for worktree in worktrees/*/; do
    if [ -d "$worktree" ]; then
        echo "Processing $worktree..."
        
        # Create symlinks for each dependency
        for dep in "${DEPS[@]}"; do
            if [ -e "$MAIN_REPO/$dep" ]; then
                # Remove existing symlink or directory if it exists
                if [ -e "$worktree/$dep" ] || [ -L "$worktree/$dep" ]; then
                    rm -rf "$worktree/$dep"
                fi
                
                # Create symlink
                ln -s "$MAIN_REPO/$dep" "$worktree/$dep"
                echo "  Linked $dep"
            else
                echo "  Warning: $dep not found in main repository"
            fi
        done
        
        # Also link the yaml spec files
        for spec_file in "yaml-spec.md" "yaml-spec-compressed.md"; do
            if [ -f "$MAIN_REPO/$spec_file" ]; then
                if [ -e "$worktree/$spec_file" ] || [ -L "$worktree/$spec_file" ]; then
                    rm -f "$worktree/$spec_file"
                fi
                ln -s "$MAIN_REPO/$spec_file" "$worktree/$spec_file"
                echo "  Linked $spec_file"
            fi
        done
    fi
done

echo ""
echo "Dependencies setup complete!"
echo ""
echo "Verifying first worktree (UV7Q):"
ls -la worktrees/UV7Q/ | grep -E "yaml-test-suite|yaml-rs|yaml-ts|zig|yaml-spec"