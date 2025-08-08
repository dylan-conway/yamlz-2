# Test 4HVU: Wrong indentation in Sequence

## Issue
The parser is incorrectly accepting a YAML sequence with inconsistent indentation between items.

## Test Input
```yaml
key:
   - ok
   - also ok
  - wrong
```

## Problem
The sequence items have inconsistent indentation:
- Lines 2-3: Items are indented with 3 spaces (columns 3-4)
- Line 4: Item is indented with 2 spaces (columns 2-3)

This violates YAML's requirement that all items in a block sequence must have consistent indentation.

## Expected Behavior
Should reject this YAML as invalid because:
1. Block sequence items must all be at the same indentation level
2. The first item establishes the indentation at column 3
3. The third item at column 2 breaks this consistency
4. YAML spec requires uniform indentation for collection items

## Fix Strategy
Need to track and validate the indentation level established by the first item in a block sequence and ensure all subsequent items match exactly.

Check the block sequence parsing logic to add validation for consistent indentation across all items.