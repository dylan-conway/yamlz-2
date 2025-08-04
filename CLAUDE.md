# YAML Parser Implementation in Zig

## Project Overview

You are implementing a YAML 1.2 parser in Zig using a recursive descent parsing approach. The goal is to achieve 98%+ passing tests from the official YAML test suite.

## Current Implementation Status

**Test Pass Rate**: 328/402 (81.6%)
- Target: 394/402 (98%)
- Gap: 66 tests

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
**Gap Analysis Complete**: To close the 66-test gap, focus on these validated categories:

**🎯 NEXT PRIORITY: Indentation Validation** (~20-25 tests) 
⭐ **START HERE** - Highest impact, clearest rules from spec
- **ZVH3**: Wrong indented sequence items (`- key: value\n - item1` - second item at wrong indent)
- **QB6E**: Wrong indented multiline quoted scalars (continuation lines must be properly indented)
- **236B**: Invalid value after mapping (`foo:\n  bar\ninvalid` - unindented content after mapping value)
- **GT5M**: Floating anchors without values (`- item1\n&node\n- item2`)
- **H7J7**: Node anchor not indented properly (`key: &x\n!!map\n  a: b`)

**Implementation Strategy**:
1. Study `parseBlockSequence()` and `parseBlockMapping()` indentation logic
2. Add validation for consistent indentation at sequence/mapping boundaries
3. Validate continuation line indentation in multiline constructs
4. Fix anchor placement validation (anchors must be attached to values)

**🔧 NEXT: Flow Collection Validation** (~10-15 tests)
- **ZL4Z**: Invalid nested mapping (`a: 'b': c` - nested mapping syntax error)
- **JKF3**: Multiline unindented double quoted block key (not allowed in flow context)
- Add stricter syntax validation for flow collections
- Validate proper flow mapping/sequence nesting rules

**⚠️ MEDIUM: Document Structure** (~10-15 tests)
- **RHX7**: YAML directive without document end marker (directives after content)
- Add validation for directive placement rules
- Improve document boundary handling

**🔍 COMPLEX: Plain Scalar Comment Interruption** (~10-15 tests) 
⚠️ **SAVE FOR LATER** - Complex multiline parsing edge cases
- **8XDJ**: Comment interrupting plain scalar continuation (`key: word1\n#  xxx\n  word2`)
- **BF9H**: Similar comment interruption patterns
- Requires significant changes to multiline scalar parsing logic

**📊 TRACKING**: 
- Current: 328/402 (81.6%)
- With indentation fixes: ~348/402 (86.6%)
- With flow validation: ~358/402 (89.1%)
- Target: 394/402 (98%)

### Validation Gap Categories (81.6% Pass Rate)
- **Too Permissive**: ~50 tests "expected error, got success" - Parser accepts invalid YAML
- **Too Restrictive**: ~16 tests "expected success, got error" - Parser rejects valid YAML  
- **Analysis Complete**: Detailed failing test categorization and prioritization done
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

**Current Status: 328/402 (81.6%) → Target: 394/402 (98%)**

### IMMEDIATE NEXT STEPS

**🎯 START HERE: Indentation Validation Implementation**

1. **Fix Block Sequence Indentation** (src/parser.zig:794-850)
   ```bash
   # Test these specific failing cases:
   ./zig/zig build test-yaml -- zig --verbose | grep "ZVH3\|GT5M\|236B"
   ```
   - **ZVH3**: Add validation in `parseBlockSequence()` that all `-` indicators are at same indent
   - **GT5M**: Validate anchors are attached to actual values, not floating
   - Implement stricter indentation consistency checks

2. **Fix Multiline String Indentation** (src/parser.zig:1132-1300)
   - **QB6E**: Add validation for proper continuation line indentation in double-quoted strings
   - Study continuation line rules in yaml-spec-compressed.md
   - Ensure multiline strings follow indentation requirements

3. **Fix Block Mapping Structure** (src/parser.zig:875-1100) 
   - **236B**: Add validation that content after mapping values is properly structured
   - Validate that unindented content after mapping value is invalid
   - **H7J7**: Fix anchor placement validation

**Expected Impact**: 20-25 tests → ~348/402 (86.6%)

### Debugging Workflow for Indentation Issues

```bash
# Test specific indentation failures
./zig/zig build test-yaml -- zig --verbose | grep "ZVH3\|QB6E\|236B\|GT5M\|H7J7"

# Compare against TypeScript reference (94.8% baseline)
./zig/zig build test-yaml -- typescript --verbose | grep "ZVH3\|QB6E\|236B"

# Study indentation handling in reference implementations
grep -r "indent\|getCurrentIndent" yaml-ts/src/
grep -r "sequence.*indent\|mapping.*indent" yaml-ts/src/

# Debug specific test cases
echo "- key: value\n - item1" | ./zig/zig run debug_test.zig  # ZVH3 case
echo "foo:\n  bar\ninvalid" | ./zig/zig run debug_test.zig      # 236B case
```

**Key Reference Files to Study**:
- `yaml-ts/src/parse/` - TypeScript indentation validation logic
- `yaml-spec-compressed.md` - Block sequence/mapping indent rules
- `src/parser.zig:794-850` - Current `parseBlockSequence()` implementation
- `src/parser.zig:875-1100` - Current `parseBlockMapping()` implementation

### Key Implementation Insights

- **Indentation is Critical**: ~35% of failing tests are indentation-related validation gaps
- **Study Reference Implementations**: TypeScript parser (94.8%) has validated indentation logic to reference
- **Systematic Approach**: Fix by category (indentation → flow → document structure) for maximum impact  
- **Avoid Regressions**: Each fix should maintain current 81.6% baseline
- **Test Early and Often**: Run `./zig/zig build test-yaml -- zig` after each change to verify progress

**Success Metrics by Category**:
- Indentation fixes: 328 → ~348 tests (81.6% → 86.6%)
- Flow validation: 348 → ~358 tests (86.6% → 89.1%) 
- Document structure: 358 → ~368 tests (89.1% → 91.5%)
- Edge cases: 368 → 394 tests (91.5% → 98.0%)