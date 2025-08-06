# Worktree Status

## Current State
- **53 worktrees created** for failing tests only
- **348/402 tests passing** (86.6%)
- **54 tests failing** (53 unique test names)

## Failing Tests with Worktrees

### "Too Restrictive" (Valid YAML rejected) - 10 tests
- 2SXE, E76Z, FH7J, J3BT, M6YH, UT92, UV7Q, VJP3, ZF4X, 6M2F

### "Too Permissive" (Invalid YAML accepted) - 43 tests
- 3HFZ, 4HVU, 4JVG, 5LLU, 62EZ, 6S55, 7LBH, 7MNF, 9C9N, 9CWY
- 9HCY, 9MMA, B63P, BD7L, BS4K, C2SP, CXX2, D49Q, DK4H, DK95
- DMG6, EB22, G9HC, H7TQ, JKF3, JY7Z, KS4U, LHL4, MUS6, N4JP
- P2EQ, Q4CL, QLJ7, RXY3, S98Z, SF5V, SY6V, TD5N, U44R, U99R
- W9L4, ZCZ6, ZXT5

## Commands
- Run all tests: `./zig/zig build test-yaml -- zig`
- Check failing tests: `./get_failing_tests.sh`
- List worktrees: `ls worktrees/`

## Each Worktree Contains
- Symlinks to: yaml-rs, yaml-ts, yaml-test-suite, zig, yaml-rs-test, yaml-spec-compressed.md
- Full copy of source code (src/)
- Independent git branch (fix-TESTNAME)
