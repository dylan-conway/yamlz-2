# YAML Parser Implementation in Zig

## Quick Status
- **Current**: 371/402 tests passing (92.3%)
- **Target**: 402/402 (100%)
- **Gap**: 31 tests to fix
- **Run tests**: `./zig/zig build test-yaml -- zig`

## Project Overview

A YAML 1.2 parser in Zig using recursive descent parsing. The goal is 100% passing tests from the official YAML test suite.

## Recent Progress

Successfully fixed 14 tests total:
- ✅ **3HFZ**: Reject content after document end marker
- ✅ **6S55**: Invalid content validation  
- ✅ **7A4E**: Allow tabs in double-quoted strings
- ✅ **7LBH**: Multiline key rejection
- ✅ **7MNF**: Missing colon validation
- ✅ **9CWY**: Invalid content at wrong indentation
- ✅ **9HCY**: Directive after content validation
- ✅ **9MMA**: Directive without document
- ✅ **C2SP**: Multiline flow sequence as key
- ✅ **D49Q**: Multiline single quoted key
- ✅ **DK4H**: Implicit key with newline
- ✅ **DMG6**: Wrong indentation validation
- ✅ **+2 tests**: Fixed by improved anchor handling for mapping keys

## Remaining Work (31 Failing Tests)

### 🎯 Priority: "Too Restrictive" Tests (8 tests)
Valid YAML being incorrectly rejected:
- **2SXE** (anchors with colons), **E76Z** (anchor on implicit key), **FH7J**, **J3BT**, **UT92**, **VJP3**, **ZF4X**

### ⚠️ "Too Permissive" Tests (23 tests)
Invalid YAML being incorrectly accepted:
- **4HVU**, **4JVG** (anchor on key), **62EZ**, **9C9N** (flow sequence indentation)
- **BD7L** (multi-document validation), **BS4K**, **EB22**, **G9HC**, **H7TQ**
- **KS4U**, **LHL4**, **MUS6**, **N4JP**, **P2EQ**
- **QLJ7**, **RXY3**, **SF5V**, **SY6V**, **TD5N**
- **U44R**, **U99R**, **UV7Q**, **ZXT5**

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
- **Too restrictive issues** (8 tests) = loosening validation to accept valid YAML
- **Too permissive issues** (35 tests) = adding validation to reject invalid YAML - **PRIMARY FOCUS**
- Study TypeScript parser (99.3% baseline) for correct behavior
- Use git commits frequently to track progress