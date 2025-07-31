# YAML Parser Implementation in Zig

## Project Overview

You are implementing a YAML 1.2 parser in Zig using a recursive descent parsing approach. The goal is to achieve 98%+ passing tests from the official YAML test suite.

## Current Implementation Status

**Test Pass Rate**: 286/402 (71.1%)
- Target: 394/402 (98%)
- Gap: 108 tests

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
   - Explicit key indicators (`?`) - partial support
   - Mappings inside sequences
   - Special values (null, true/false, .inf, .nan)
   - YAML 1.1 boolean compatibility (yes/no, on/off, y/n)

3. **Recent Fixes**:
   - Flow sequence empty entry validation (CTN5)
   - Block scalar indicator validation (S4GJ, D83L)
   - Tab validation in block sequences (Y79Y test suite - all passing)
   - Trailing comma support in flow sequences
   - Basic document directives (%YAML, %TAG)
   - Block sequence/mapping indentation validation
   - Improved plain scalar parsing in flow context (FRK4 now passing)
   - Fixed colon handling in plain scalars for flow context

4. **Architecture**:
   - Clean separation: lexer.zig, ast.zig, parser.zig
   - Arena allocator for memory management
   - Proper line/column tracking
   - Test runner comparing against reference implementations

### Remaining Work to Reach 98%
To close the 108-test gap, prioritize these high-impact areas:

1. **Tab Validation in Quoted Strings** (~10 tests): DK95 test suite
   - Tabs at beginning of continuation lines in double-quoted strings
   - Tabs that look like indentation should fail

2. **Explicit Key Syntax** (~15-20 tests):
   - Full support for `?` explicit key indicator
   - Complex keys (sequences/mappings as keys)
   - Empty keys: `{? : value}`
   - Explicit key-value pairs in block mappings

3. **Plain Scalar Edge Cases** (~15-20 tests):
   - Multi-line implicit keys (HU3P) - plain scalars can't contain mappings
   - Comments interrupting scalars (8XDJ)
   - Proper termination rules based on context
   - `:` handling in flow contexts

4. **Comment Validation** (~10-15 tests):
   - Comments require whitespace before `#` (except at line start)
   - Invalid comments like `"text#comment"`

5. **Flow Collection Edge Cases** (~10-15 tests):
   - Empty entry validation (no consecutive commas)
   - Plain scalars starting with indicators (`:x`)
   - Complex flow mappings

6. **String Escape Sequences** (~5-10 tests):
   - Invalid escape sequence validation
   - `\'` not valid in double-quoted strings
   - Only specific escapes allowed

7. **Multi-document Support** (~5-10 tests):
   - Handle multiple documents with `---` and `...`
   - Directives only before first document
   - Proper document separation

### Known Issues
- Parser is too permissive (~63 tests "expected error, got success")
- Missing key features (~51 tests "expected success, got error")
- Need better error propagation for specific validation failures
- No support for multiple documents in a stream

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

## Implementation Plan

### Phase 1: Project Setup and Test Runner

The project has been initialized with `./zig/zig init`, which created:
- `build.zig` - Build configuration
- `build.zig.zon` - Package manifest
- `src/main.zig` - Executable entry point
- `src/root.zig` - Library entry point

Extend this structure with:
```
src/
  main.zig        - Entry point and CLI (already exists)
  root.zig        - Library exports (already exists)
  parser.zig      - Main parser implementation
  lexer.zig       - Lexer that works with the parser
  ast.zig         - AST node definitions
  test_runner.zig - Test suite runner
```

2. Test runner is already implemented (`src/test_runner.zig`):

The test runner has been implemented and supports switching between parsers:

```bash
# Run with TypeScript parser (94.8% pass rate)
./zig/zig build test-yaml -- typescript

# Run with Rust parser (83.8% pass rate)
./zig/zig build test-yaml -- rust

# Run with our Zig parser (23.4% - just expected-to-fail tests)
./zig/zig build test-yaml -- zig

# Run with verbose output to see test names and failure reasons
./zig/zig build test-yaml -- typescript --verbose
./zig/zig build test-yaml -- rust --verbose
./zig/zig build test-yaml -- zig --verbose
```

Key features:
- Command-line parser selection
- Handles both single tests and tests with subtests
- Properly identifies expected-to-fail tests (with `error` file)
- Shows progress with dots (.) for passes and F for failures
- Reports summary statistics
- Verbose mode (`--verbose`) shows test names and failure reasons with ✓/✗ symbols

3. Test runner is already added to build.zig with command-line argument support:

```zig
// Already in build.zig:
const test_runner = b.addExecutable(.{
    .name = "yaml-test-runner",
    .root_source_file = b.path("src/test_runner.zig"),
    .target = target,
    .optimize = optimize,
});

b.installArtifact(test_runner);

const run_tests_cmd = b.addRunArtifact(test_runner);
run_tests_cmd.step.dependOn(b.getInstallStep());

// Add argument forwarding
if (b.args) |args| {
    run_tests_cmd.addArgs(args);
}

const run_yaml_tests = b.step("test-yaml", "Run YAML test suite");
run_yaml_tests.dependOn(&run_tests_cmd.step);
```

4. Create a minimal parser stub (`src/parser.zig`) to get started:

```zig
const std = @import("std");

pub const Document = struct {
    // Placeholder for now
    data: []const u8,
};

pub fn parse(input: []const u8) !Document {
    // For now, just return error to see all tests fail
    return error.NotImplemented;
}
```

Now you can run `./zig/zig build test-yaml -- zig` to see the baseline (23.4% passing - these are tests expected to fail).

### Phase 2: Basic Parser Structure

1. Implement the lexer (`lexer.zig`):

```zig
const std = @import("std");

pub const Lexer = struct {
    input: []const u8,
    pos: usize = 0,
    line: usize = 1,
    column: usize = 1,
    line_start: usize = 0, // Position of current line start
    
    pub fn init(input: []const u8) Lexer {
        return .{ .input = input };
    }
    
    pub fn peek(self: *const Lexer) u8 {
        if (self.pos >= self.input.len) return 0;
        return self.input[self.pos];
    }
    
    pub fn peekNext(self: *const Lexer) u8 {
        if (self.pos + 1 >= self.input.len) return 0;
        return self.input[self.pos + 1];
    }
    
    pub fn advance(self: *Lexer, count: usize) void {
        var i: usize = 0;
        while (i < count and self.pos < self.input.len) : (i += 1) {
            if (self.input[self.pos] == '\n') {
                self.line += 1;
                self.column = 1;
                self.line_start = self.pos + 1;
            } else {
                self.column += 1;
            }
            self.pos += 1;
        }
    }
    
    pub fn match(self: *const Lexer, str: []const u8) bool {
        if (self.pos + str.len > self.input.len) return false;
        return std.mem.eql(u8, self.input[self.pos..self.pos + str.len], str);
    }
    
    pub fn currentIndent(self: *const Lexer) usize {
        // Count spaces from start of current line
        var indent: usize = 0;
        var i = self.line_start;
        while (i < self.input.len and self.input[i] == ' ') : (i += 1) {
            indent += 1;
        }
        return indent;
    }
    
    pub fn isEOF(self: *const Lexer) bool {
        return self.pos >= self.input.len;
    }
    
    // Character classification
    pub fn isWhitespace(ch: u8) bool {
        return ch == ' ' or ch == '\t';
    }
    
    pub fn isLineBreak(ch: u8) bool {
        return ch == '\n' or ch == '\r';
    }
    
    pub fn isFlowIndicator(ch: u8) bool {
        return ch == ',' or ch == '[' or ch == ']' or ch == '{' or ch == '}';
    }
    
    pub fn isIndicator(ch: u8) bool {
        return switch (ch) {
            '-', '?', ':', ',', '[', ']', '{', '}', '#', '&', '*', '!', '|', '>', '\'', '"', '%', '@', '`' => true,
            else => false,
        };
    }
};
```

2. Create AST nodes (`ast.zig`):

```zig
const std = @import("std");

pub const NodeType = enum {
    scalar,
    sequence,
    mapping,
    alias,
};

pub const Node = struct {
    type: NodeType,
    start_line: usize = 0,
    start_column: usize = 0,
    anchor: ?[]const u8 = null,
    tag: ?[]const u8 = null,
    
    // Use a union for the actual data
    data: union {
        scalar: Scalar,
        sequence: Sequence,
        mapping: Mapping,
        alias: []const u8,
    },
};

pub const Scalar = struct {
    value: []const u8,
    style: enum {
        plain,
        single_quoted,
        double_quoted,
        literal,
        folded,
    } = .plain,
};

pub const Sequence = struct {
    items: std.ArrayList(*Node),
};

pub const Mapping = struct {
    pairs: std.ArrayList(Pair),
};

pub const Pair = struct {
    key: *Node,
    value: *Node,
};

pub const Document = struct {
    root: ?*Node,
    directives: ?Directives = null,
};

pub const Directives = struct {
    yaml_version: ?[]const u8 = null,
    tags: std.ArrayList(TagDirective),
};

pub const TagDirective = struct {
    handle: []const u8,
    prefix: []const u8,
};
```

3. Start parser implementation (`parser.zig`):

```zig
const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const ast = @import("ast.zig");

pub const Parser = struct {
    lexer: Lexer,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, input: []const u8) Parser {
        return .{
            .lexer = Lexer.init(input),
            .allocator = allocator,
        };
    }
    
    // Main entry point
    pub fn parseDocument(self: *Parser) !ast.Document {
        // Skip any leading whitespace/comments
        self.skipWhitespaceAndComments();
        
        // Check for directives (---)
        if (self.lexer.match("---")) {
            self.lexer.advance(3);
            self.skipWhitespaceAndComments();
        }
        
        // Parse the root value
        const root = try self.parseValue(0);
        
        return ast.Document{
            .root = root,
        };
    }
    
    // Parse any value based on context
    fn parseValue(self: *Parser, min_indent: usize) !*ast.Node {
        self.skipWhitespaceAndComments();
        
        const ch = self.lexer.peek();
        
        // Flow style
        if (ch == '[') return try self.parseFlowSequence();
        if (ch == '{') return try self.parseFlowMapping();
        if (ch == '"') return try self.parseDoubleQuotedScalar();
        if (ch == '\'') return try self.parseSingleQuotedScalar();
        
        // Block style - check indentation
        const indent = self.lexer.currentIndent();
        if (indent < min_indent) return error.InsufficientIndent;
        
        // Check for block indicators
        if (ch == '-' and self.lexer.peekNext() == ' ') {
            return try self.parseBlockSequence(indent);
        }
        
        // Try to parse as mapping (key: value)
        if (self.isPlainScalarStart()) {
            const save_pos = self.lexer.pos;
            _ = try self.parsePlainScalar();
            self.skipSpaces();
            
            if (self.lexer.peek() == ':') {
                self.lexer.pos = save_pos; // Restore position
                return try self.parseBlockMapping(indent);
            }
            
            self.lexer.pos = save_pos; // Restore position
        }
        
        // Default to scalar
        return try self.parsePlainScalar();
    }
    
    // ... more parsing methods ...
};

// Public API
pub fn parse(input: []const u8) !ast.Document {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    var parser = Parser.init(arena.allocator(), input);
    return try parser.parseDocument();
}
```

Key parsing patterns:
- Always check indentation for block constructs
- Use lookahead to determine structure type
- Save/restore position when ambiguous
- Flow style takes precedence over block style

### Phase 3: Core Features

Implement in this order (based on test suite frequency):

1. **Plain Scalars**: Unquoted strings
2. **Block Mappings**: Key-value pairs with indentation
3. **Block Sequences**: Lists with dash markers
4. **Flow Mappings**: `{key: value}` style
5. **Flow Sequences**: `[item1, item2]` style
6. **Quoted Strings**: Single and double quotes with escaping
7. **Comments**: `# comment` handling
8. **Multi-line Scalars**: Literal `|` and folded `>` styles

### Phase 4: Advanced Features

1. **Anchors & Aliases**: `&anchor` and `*anchor` references
2. **Tags**: Type annotations like `!!str`
3. **Directives**: `%YAML 1.2` and `%TAG`
4. **Complex Indentation**: Mixed block/flow styles
5. **Special Values**: `.inf`, `.nan`, booleans, null variations

### Phase 5: Polish and Optimization

1. Improve error messages with line/column information
2. Handle edge cases found in failing tests
3. Optimize performance if needed (but keep it simple)
4. Ensure arena allocator is properly used everywhere (no memory leaks)

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
# Test with your Zig parser (currently 22.2% - just the expected-to-fail tests)
./zig/zig build test-yaml -- zig

# Test with TypeScript parser (baseline ~89%)
./zig/zig build test-yaml -- typescript

# Test with Rust parser (baseline ~84%)
# First build the Rust parser binary:
./build_rust_parser.sh
# Then run tests:
./zig/zig build test-yaml -- rust
```

If no parser is specified, it will show usage instructions.

### Test Suite Structure

The test suite is in `yaml-test-suite/` with each test in its own directory:
- `in.yaml` - Input YAML to parse
- `error` - If present, parsing should fail
- `in.json` - Expected JSON output (for passing tests)
- `===` - Test description

### Development Workflow

1. Run `./zig/zig build test-yaml -- zig` to see baseline (22.2%)
2. Implement features in `src/parser.zig`
3. Run tests again to see progress
4. Compare against TypeScript and Rust parsers as needed
5. Target: 98% passing

Remember: Start simple, test often, and incrementally add complexity. The recursive descent approach means you can build the parser piece by piece.

## Iterative Development Strategy

1. **Start with the test runner** ✅ - Already implemented with verbose mode support
2. **Implement minimal parser** ✅ - Currently at 72.4% (291/402 tests passing)
3. **Study Reference Implementations** - **THIS IS CRITICAL**:
   ```bash
   # When you see a pattern of failures (e.g., tab validation)
   # 1. First read the compressed spec into memory
   # 2. Then examine the reference implementations:
   grep -r "tab\|Tab\|TAB\|\t" yaml-ts/src/
   grep -r "tab\|Tab\|TAB\|\t" yaml-rs/src/
   
   # Study how they handle the specific case
   # Look at their validation logic, not just the parsing
   ```
4. **Fix categories of bugs, not individual tests**:
   - Group failing tests by root cause
   - Study reference implementations for that category
   - Implement the fix based on understanding the pattern
   - This is much faster than fixing tests one by one
5. **Use verbose mode to identify patterns**:
   ```bash
   ./zig/zig build test-yaml -- zig --verbose | grep "✗" | sort
   ```
6. **Commit after each category fix**:
   ```bash
   # After fixing a category (e.g., tab validation)
   git add -A
   git commit -m "Fix tab validation in flow contexts (78% tests passing)"
   ```
7. **Debug by comparing implementations**:
   ```bash
   # When stuck on a test, run it through all parsers:
   ./zig/zig build test-yaml -- typescript --verbose | grep "TEST_NAME"
   ./zig/zig build test-yaml -- rust --verbose | grep "TEST_NAME"
   ./zig/zig build test-yaml -- zig --verbose | grep "TEST_NAME"
   ```
8. **Focus on high-impact categories** - Tab validation, flow mappings, and indentation issues affect many tests

The key insight: Understanding WHY the reference implementations make certain choices (by reading their code) is much more valuable than just knowing WHAT they do. This transforms the problem from "fix 103 individual tests" to "fix ~10 categories of issues."