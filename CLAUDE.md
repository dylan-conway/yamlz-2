# YAML Parser Implementation in Zig

## Project Overview

You are implementing a YAML 1.2 parser in Zig using a recursive descent parsing approach. The goal is to achieve 98%+ passing tests from the official YAML test suite.

## Current Implementation Status

**Test Pass Rate**: 340/402 (84.6%)
- Target: 394/402 (98%)
- Gap: 54 tests

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

3. **Recent Major Fixes** (2024-2025 Sessions):
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
**Gap Analysis Updated**: To close the 54-test gap, focus on these categories:

**🎯 NEXT PRIORITY: Too Restrictive Fixes** (~14 tests) 
⭐ **LOW-HANGING FRUIT** - Valid YAML being rejected incorrectly
- **UV7Q, U9NS, S4T7, M6YH**: Various valid constructs rejected
- **J3BT, HS5T, E76Z**: Valid YAML patterns
- **VJP3/01, ZF4X, DC7X**: Flow/block context issues
- **2SXE, A2M4, UT92, 6M2F, FH7J**: Additional valid cases
- These typically require loosening overly strict validation

**Implementation Strategy**:
1. Study `parseBlockSequence()` and `parseBlockMapping()` indentation logic
2. Add validation for consistent indentation at sequence/mapping boundaries
3. Validate continuation line indentation in multiline constructs
4. Fix anchor placement validation (anchors must be attached to values)

**🔧 Flow Collection Validation** (~10-12 tests)
- **JKF3**: Multiline unindented double quoted block key (not allowed in flow context)
- **G9HC, BD7L, N4JP**: Invalid flow collection syntax patterns
- **H7TQ, 9C9N**: Flow context validation gaps
- **ZL4Z**: Invalid nested mapping (`a: 'b': c` - nested mapping syntax error)
- Add stricter syntax validation for flow collections
- Validate proper flow mapping/sequence nesting rules

**⚠️ Document Structure/Directives** (~8-10 tests)
- **MUS6/00, MUS6/01**: YAML directive validation gaps
- **6S55**: Document structure validation issues
- **RXY3, P2EQ**: Document boundary edge cases
- Add validation for directive placement rules
- Improve document boundary handling

**🔍 Plain Scalar Comment Interruption** (~8-10 tests) 
⚠️ **COMPLEX** - Multiline parsing edge cases
- **8XDJ**: Comment interrupting plain scalar continuation (`key: word1\n#  xxx\n  word2`)
- **BF9H, 4JVG**: Similar comment interruption patterns
- **DK95/01**: Complex plain scalar edge cases
- Requires significant changes to multiline scalar parsing logic

**❌ Indentation Edge Cases** (~6-8 tests)
- **4HVU**: Block sequence indentation (attempted fix caused regression)
- **ZCZ6, SY6V**: Various indentation validation gaps
- **DMG6, QLJ7**: Indentation in complex structures
- Need careful implementation to avoid regressions

**📊 TRACKING**: 
- Current: 340/402 (84.6%)
- With "too restrictive" fixes: ~354/402 (88.1%)
- With flow validation: ~364/402 (90.5%)
- With document structure: ~372/402 (92.5%)
- Target: 394/402 (98%)

### Validation Gap Categories (84.6% Pass Rate)
- **Too Permissive**: 48 tests "expected error, got success" - Parser accepts invalid YAML
- **Too Restrictive**: 14 tests "expected success, got error" - Parser rejects valid YAML  
- **Progress Made**: +9 tests fixed since last major update
- **Architecture Ready**: Parser has solid validation framework, ready for systematic improvements

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
- Too restrictive fixes: 340 → ~354 tests (84.6% → 88.1%)
- Flow validation: 354 → ~364 tests (88.1% → 90.5%) 
- Document structure: 364 → ~372 tests (90.5% → 92.5%)
- Edge cases: 372 → 394 tests (92.5% → 98.0%)

### Lessons Learned from Fix Attempts

**Session Summary (2025)**: 
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