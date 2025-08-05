Of course. Here is a detailed, phased implementation plan for a developer named Claude to get the Zig YAML parser to 100% `yaml-test-suite` compliance.

This plan breaks the work into manageable stages, starting with the most critical features and moving toward subtle edge cases. Each step includes the "what," the "why," and "how to verify," using the `yaml-test-suite` as the benchmark for success.

---

### **Project Plan: Achieving 100% yaml-test-suite Compliance**

**Developer:** Claude
**Goal:** Implement all required changes to pass 100% of the official YAML test suite.

---

### **Phase 1: Implement Foundational Features (Anchors, Aliases & Tags)**

**Objective:** Implement the core YAML features of data reuse (anchors/aliases) and type tagging. A large percentage of the test suite depends on these, so they are the highest priority.

**Step 1.1: Implement Anchor & Alias Resolution**

- **Why:** The current parser identifies anchors (`&`) and aliases (`*`) but doesn't connect them. This is fundamental for parsing most non-trivial YAML.
- **Actions:**
  1.  **Modify `Parser` Struct:** Add a hash map to store named nodes. This map must be cleared for each new document in a stream.
      ```zig
      // In the Parser struct
      anchors: std.StringHashMap(*ast.Node),
      ```
      Initialize it in `Parser.init` and deinitialize it in `Parser.deinit`. Remember to clear it at the start of `parseDocument`.
  2.  **Register Anchors:** In `parseValue`, locate the section that parses an anchor (`if ch == '&'`). After the associated node (`node`) has been completely parsed and allocated, insert it into the `anchors` map.
      - **Code Location:** Just before `return node;` in `parseValue`.
      - **Logic:**
        ```zig
        if (node) |n| {
            if (anchor) |a| {
                if (self.anchors.get(a) != null) {
                    return error.DuplicateAnchor;
                }
                try self.anchors.put(a, n);
                n.anchor = a;
            }
            // ... rest of the logic
        }
        ```
  3.  **Resolve Aliases:** In `parseValue`, find the alias parsing logic (`if ch == '*'`).
      - **Code Location:** In the `else if (ch == '*')` block.
      - **Logic:** Instead of creating a new `alias` node, look up the alias name in `self.anchors`.
        - If found, return the stored `*ast.Node` pointer directly. **Do not create a new node.**
        - If not found, return an `error.InvalidAlias`.
- **Verification:** Run all tests from the `yaml-test-suite` that contain `&` and `*`. This includes tests like `2XXW`, `6ZKB`, `9SXS`, and many others.

**Step 1.2: Implement `%TAG` Directive and Tag Resolution**

- **Why:** The parser currently skips `%TAG` directives, making it impossible to correctly interpret shorthand tags like `!e!foo`.
- **Actions:**
  1.  **Modify `Parser` Struct:** Add a hash map for tag handles. This also needs to be reset for each document.
      ```zig
      // In the Parser struct
      tag_handles: std.StringHashMap([]const u8),
      ```
  2.  **Parse `%TAG` Directive:** In `parseDocument`, enhance the existing `else if (std.mem.eql(u8, directive_name, "TAG"))` block.
      - **Logic:** Parse the tag handle (e.g., `!e!`) and the prefix (e.g., `!example.com,2000/`) and store the mapping in `self.tag_handles`.
  3.  **Resolve Shorthand Tags:** In `parseValue`, when a tag is found, it needs to be resolved before being attached to the node.
      - **Logic:** Check if the parsed tag `t` contains a recognized handle from `self.tag_handles`. If it does, construct the full tag URI by replacing the handle with its prefix. Store this expanded tag on the node.
- **Verification:** Run all tests involving `%TAG` directives and shorthand tags (e.g., `6CKJ`, `C4HZ`, `P76L`).

---

### **Phase 2: Refine Core Parsing and Indentation Logic**

**Objective:** Tackle the most difficult part of YAML parsing: indentation, context sensitivity, and multi-line scalar rules.

**Step 2.1: Perfect Indentation and Complex Keys**

- **Why:** Flawless indentation handling is the key to passing the most complex block-style tests.
- **Actions:**
  1.  **Strict Tab Enforcement:** Audit the parser and ensure `checkIndentationForTabs` is called at the beginning of every line-consuming operation in a block context (i.e., the `while` loops in `parseBlockMapping` and `parseBlockSequence`).
  2.  **Complex Key Parsing:** This is critical. The YAML spec allows entire collections to be keys.
      - **Code Location:** In `parseBlockMapping` and `parseFlowMapping`, find the `?` (explicit key) parsing logic.
      - **Change:** Replace `key = try self.parsePlainScalar()` with `key = try self.parseValue(current_indent)`. This allows the key to be any valid YAML structure (flow map, sequence, etc.).
- **Verification:** Run tests with complex keys, such as `4QFK`, `6S7S`, `K54U`.

**Step 2.2: Refine Block and Plain Scalar Parsing**

- **Why:** The rules for multi-line scalars, especially plain (unquoted) and double-quoted ones, are full of edge cases that are heavily tested.
- **Actions:**
  1.  **Block Scalar Indentation:** Find tests from the suite that have empty or whitespace-only lines preceding the first content line of a `|` or `>` scalar. Use these to debug the auto-detection logic for `block_indent`.
  2.  **Plain Scalar Interruption by Comments:** This is famously difficult. The existing logic is a good start.
      - **Strategy:** Find the specific tests for this (e.g., `9SXL`, `M7A_`). Step through the `parsePlainScalar` function in a debugger. The key is to correctly determine if a comment line _ends_ the scalar (because the next line is less indented) or _illegally interrupts_ it (because the next line is indented as a continuation).
  3.  **Double-Quoted Multiline Folding:** Review `parseDoubleQuotedScalar`.
      - **Logic:** The current implementation correctly handles escaped newlines (`\n`). It needs refinement for unescaped newlines.
        - A single unescaped newline between text should be folded to a space.
        - A blank line (two consecutive newlines) should result in a literal newline (`\n`) in the output.
        - Leading/trailing spaces on lines being folded are stripped.
- **Verification:** Run the full test suite. Pay close attention to failures in tests with names like `4CQQ` (folded), `6BCT` (literal), `6WPF` (plain multiline), and `7Z25` (double-quoted multiline).

---

### **Phase 3: Final Polish, Edge Cases, and Full Compliance**

**Objective:** Address the remaining, often obscure, edge cases to reach 100% pass rate.

**Step 3.1: Finalize Document and Error Handling**

- **Why:** Correctly handling document boundaries and producing the right error for invalid input is part of compliance.
- **Actions:**
  1.  **Document State Reset:** In `parseStream`, explicitly ensure the `anchors` and `tag_handles` maps are cleared before parsing each new document. An anchor from one document cannot be used in another.
  2.  **Error Verification:** For any remaining failing tests, check if the failure is due to producing the wrong _error type_. The `yaml-test-suite` often includes `.error` files that specify the expected failure. Ensure your `ParseError` enum maps correctly to these scenarios.
  3.  **Final Comment Checks:** Double-check comment placement rules. A common failure is allowing a comment where it's not permitted (e.g., `[item#comment]`). The `skipWhitespaceAndCommentsInFlow` function is key here.

**Step 3.2: The Final Push**

- **Why:** To get from 99% to 100%.
- **Actions:**
  1.  **Run the Full Suite:** Execute your parser against the entire `yaml-test-suite`.
  2.  **Triage Failures:** List the remaining 5-10 failing tests.
  3.  **Isolate and Conquer:** For each failure:
      - Read the test's description (`.yaml-test` file).
      - Examine the input (`.yaml` file) and the expected output (`.json` or `.error` file).
      - Trace the parser's execution with the failing input to find the exact point of divergence.
      - Fix the logic, ensuring it doesn't break previously passing tests.
  4.  **Repeat until Zero Failures.**

By following this structured plan, you will systematically build up the parser's capabilities and robustness, ensuring that each change is verified against the official standard before moving on to the next challenge. Good luck, Claude
