# YAML Parser Implementation in Zig

## Quick Status

- **Current**: 391/402 tests passing (97.3%)
- **Target**: 402/402 (100%)
- **Gap**: 11 tests to fix
- **Run tests**: `./zig/zig build test-yaml -- zig`

## Project Overview

A YAML 1.2 parser in Zig using recursive descent parsing. The goal is 100% passing tests from the official YAML test suite.

## Recent Progress

Successfully fixed 40+ tests in recent commits:

- ✅ **3HFZ**: Reject content after document end marker
- ✅ **7A4E**: Allow tabs in double-quoted strings
- ✅ **7LBH**: Multiline key rejection
- ✅ **9HCY**: Directive after content validation
- ✅ **9MMA**: Directive without document
- ✅ **C2SP**: Multiline flow sequence as key
- ✅ **D49Q**: Multiline single quoted key
- ✅ **DK4H**: Implicit key with newline
- ✅ **DMG6**: Wrong indentation validation
- ✅ **ZXT5**: Fixed multiline key detection in flow sequences
- ✅ **ZF4X**: Fixed multiline flow mappings
- ✅ **VJP3**: Fixed flow collections spanning multiple lines
- ✅ **UT92**: Fixed multiline plain scalars in flow key context
- ✅ **U99R**: Fixed comma validation after tags
- ✅ **SY6V**: Fixed anchor validation before block sequence entries
- ✅ **SF5V**: Fixed duplicate YAML directive detection
- ✅ **RXY3**: Fixed document marker detection in quoted strings
- ✅ **P2EQ**: Fixed invalid content after flow collections
- ✅ **MUS6**: Fixed directive variant validation
- ✅ **LHL4**: Fixed tag validation with flow indicators
- ✅ **H7TQ**: Fixed extra words on YAML directive
- ✅ **G9HC**: Fixed anchor validation at zero indentation
- ✅ **FH7J**: Fixed tags on empty scalars
- ✅ **9C9N**: Fixed flow sequence indentation validation
- ✅ **62EZ**: Fixed invalid block mapping key on same line
- ✅ **EB22**: Fixed directive after content
- ✅ **N4JP**: Fixed bad indentation in mappings
- ✅ **2SXE**: Fixed anchors with colons
- ✅ **E76Z**: Fixed anchor on implicit key
- ✅ **BEC7**: Accept future YAML versions (1.3+) as per spec
- ✅ **And more...**

## Remaining Work (11 Failing Tests)

### Current Failing Tests:

- **UV7Q**: Tab/indentation issues
- **4JVG**: Scalar value with two anchors
- **BD7L**: Invalid mapping after sequence
- **TD5N**: Invalid content after sequence
- **7MNF**: Missing colon validation
- **KS4U**: Invalid content after document end
- **QLJ7**: Tag shorthand validation
- **9CWY**: Invalid content at wrong indentation
- **4HVU**: Inconsistent sequence indentation
- **6S55**: Invalid content validation
- **BS4K**: Comment between plain scalar lines

### Recently Fixed (since last update):

- **XLQ9**: Invalid scalar after document marker
- **J3BT**: Tab handling after colons
- **U44R**: Bad indentation in mappings
- **Q9WF**: Directive with non-printable character

## Key Resources

- **YAML Spec (Compressed)**: `./yaml-spec-compressed.md` - Primary reference for production rules
- **Reference Implementations**: Study these to understand edge cases:
  - TypeScript: `./yaml-ts/` (94.8% baseline)
  - Rust: `./yaml-rs/` (83.8% baseline)
- **Test Suite**: `./yaml-test-suite/src/`
- **Worktrees**: `worktrees/` - Individual worktrees for specific tests being debugged

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

Create worktrees as needed for debugging specific tests: `git worktree add worktrees/TEST_NAME`

### Fix Strategy

1. **Study reference implementations first** (`yaml-ts/` and `yaml-rs/`)
2. **Make targeted fixes** - avoid broad changes that affect many tests
3. **Test incrementally** - run full suite after each change
4. **Revert if broken** - if a fix doesn't work, revert immediately

### Key Principles

- Most remaining tests are "too permissive" issues - adding validation to reject invalid YAML
- Study TypeScript parser (94.8% baseline) for correct behavior
- Use git commits frequently to track progress
- Make targeted fixes to avoid regressions
