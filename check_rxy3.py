#!/usr/bin/env python3
import subprocess
import sys

# Run the test runner
result = subprocess.run(
    ["./zig-out/bin/yaml-test-runner", "zig"],
    capture_output=True,
    text=True
)

# Parse the output to find failing tests
lines = result.stderr.strip().split('\n')
test_results = lines[0] if lines else ""

# Count the F's (failures) up to test RXY3
# The tests are run in alphabetical order
all_tests = sorted([
    "001", "002", "003", "004", "005", "006", "007", "008", "009", "00A",
    # ... many more tests ...
    "RXY3", "S3PD", "S4JQ", "S98Z", "SF5V"  # RXY3 and some tests around it
])

# Find RXY3 position
test_names = []
with open("../../yaml-test-suite/tests.txt", "r") as f:
    test_names = [line.strip() for line in f if line.strip()]
    
if "RXY3" in test_names:
    idx = test_names.index("RXY3")
    if idx < len(test_results):
        result_char = test_results[idx]
        if result_char == '.':
            print("RXY3: PASS")
        elif result_char == 'F':
            print("RXY3: FAIL")
        else:
            print(f"RXY3: Unknown ({result_char})")
    else:
        print(f"RXY3: Not found (index {idx} out of range)")
else:
    print("RXY3 not found in test list")

# Also check overall stats
for line in lines:
    if "Passing:" in line:
        print(line)