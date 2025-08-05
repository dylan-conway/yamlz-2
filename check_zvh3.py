#!/usr/bin/env python3
import os
import subprocess

# Get sorted list of test directories
test_dirs = sorted([d for d in os.listdir('yaml-test-suite') 
                   if os.path.isdir(f'yaml-test-suite/{d}') 
                   and len(d) == 4 
                   and not d.startswith('.')])

# Find ZVH3's position
if 'ZVH3' in test_dirs:
    position = test_dirs.index('ZVH3') + 1
    print(f"ZVH3 is test #{position} out of {len(test_dirs)}")
    
    # Check a few tests around it
    start = max(0, position - 3)
    end = min(len(test_dirs), position + 3)
    
    print("\nTests around ZVH3:")
    for i in range(start, end):
        test = test_dirs[i]
        has_error = os.path.exists(f'yaml-test-suite/{test}/error')
        mark = " <--" if test == "ZVH3" else ""
        print(f"  {i+1}. {test}: {'expects error' if has_error else 'expects success'}{mark}")