#!/usr/bin/env python3
import subprocess
import re

# Build first
subprocess.run(['./zig/zig', 'build'], capture_output=True)

# Run the test suite
result = subprocess.run(['./zig/zig', 'build', 'test-yaml', '--', 'zig', '--verbose'], 
                       capture_output=True, text=True)

# Find all failing tests
failing_tests = []
for line in result.stdout.split('\n'):
    if line.startswith('✗'):
        # Extract test name from lines like "✗ yaml-test-suite/UV7Q (expected success, got error)"
        match = re.match(r'✗ yaml-test-suite/([^\s]+)', line)
        if match:
            failing_tests.append(match.group(1))

# Sort and deduplicate
failing_tests = sorted(set(failing_tests))

# Write to file
with open('failing_tests.txt', 'w') as f:
    for test in failing_tests:
        f.write(test + '\n')

print(f"Found {len(failing_tests)} failing tests")
for test in failing_tests[:10]:
    print(f"  {test}")
if len(failing_tests) > 10:
    print(f"  ... and {len(failing_tests) - 10} more")