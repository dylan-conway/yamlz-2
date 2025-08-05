#!/usr/bin/env python3
import subprocess
import os

# Get all test directories
test_dirs = sorted([d for d in os.listdir('yaml-test-suite') 
                   if os.path.isdir(f'yaml-test-suite/{d}') 
                   and len(d) == 4 
                   and not d.startswith('.')])

failing = []
for test in test_dirs:
    # Run each test individually
    result = subprocess.run(['./zig-out/bin/yamlz_2'], 
                          stdin=open(f'yaml-test-suite/{test}/in.yaml', 'rb'),
                          capture_output=True)
    
    # Check if test expects error
    expects_error = os.path.exists(f'yaml-test-suite/{test}/error')
    
    # Test fails if:
    # - Expects error but parser succeeded (returncode == 0)
    # - Expects success but parser failed (returncode != 0)
    failed = False
    if expects_error and result.returncode == 0:
        failed = True
        reason = "EXPECTS_ERROR_BUT_PASSED"
    elif not expects_error and result.returncode != 0:
        failed = True  
        reason = "EXPECTS_SUCCESS_BUT_FAILED"
    
    if failed:
        failing.append((test, reason))
        if len(failing) <= 10:
            print(f"{test}: {reason}")

print(f"\nTotal failing: {len(failing)}")
print("\nFirst 20 failing tests that expect error but pass:")
error_but_pass = [t for t, r in failing if r == "EXPECTS_ERROR_BUT_PASSED"]
for test in error_but_pass[:20]:
    print(test)