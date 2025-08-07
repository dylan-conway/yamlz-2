#!/usr/bin/env python3
import subprocess
import os

# Get list of all tests
test_dir = "../../yaml-test-suite"
tests = sorted([d for d in os.listdir(test_dir) if d.isalnum() and len(d) == 4])

# Run the test runner
result = subprocess.run(
    ["./zig-out/bin/yaml-test-runner", "zig"],
    capture_output=True,
    text=True
)

# Get the test results line (first line of stderr)
test_results = result.stderr.split('\n')[0]

# Find failing tests
failing = []
for i, test_name in enumerate(tests):
    if i < len(test_results):
        if test_results[i] == 'F':
            failing.append(test_name)

print(f"Failing tests ({len(failing)}):")
print(" ".join(failing))

# Check if RXY3 is in the list
if "RXY3" in failing:
    print("\nRXY3 is STILL FAILING")
else:
    print("\nRXY3 is FIXED!")