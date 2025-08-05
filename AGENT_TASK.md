# Fix Test HS5T

## Task
Your task is to fix the failing YAML test **HS5T** without breaking any other tests.

## Test Type
This is a **unknown** test:

## Working Directory
You are in worktree: /Users/dylan/code/yamlz-2/worktrees/HS5T
Branch: fix-HS5T

## Instructions
1. First understand why test HS5T is failing:
   - Check the test input: cat yaml-test-suite/HS5T/in.yaml
   - Check test description: cat yaml-test-suite/HS5T/===
   - Run: ./zig/zig build test-yaml -- zig --verbose | grep "HS5T"

2. Study reference implementations to understand the correct behavior:
   - Check TypeScript: grep -r "HS5T" yaml-ts/tests/ || true
   - Study similar parsing logic in yaml-ts/src/
   - Check Rust implementation in yaml-rs/src/

3. Fix the issue in src/parser.zig:
   - Make targeted changes to fix ONLY this test
   - DO NOT make broad changes that could affect other tests
   - Focus on the specific validation or parsing logic needed

4. Verify your fix:
   - Run: ./zig/zig build test-yaml -- zig --verbose | grep "HS5T"
   - Ensure the test now passes
   
5. Check for regressions:
   - Run full test suite: ./zig/zig build test-yaml -- zig
   - Compare the pass rate - it should be at least 341/402 (one more than current 340)
   - If pass rate dropped, your fix caused regressions - revise it

6. Once test passes without regressions:
   - Commit your changes:
     git add -A
     git commit -m "Fix test HS5T - unknown issue resolved without regressions"
   
7. Exit after committing the successful fix

## Important Notes
- ONLY fix test HS5T - do not attempt to fix other tests
- If you cannot fix without causing regressions, document why in a comment and exit
- The current baseline is 340/402 tests passing - do not go below this
- Your fix should increase the pass rate to at least 341/402
