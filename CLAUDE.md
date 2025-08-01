# YAML Parser Implementation in Zig

## Project Overview

You are implementing a YAML 1.2 parser in Zig using a recursive descent parsing approach. The goal is to achieve 98%+ passing tests from the official YAML test suite.

## Current Implementation Status

**Test Pass Rate**: 327/402 (81.3%)
- Target: 394/402 (98%)
- Gap: 67 tests

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

3. **Recent Major Fixes** (2024 Session):
   ✅ **Explicit Key Syntax (X8DW, ZWK4)**: Complete support for `?` indicator with comment separation and null values
   ✅ **Flow Collection Comments (7TMG)**: Fixed overly restrictive comment validation in flow contexts
   ✅ **Multi-Document Support**: Complete streams with `---`/`...` separators (M7A3, U9NS, 6XDY, 35KP)
   ✅ **Block Sequence Mappings (JQ4R)**: Fixed compact mappings inside block sequence entries  
   ✅ **Tab Validation (7A4E)**: Corrected tab handling in double-quoted string continuations
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
To close the 67-test gap, prioritize these high-impact areas:

1. **Flow Collection Edge Cases** (~10-15 tests): 🚧 **IN PROGRESS**
   - Empty entry validation (no consecutive commas)
   - Plain scalars starting with indicators (`:x`)
   - Complex flow mappings with edge cases

2. **Plain Scalar Comment Interruption** (~10-15 tests):
   - Comments interrupting multiline scalars (BF9H, 8XDJ)
   - These are complex edge cases that even reference implementations struggle with
   - May require significant multiline parsing logic changes

3. **String Escape Sequences** (~5-10 tests):
   - Invalid escape sequence validation
   - `\'` not valid in double-quoted strings
   - Only specific escapes allowed

4. **Permissive Parser Issues** (~20-30 tests):
   - Many "expected error, got success" cases where parser is too lenient
   - Need stricter validation for edge cases
   - Requires careful analysis to avoid breaking valid cases

5. **Missing Success Cases** (~10-15 tests):
   - "expected success, got error" cases
   - Usually complex valid YAML that current parser rejects
   - Often involves intricate indentation or flow/block mixing

### Current Analysis (81.3% Pass Rate)
- **Too Permissive**: ~45 tests "expected error, got success" - Parser accepts invalid YAML
- **Too Restrictive**: ~30 tests "expected success, got error" - Parser rejects valid YAML  
- **Major Gaps Closed**: Explicit keys, multi-document support, flow comments, tab validation
- **Focus Areas**: Flow collection edge cases, escape sequences, permissive validation

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

1. **Study Reference Implementations First**: Before attempting to fix failing tests:
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
# Test with your Zig parser (currently 81.3% - 327/402 passing)
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

**Current Status: 327/402 (81.3%) → Target: 394/402 (98%)**

### Priority Approach

1. **Focus on Flow Collection Edge Cases** 🚧 IN PROGRESS
   - Continue fixing issues like empty entries, complex flow mappings
   - These typically have clear spec rules and reference implementations

2. **Address Permissive Parser Issues** 
   - ~45 "expected error, got success" tests
   - Use reference implementations to understand what should fail
   - Add targeted validation without breaking existing functionality

3. **Fix Restrictive Parser Issues**
   - ~30 "expected success, got error" tests  
   - Usually complex but valid YAML constructs
   - Study TypeScript parser (94.8% baseline) for guidance

### Debugging Workflow

```bash
# Identify failure patterns
./zig/zig build test-yaml -- zig --verbose | grep "✗" | sort

# Compare against reference implementations  
./zig/zig build test-yaml -- typescript --verbose | grep "TEST_NAME"
./zig/zig build test-yaml -- zig --verbose | grep "TEST_NAME"

# Study reference implementation source code
grep -r "specific_pattern" yaml-ts/src/
```

### Key Insights

- **Study WHY, not just WHAT**: Understanding reference implementation choices transforms "fix 67 individual tests" into "fix ~5-8 categories of issues"
- **Avoid regressions**: Each fix should maintain current 81.3% baseline
- **Target high-impact areas**: Some categories affect 10+ tests each