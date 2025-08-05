#!/bin/bash
./zig/zig build test-yaml -- zig --verbose 2>/dev/null | grep "✗" | awk '{print $2}' | sed 's/yaml-test-suite\///' | sed 's/ .*//' | sort | uniq