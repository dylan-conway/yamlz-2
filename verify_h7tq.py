#!/usr/bin/env python3
import subprocess

# Get list of failing tests
result = subprocess.run(
    ["./get_failing_tests.sh"],
    capture_output=True,
    text=True,
    shell=True
)

failing_tests = result.stdout.strip().split()

if "H7TQ" in failing_tests:
    print("FAILURE: H7TQ is still in the failing tests list")
    print(f"Total failing tests: {len(failing_tests)}")
else:
    print("SUCCESS: H7TQ is not in the failing tests list anymore!")
    print(f"Total failing tests: {len(failing_tests)}")
    
print("\nFailing tests:", " ".join(failing_tests))