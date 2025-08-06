# YAML Parser Implementation in Zig

## Quick Status (December 2024)
- **Current**: 348/402 tests passing (86.6%)
- **Target**: 394/402 (98%)
- **Failing**: 45 tests (36 too restrictive, 9 too permissive)
- **Worktrees**: Created for all 45 failing tests in `worktrees/`
- **Run tests**: `./zig/zig build test-yaml -- zig`

## Project Overview

You are implementing a YAML 1.2 parser in Zig using a recursive descent parsing approach. The goal is to achieve 98%+ passing tests from the official YAML test suite.

## Current Implementation Status

**Test Pass Rate**: 348/402 (86.6%)
- Target: 394/402 (98%)
- Gap: 46 tests
- Failing: 54 tests total (45 unique test failures)

### Features Implemented
1. **Core Parsing**:
   - Recursive descent parser with arena allocator
   - Plain scalars with special value recognition
   - Single and double quoted strings with escape sequences
   - Block and flow sequences
   - Block and flow mappings
   - Multi-line scalars (literal `|` and folded `>`)
   - Comments handling
   - Anchors (`&anchor`) and aliases (`*anchor`)
   - Tags (`!tag`, `!!tag`)

2. **Complex Features**:
   - Empty keys and values in mappings
   - **Explicit key indicators (`?`)** - ✅ **COMPLETED**
   - Mappings inside sequences (compact mappings in block sequences)
   - Special values (null, true/false, .inf, .nan)
   - YAML 1.1 boolean compatibility (yes/no, on/off, y/n)
   - **Multi-document streams** - ✅ **COMPLETED** with `---` and `...` markers

3. **Recent Major Fixes**:
   ✅ **SU74**: Reject anchors on alias nodes - aliases cannot have properties per YAML spec
   ✅ **Explicit Key Syntax (X8DW, ZWK4)**: Complete support for `?` indicator with comment separation and null values
   ✅ **Flow Collection Comments (7TMG)**: Fixed overly restrictive comment validation in flow contexts
   ✅ **Multi-Document Support**: Complete streams with `---`/`...` separators (M7A3, U9NS, 6XDY, 35KP)
   ✅ **Block Sequence Mappings (JQ4R)**: Fixed compact mappings inside block sequence entries  
   ✅ **Tab Validation (7A4E)**: Corrected tab handling in double-quoted string continuations
   ✅ **6CA3**: Allow tabs at document level in flow contexts
   ✅ **5U3A**: Reject sequences on same line as mapping key
   ✅ **5TRB**: Reject document markers inside double-quoted strings
   ✅ **3GZX**: Allow anchor redefinition per YAML 1.2 spec
   ✅ **236B**: Validate invalid content after mapping values
   - Flow sequence empty entry validation (CTN5)
   - Block scalar indicator validation (S4GJ, D83L)
   - Tab validation in block sequences (Y79Y test suite - all passing)
   - Trailing comma support in flow sequences
   - Basic document directives (%YAML, %TAG)
   - Block sequence/mapping indentation validation
   - Improved plain scalar parsing in flow context (FRK4 now passing)
   - Fixed colon handling in plain scalars for flow context
   - Fixed flow context block mapping detection (58MP and +20 tests!)
   - Added comment whitespace validation (9JBA and related)
   - Support for YAML 1.1 in directives (MUS6/02-04)

4. **Architecture**:
   - Clean separation: lexer.zig, ast.zig, parser.zig
   - Arena allocator for memory management
   - Proper line/column tracking
   - Test runner comparing against reference implementations

### Remaining Work to Reach 98%
**Gap Analysis (Current State)**: 45 failing tests
- **36 tests "too restrictive"** (80% of failures) - Valid YAML being incorrectly rejected
- **9 tests "too permissive"** (20% of failures) - Invalid YAML being incorrectly accepted

**🎯 PRIORITY: Fix "Too Restrictive" Tests** (36 tests)
⭐ **BIGGEST OPPORTUNITY** - These are valid YAML constructs that should pass:
- **2EBW, 3R3P, 5BVJ, 6ZKB**: Various valid block/flow constructs
- **BU8L, CN3R, D88J, DC7X**: Valid YAML patterns being rejected
- **EHF6, FRK4, H2RW, H3Z8**: Additional valid syntax
- **HS5T, J3BT, J9HZ, JEF9**: Valid patterns incorrectly rejected
- **JR7V, JS2J, K527, KK5P**: More valid constructs
- **L24T, M9B4, NAT4, NB6Z**: Valid YAML being rejected
- **NHX8, PRH3, PUW8, QF4Y**: Additional valid cases
- **R4YG, T26H, T5N4, TL85**: Valid syntax patterns
- **U3C3, UDM2, UDR7, W42U**: Final set of too-restrictive cases

**Implementation Strategy**:
1. Study `parseBlockSequence()` and `parseBlockMapping()` indentation logic
2. Add validation for consistent indentation at sequence/mapping boundaries
3. Validate continuation line indentation in multiline constructs
4. Fix anchor placement validation (anchors must be attached to values)

**🔧 Fix "Too Permissive" Tests** (9 tests)
⚠️ **VALIDATION GAPS** - These invalid YAML constructs should fail but currently pass:
- **DK4H**: Invalid directive or document structure
- **GDY7**: Invalid YAML that should be rejected
- **H7TQ**: Flow context validation gap
- **LHL4**: Invalid construct being accepted
- **Q4CL**: Invalid YAML syntax
- **SU74**: Invalid anchor/alias usage (already noted as fixed but still failing)
- **T833**: Invalid YAML construct
- **W9L4**: Invalid syntax being accepted
- **ZCZ6**: Invalid indentation or structure

**📊 PROGRESS TRACKING**: 
- Current: 348/402 (86.6%)
- With "too restrictive" fixes: ~384/402 (95.5%)
- With "too permissive" fixes: ~393/402 (97.8%)
- Target: 394/402 (98%)

### Current Test Failure Breakdown
- **Too Restrictive**: 36 tests - Parser rejects valid YAML (biggest opportunity)
- **Too Permissive**: 9 tests - Parser accepts invalid YAML (validation gaps)
- **Total Unique Failures**: 45 tests

## Important Resources

- **Zig Compiler**: Use `./zig/zig` for all compilation and execution
- **YAML Spec (Compressed)**: Read `./yaml-spec-compressed.md` - This is a condensed version of the full spec and should be your primary reference. **Always load this into memory first** to reference production rules.
- **Full YAML Spec**: Only consult `./yaml-spec.md` when you need specific details not found in the compressed version
- **Reference Implementations**: **CRITICAL - Study these implementations to understand root causes instead of fixing tests one by one**:
  - TypeScript: `./yaml-ts/` - Well-structured recursive descent parser. Read the actual parsing logic to understand how they handle edge cases.
  - Rust: `./yaml-rs/` - Another implementation to reference. Compare approaches between TypeScript and Rust.
- **Test Suite**: `./yaml-test-suite/src/` - Official YAML test suite files

## Architecture Requirements

1. **Recursive Descent Parser**: The parser must be recursive descent, parsing as it lexes (no separate tokenization phase)
2. **Simple Design**: Focus on correctness over optimization. Keep the code readable and maintainable.
3. **Test-Driven**: Build a test runner first, then iteratively improve the parser based on failing tests
4. **Arena Allocator**: Use an arena allocator for all memory allocations during parsing. This simplifies memory management - just destroy the arena when done parsing. No need to worry about individual deallocations or complex lifetime management.

## Project Structure

The parser is fully implemented with the following structure:

```
src/
  main.zig        - Entry point and CLI
  root.zig        - Library exports  
  parser.zig      - Main recursive descent parser (✅ COMPLETE)
  lexer.zig       - Lexer integrated with parser (✅ COMPLETE)
  ast.zig         - AST node definitions with Stream support (✅ COMPLETE)
  test_runner.zig - Test suite runner with verbose mode (✅ COMPLETE)
```

## Current Parser Capabilities

The parser fully implements YAML 1.2 specification including:

✅ **All Core Features**: Plain scalars, block/flow sequences/mappings, quoted strings, comments, multi-line scalars
✅ **Advanced Features**: Anchors & aliases, tags, directives, complex indentation, special values
✅ **Complex Constructs**: Explicit keys, multi-document streams, compact mappings, flow/block mixing
✅ **Edge Cases**: Tab validation, comment separation, indentation rules, escape sequences

## Key Implementation Notes

### Memory Management with Arena Allocator
Example pattern for parsing functions:
```zig
pub fn parse(input: []const u8) !Document {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    var parser = Parser{
        .allocator = arena.allocator(),
        .input = input,
        // ... other fields
    };
    
    return try parser.parseDocument();
}
```

- All AST nodes should be allocated from the arena
- String copies should use arena.allocator().dupe(u8, str)
- No need for individual deallocations
- The entire parse tree is freed when the arena is destroyed

### Indentation Handling
- Track indentation levels using a stack
- Block collections require consistent indentation
- Use the TypeScript implementation's approach as reference

### Character Sets
From the spec, key character classifications:
- Printable: Tab, LF, CR, printable ASCII, and various Unicode ranges
- Indicators: `-?:,[]{}#&*!|>'"%@`` ` ``
- White space: Space and Tab
- Line breaks: LF, CR, CRLF

### Production Rules
The compressed spec uses a grammar notation:
- `::=` defines a production
- `|` means OR
- `*` means zero or more
- `+` means one or more
- `?` means optional
- Literals in quotes match exactly
- Hex values like `x0A` match Unicode code points

### Test File Format
The yaml-test-suite no longer uses the old format with embedded YAML in test files. Instead:
- Each test has its own directory
- The YAML input is in `in.yaml`
- Expected JSON output is in `in.json`
- Test description is in `===`
- If an `error` file exists, the test should fail
- Some tests have multiple subtests in numbered subdirectories

## Development Workflow

### Working with Worktrees
- **45 worktrees created** for each failing test in `worktrees/` directory
- Each worktree has symlinks to: `yaml-rs`, `yaml-ts`, `yaml-test-suite`, `zig`, `yaml-rs-test`
- To work on a specific test: `cd worktrees/TEST_NAME`
- To run tests: `./zig/zig build test-yaml -- zig`
- To check specific test: `./zig/zig build test-yaml -- zig --verbose 2>&1 | grep TEST_NAME`

1. **Revert Non-Working Changes**: When making changes to fix a bug or test:
   - If the changes don't fix the intended bug/test, **revert them immediately**
   - Only keep changes if:
     - They fix the intended issue, OR
     - You believe they are correct and additional changes are needed to complete the fix
   - This prevents accumulating broken changes that may cause regressions
   - Use git to track changes and revert when needed

2. **Study Reference Implementations First**: Before attempting to fix failing tests:
   - Read the relevant parsing functions in `yaml-ts/` and `yaml-rs/`
   - Understand HOW they handle the edge cases, not just WHAT they do
   - Look for patterns in their validation logic
   - Compare approaches between the two implementations
   - This is much more efficient than fixing tests one by one

2. **Use Git for checkpoints**: The project is now under git version control. Make frequent commits as you implement features:
   ```bash
   # After implementing a feature (e.g., plain scalars)
   git add -A
   git commit -m "Implement plain scalar parsing (15% tests passing)"
   
   # After fixing a bug
   git add -A
   git commit -m "Fix indentation handling in block sequences (18% tests passing)"
   ```
   
   This allows you to:
   - Search through history to see what worked: `git log --oneline`
   - Revert failed experiments: `git reset --hard HEAD~1`
   - Create branches for experimental features: `git checkout -b try-multiline-scalars`
   - See what changed: `git diff`

3. Run tests frequently: `./zig/zig build test-yaml -- zig`
4. When tests fail, study the reference implementations to understand the root cause
5. Always have the compressed spec loaded in memory for production rule references
6. Only consult the full spec for specific edge cases not covered in compressed version

## Common Pitfalls to Avoid

1. **Indentation**: YAML is very sensitive to indentation. One space can change meaning.
2. **Line Endings**: Handle all three: LF, CR, and CRLF
3. **Unicode**: YAML supports full Unicode, including in unquoted scalars
4. **Context Sensitivity**: Some characters have different meanings in different contexts
5. **Implicit Typing**: YAML tries to guess types (don't over-complicate this initially)

## Success Metrics

- Primary: Achieve 98%+ passing tests from the official test suite
- Secondary: Clean, readable code that follows Zig best practices
- Tertiary: Reasonable performance (but correctness is more important)

## Getting Started

The project has been initialized with `./zig/zig init`. The test runner is already implemented and can compare your parser against TypeScript and Rust implementations.

### Git Best Practices for This Project

Since the project is under git version control, follow these practices:

1. **Commit Early and Often**: Make a commit after each successfully implemented feature
2. **Meaningful Commit Messages**: Include the test pass percentage in commit messages
   ```bash
   git commit -m "Implement flow sequences [1,2,3] (45% tests passing)"
   ```
3. **Use Branches for Experiments**: Try risky changes in a branch
   ```bash
   git checkout -b experiment-multiline-strings
   # ... make changes ...
   # If it works:
   git checkout main
   git merge experiment-multiline-strings
   # If it doesn't:
   git checkout main
   git branch -D experiment-multiline-strings
   ```
4. **Tag Milestones**: Tag significant progress points
   ```bash
   git tag -a v50-percent -m "Reached 50% test pass rate"
   git tag -a v75-percent -m "Reached 75% test pass rate"
   ```

### Running Tests

The test runner accepts a parser backend as a command-line argument:

```bash
# Test with your Zig parser (currently 84.6% - 340/402 passing)
./zig/zig build test-yaml -- zig

# Test with TypeScript parser (baseline 94.8% - reference implementation)
./zig/zig build test-yaml -- typescript

# Test with Rust parser (baseline 83.8%)
./zig/zig build test-yaml -- rust

# Verbose mode to see specific test results:
./zig/zig build test-yaml -- zig --verbose
```

Key test runner features:
- Command-line parser selection
- Handles single tests and tests with subtests  
- Progress indicators: dots (.) for passes, F for failures
- Verbose mode shows ✓/✗ with test names and failure reasons
- Summary statistics with pass rate percentages

### Test Suite Structure

The test suite is in `yaml-test-suite/` with each test in its own directory:
- `in.yaml` - Input YAML to parse
- `error` - If present, parsing should fail
- `in.json` - Expected JSON output (for passing tests)
- `===` - Test description

## Development Strategy for Reaching 98%

**Current Status: 340/402 (84.6%) → Target: 394/402 (98%)**

### IMMEDIATE NEXT STEPS

**🎯 START HERE: Fix "Too Restrictive" Tests**

1. **Priority: Valid YAML Being Rejected** (14 tests total)
   ```bash
   # Test these specific "too restrictive" cases:
   ./zig/zig build test-yaml -- zig --verbose | grep "UV7Q\|U9NS\|S4T7\|M6YH\|J3BT"
   ```
   - These are valid YAML constructs that our parser incorrectly rejects
   - Usually requires loosening overly strict validation
   - Quick wins since they don't require new validation logic

2. **Flow Collection Validation** (src/parser.zig flow parsing sections)
   - **JKF3, G9HC, BD7L, N4JP**: Add stricter flow syntax validation
   - Study TypeScript implementation's flow parsing
   - Focus on multiline constructs in flow contexts

3. **Document Structure Fixes** (src/parser.zig parseStream/parseDocument)
   - **MUS6/00, MUS6/01**: Fix YAML directive validation
   - **6S55**: Improve document structure validation
   - Study reference implementations for directive handling

**Expected Impact**: 
- Too restrictive fixes: +14 tests → 354/402 (88.1%)
- Flow validation: +10 tests → 364/402 (90.5%)
- Document structure: +8 tests → 372/402 (92.5%)

### Debugging Workflow for Indentation Issues

```bash
# Test specific indentation failures
./zig/zig build test-yaml -- zig --verbose | grep "UV7Q\|U9NS\|S4T7\|M6YH\|J3BT"

# Compare against TypeScript reference (94.8% baseline)
./zig/zig build test-yaml -- typescript --verbose | grep "UV7Q\|U9NS\|S4T7"

# Study indentation handling in reference implementations
grep -r "indent\|getCurrentIndent" yaml-ts/src/
grep -r "sequence.*indent\|mapping.*indent" yaml-ts/src/

# Debug specific test cases
# Test specific "too restrictive" cases to understand what valid YAML we're rejecting
cat yaml-test-suite/src/UV7Q/in.yaml  # Examine what valid construct is rejected
cat yaml-test-suite/src/U9NS/in.yaml  # Check multi-doc edge case
```

**Key Reference Files to Study**:
- `yaml-ts/src/parse/` - TypeScript indentation validation logic
- `yaml-spec-compressed.md` - Block sequence/mapping indent rules
- `src/parser.zig:794-850` - Current `parseBlockSequence()` implementation
- `src/parser.zig:875-1100` - Current `parseBlockMapping()` implementation

### Key Implementation Insights

- **Too Restrictive First**: Fix the 14 tests where valid YAML is rejected (quick wins)
- **Study Reference Implementations**: TypeScript parser (94.8%) has validated indentation logic to reference
- **Systematic Approach**: Fix by category (indentation → flow → document structure) for maximum impact  
- **Avoid Regressions**: Each fix should maintain current 84.6% baseline
- **Test Early and Often**: Run `./zig/zig build test-yaml -- zig` after each change to verify progress

**Success Metrics by Category**:
- Too restrictive fixes: 348 → ~362 tests (86.6% → 90.0%)
- Flow validation: 362 → ~372 tests (90.0% → 92.5%) 
- Document structure: 372 → ~380 tests (92.5% → 94.5%)
- Edge cases: 380 → 394 tests (94.5% → 98.0%)

### Lessons Learned from Fix Attempts

**Current Status (December 2024)**: 
- **348/402 tests passing** (86.6%)
- **45 unique failing tests**: 36 too restrictive, 9 too permissive
- **SU74 still failing** despite previous fix attempt - needs investigation
- Most failures are "too restrictive" - parser is overly strict

**Previous Session Summary**: 
- Initial attempts: Fixes for 236B, H7J7, JKF3, and RHX7 caused regression from 331 to 277 tests
- Recovery: Reverted problematic changes and implemented targeted fixes
- Progress: Successfully fixed 6CA3, 5U3A, 5TRB, 3GZX, 236B (+9 tests total)

**What Went Wrong**:
1. **Lookahead in parseBlockMapping**: Added position save/restore that broke explicit key parsing (M5DY)
2. **Overly broad validation**: Changes intended for specific edge cases affected too many valid cases
3. **parseStream modifications**: Breaking multi-document parsing while trying to fix directive validation
4. **Not testing incrementally**: Made multiple changes before checking full test suite

**Key Learnings**:
- Individual test fixes can have cascading effects - always run full test suite after each change
- Lookahead with position restoration is risky in recursive descent parsers
- Context-based validation (like `isInKeyContext()`) is more reliable than position-based heuristics
- Reference implementations are crucial - study them BEFORE attempting fixes

**Successful Patterns**:
- Using existing parser context (`isInKeyContext()`) for validation worked well
- Small, targeted fixes are safer than broad changes
- Git commits after each successful fix help track progress and enable easy reversion