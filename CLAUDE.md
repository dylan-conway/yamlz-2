# YAML Parser Implementation in Zig

## Quick Status
- **Current**: 354/402 tests passing (88.1%)
- **Target**: 394/402 (98%)
- **Gap**: 40 tests to fix
- **Run tests**: `./zig/zig build test-yaml -- zig`

## Project Overview

A YAML 1.2 parser in Zig using recursive descent parsing. The goal is 98%+ passing tests from the official YAML test suite.

## Remaining Work (48 Failing Tests)

### 🎯 Priority: "Too Restrictive" Tests (39 tests)
Valid YAML being incorrectly rejected - **BIGGEST OPPORTUNITY**:
- **2EBW, 3R3P, 5BVJ, 6ZKB, BU8L, CN3R, D88J, DC7X**
- **EHF6, FRK4, H2RW, H3Z8, HS5T, J3BT, J9HZ, JEF9** 
- **JR7V, JS2J, K527, KK5P, L24T, M9B4, NAT4, NB6Z**
- **NHX8, PRH3, PUW8, QF4Y, R4YG, T26H, T5N4, TL85**
- **U3C3, UDM2, UDR7, W42U, + 3 more**

### ⚠️ "Too Permissive" Tests (9 tests)
Invalid YAML being incorrectly accepted:
- **DK4H, GDY7, H7TQ, LHL4, Q4CL, SU74, T833, W9L4, ZCZ6**

## Key Resources

- **YAML Spec (Compressed)**: `./yaml-spec-compressed.md` - Primary reference for production rules
- **Reference Implementations**: Study these to understand edge cases:
  - TypeScript: `./yaml-ts/` (94.8% baseline)
  - Rust: `./yaml-rs/` (83.8% baseline)
- **Test Suite**: `./yaml-test-suite/src/`
- **Worktrees**: `worktrees/` - Individual worktrees for each failing test

## Testing

```bash
# Run full test suite
./zig/zig build test-yaml -- zig

# Verbose mode to see specific failures
./zig/zig build test-yaml -- zig --verbose

# Check specific test
./zig/zig build test-yaml -- zig --verbose 2>&1 | grep TEST_NAME

# Compare with reference implementations
./zig/zig build test-yaml -- typescript  # 94.8% baseline
./zig/zig build test-yaml -- rust        # 83.8% baseline
```

## Strategy for Agents

### Working with Worktrees
Each failing test has its own worktree in `worktrees/TEST_NAME/` with symlinks to all necessary resources.

### Fix Strategy
1. **Study reference implementations first** (`yaml-ts/` and `yaml-rs/`)
2. **Make targeted fixes** - avoid broad changes that affect many tests
3. **Test incrementally** - run full suite after each change
4. **Revert if broken** - if a fix doesn't work, revert immediately

### Key Principles
- **Too restrictive issues** (39 tests) = loosening validation = easier fixes
- **Too permissive issues** (9 tests) = adding validation = harder fixes
- Study TypeScript parser (94.8% baseline) for correct behavior
- Use git commits frequently to track progress