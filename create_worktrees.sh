#\!/bin/bash
FAILING_TESTS=(2SXE 3HFZ 4HVU 4JVG 5LLU 62EZ 6M2F 6S55 7LBH 7MNF 9C9N 9CWY 9HCY 9MMA B63P BD7L BS4K C2SP CXX2 D49Q DK4H DK95 DMG6 E76Z EB22 FH7J G9HC H7TQ J3BT JKF3 JY7Z KS4U LHL4 M6YH MUS6 N4JP P2EQ Q4CL QLJ7 RXY3 S98Z SF5V SY6V TD5N U44R U99R UT92 UV7Q VJP3 W9L4 ZCZ6 ZF4X ZXT5)

mkdir -p worktrees

for test in "${FAILING_TESTS[@]}"; do
    echo "Creating worktree for $test..."
    git worktree add "worktrees/$test" -b "fix-$test" 2>/dev/null || git worktree add "worktrees/$test" "fix-$test" 2>/dev/null || true
    
    # Create symlinks
    cd "worktrees/$test"
    ln -sf ../../yaml-rs yaml-rs 2>/dev/null
    ln -sf ../../yaml-ts yaml-ts 2>/dev/null
    ln -sf ../../yaml-test-suite yaml-test-suite 2>/dev/null
    ln -sf ../../zig zig 2>/dev/null
    ln -sf ../../yaml-rs-test yaml-rs-test 2>/dev/null
    ln -sf ../../yaml-spec-compressed.md yaml-spec-compressed.md 2>/dev/null
    cd ../..
done

echo "Created ${#FAILING_TESTS[@]} worktrees"
