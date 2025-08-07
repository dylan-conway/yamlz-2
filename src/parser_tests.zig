const std = @import("std");
const parser = @import("parser.zig");
const testing = std.testing;

// Helper function to test with TypeScript parser
fn testTypescriptParser(yaml_input: []const u8) !bool {
    const allocator = testing.allocator;

    // Create .tmp directory if it doesn't exist
    const cwd = std.fs.cwd();
    cwd.makeDir(".tmp") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Write yaml input to a temp file
    const tmp_path = ".tmp/test_input.yaml";
    const tmp_file = try cwd.createFile(tmp_path, .{});
    defer tmp_file.close();
    defer cwd.deleteFile(tmp_path) catch {};

    try tmp_file.writeAll(yaml_input);

    // Use TypeScript yaml parser to test
    // Use node in CI, bun locally (faster)
    const ci_env = std.process.getEnvVarOwned(allocator, "CI") catch null;
    defer if (ci_env) |v| allocator.free(v);
    const js_runtime = if (ci_env != null) "node" else "bun";
    
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            js_runtime,
            "-e",
            \\const fs = require('fs');
            \\const yaml = require('./yaml-ts/dist/index.js');
            \\const input = fs.readFileSync(process.argv[1], 'utf8');
            \\try {
            \\  const docs = yaml.parseAllDocuments(input);
            \\  let errors = [];
            \\  for (const doc of docs) errors = errors.concat(doc.errors);
            \\  if (errors.length > 0) {
            \\    process.exit(1);
            \\  }
            \\  process.exit(0);
            \\} catch (e) {
            \\  process.exit(1);
            \\}
            ,
            tmp_path,
        },
    }) catch |err| {
        // If the external parser isn't available, skip validation
        std.debug.print("\n  Warning: TypeScript parser not available ({})\n", .{err});
        return true; // Return a neutral result
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return result.term.Exited == 0;
}

// Helper function to test with Rust parser
fn testRustParser(yaml_input: []const u8) !bool {
    const allocator = testing.allocator;

    // Create .tmp directory if it doesn't exist
    const cwd = std.fs.cwd();
    cwd.makeDir(".tmp") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Write yaml input to a temp file
    const yaml_path = ".tmp/test_input_rust.yaml";
    const yaml_file = try cwd.createFile(yaml_path, .{});
    defer yaml_file.close();
    defer cwd.deleteFile(yaml_path) catch {};
    try yaml_file.writeAll(yaml_input);

    // Run the pre-built Rust parser binary
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "./yaml-rs-test/target/release/yaml-rs-test",
            yaml_path,
        },
    }) catch |err| {
        // If the external parser isn't available, skip validation
        std.debug.print("\n  Warning: Rust parser not available ({})\n", .{err});
        return true; // Return a neutral result
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return result.term.Exited == 0;
}

// Helper to validate a test case across all parsers
fn validateWithAllParsers(input: []const u8, should_fail: bool) !void {
    // Test with Zig parser
    const zig_result = if (parser.parse(input)) |_| true else |_| false;

    // Test with TypeScript parser
    const ts_result = try testTypescriptParser(input);

    // Test with Rust parser
    const rust_result = try testRustParser(input);

    const expected = !should_fail;

    // Log if other parsers disagree (but don't fail the test)
    if (ts_result != expected) {
        std.debug.print("\n  Note: TypeScript parser disagrees (got {}, expected {})\n", .{ ts_result, expected });
    }

    if (rust_result != expected) {
        std.debug.print("\n  Note: Rust parser disagrees (got {}, expected {})\n", .{ rust_result, expected });
    }

    // Zig parser must match expected
    try testing.expectEqual(expected, zig_result);
}

// Basic scalar tests
test "parser: simple scalar value" {
    try validateWithAllParsers("hello", false);
}

test "parser: double-quoted scalar" {
    try validateWithAllParsers("\"hello world\"", false);
}

test "parser: single-quoted scalar" {
    try validateWithAllParsers("'hello world'", false);
}

// Basic mapping tests
test "parser: simple key-value mapping" {
    try validateWithAllParsers("key: value", false);
}

test "parser: nested mapping" {
    try validateWithAllParsers("parent:\n  child: value", false);
}

// Intentionally failing test to verify CI reporting
test "parser: intentionally failing test for CI verification" {
    // This should fail - we're expecting it to reject but it will accept
    try validateWithAllParsers("valid: yaml", true);
}
