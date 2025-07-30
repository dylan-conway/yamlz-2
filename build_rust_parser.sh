#!/bin/bash
# Build the Rust parser test binary

echo "Building Rust parser test binary..."
cd yaml-rs-test && cargo build --release
echo "Done! Binary is at yaml-rs-test/target/release/yaml-rs-test"