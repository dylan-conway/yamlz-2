#!/usr/bin/env python3
import subprocess
import sys

# Run the test runner and capture output
result = subprocess.run(
    ["./zig-out/bin/yaml-test-runner", "zig"],
    capture_output=True,
    text=True
)

# Parse the output to check H7TQ status
output = result.stdout
lines = output.strip().split('\n')

# The first line should contain test results as dots and Fs
if lines:
    test_results = lines[0]
    
    # Get list of test directories in order
    import os
    test_dirs = []
    yaml_test_suite = "yaml-test-suite"
    for entry in sorted(os.listdir(yaml_test_suite)):
        if entry not in ['.git', 'tags', 'meta', 'name']:
            test_path = os.path.join(yaml_test_suite, entry)
            if os.path.isdir(test_path):
                # Check if it has in.yaml or subdirectories
                if os.path.exists(os.path.join(test_path, "in.yaml")):
                    test_dirs.append(entry)
                else:
                    # Check for subdirectories
                    for subentry in sorted(os.listdir(test_path)):
                        subpath = os.path.join(test_path, subentry)
                        if os.path.isdir(subpath) and os.path.exists(os.path.join(subpath, "in.yaml")):
                            test_dirs.append(f"{entry}/{subentry}")
    
    # Find H7TQ's position
    try:
        h7tq_index = test_dirs.index("H7TQ")
        if h7tq_index < len(test_results):
            result_char = test_results[h7tq_index]
            if result_char == '.':
                print(f"SUCCESS: H7TQ is now PASSING!")
            else:
                print(f"FAILURE: H7TQ is still FAILING")
        else:
            print(f"Could not determine H7TQ status - index out of range")
    except ValueError:
        print("H7TQ not found in test list")
    
    # Also show overall stats
    for line in lines:
        if "Passing:" in line:
            print(f"Overall: {line}")