#\!/bin/bash
./zig/zig build test-yaml -- zig --verbose 2>&1 | grep "✗" | sed 's/.*yaml-test-suite\///' | sed 's/ .*//' | sed 's/\/[0-9]*$//' | sort -u
