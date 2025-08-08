const std = @import("std");
const parser = @import("parser.zig");

// Parser backend to use
const ParserBackend = enum {
    zig,
    typescript,
    rust,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create temporary directory for test files
    const cwd = std.fs.cwd();
    cwd.makeDir(".tmp") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
    
    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2 or args.len > 3) {
        std.debug.print("Usage: {s} <parser> [--verbose]\n", .{args[0]});
        std.debug.print("  parser: zig, typescript, or rust\n", .{});
        std.debug.print("  --verbose: Show test names as they run\n", .{});
        return error.InvalidArguments;
    }
    
    const parser_backend = std.meta.stringToEnum(ParserBackend, args[1]) orelse {
        std.debug.print("Error: Invalid parser backend '{s}'\n", .{args[1]});
        std.debug.print("Valid options: zig, typescript, rust\n", .{});
        return error.InvalidParser;
    };
    
    const verbose = args.len == 3 and std.mem.eql(u8, args[2], "--verbose");
    
    // Get test suite directory
    const test_dir = try cwd.openDir("yaml-test-suite", .{ .iterate = true });
    
    var total_tests: u32 = 0;
    var passing_tests: u32 = 0;
    var failing_tests = std.ArrayList([]const u8).init(allocator);
    defer failing_tests.deinit();
    
    // Iterate through test directories
    var iter = test_dir.iterate();
    while (try iter.next()) |entry| {
        // Skip non-directories and special directories
        if (entry.kind != .directory) continue;
        if (std.mem.eql(u8, entry.name, "tags")) continue;
        if (std.mem.eql(u8, entry.name, "meta")) continue;
        if (std.mem.eql(u8, entry.name, "name")) continue;
        if (std.mem.eql(u8, entry.name, ".git")) continue;
        
        // Open test directory
        var test_case_dir = try test_dir.openDir(entry.name, .{ .iterate = true });
        defer test_case_dir.close();
        
        // Check if this has subtests or is a single test
        test_case_dir.access("in.yaml", .{}) catch {
            // No in.yaml - this has subtests
            // Multiple subtests - iterate through subdirectories
            var sub_iter = test_case_dir.iterate();
            while (try sub_iter.next()) |sub_entry| {
                if (sub_entry.kind != .directory) continue;
                
                var subtest_dir = try test_case_dir.openDir(sub_entry.name, .{});
                defer subtest_dir.close();
                
                const test_name = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ entry.name, sub_entry.name });
                defer allocator.free(test_name);
                
                try runSingleTest(allocator, test_name, &subtest_dir, parser_backend, &total_tests, &passing_tests, &failing_tests, verbose);
            }
            continue;
        };
        
        // Has in.yaml - single test case
        try runSingleTest(allocator, entry.name, &test_case_dir, parser_backend, &total_tests, &passing_tests, &failing_tests, verbose);
    }
    
    // Report results
    const percentage = @as(f32, @floatFromInt(passing_tests)) / @as(f32, @floatFromInt(total_tests)) * 100;
    if (!verbose) std.debug.print("\n", .{});
    std.debug.print("=== YAML Test Suite Results ===\n", .{});
    std.debug.print("Parser: {s}\n", .{@tagName(parser_backend)});
    std.debug.print("Total tests: {}\n", .{total_tests});
    std.debug.print("Passing: {} ({d:.1}%)\n", .{ passing_tests, percentage });
    std.debug.print("Failing: {}\n", .{total_tests - passing_tests});
    
    if (failing_tests.items.len > 0) {
        std.debug.print("\nFailing tests:\n", .{});
        for (failing_tests.items) |name| {
            std.debug.print("  - {s}\n", .{name});
        }
    }
    
    // Free failing test names
    for (failing_tests.items) |name| {
        allocator.free(name);
    }
}

fn runTypescriptParser(allocator: std.mem.Allocator, yaml_input: []const u8) !bool {
    // Write yaml input to a temp file
    const tmp_path = ".tmp/yaml_test_input.yaml";
    const cwd = std.fs.cwd();
    const tmp_file = try cwd.createFile(tmp_path, .{});
    defer tmp_file.close();
    defer cwd.deleteFile(tmp_path) catch {};
    
    try tmp_file.writeAll(yaml_input);
    
    // Use TypeScript yaml parser to test
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "bun",
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
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    
    return result.term.Exited == 0;
}

fn runRustParser(allocator: std.mem.Allocator, yaml_input: []const u8) !bool {
    // Write yaml input to a temp file
    const yaml_path = ".tmp/yaml_test_input.yaml";
    const cwd = std.fs.cwd();
    const yaml_file = try cwd.createFile(yaml_path, .{});
    defer yaml_file.close();
    defer cwd.deleteFile(yaml_path) catch {};
    try yaml_file.writeAll(yaml_input);
    
    // Run the pre-built Rust parser binary
    // Expected to be at ./yaml-rs-test/target/release/yaml-rs-test
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "./yaml-rs-test/target/release/yaml-rs-test",
            yaml_path,
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    
    return result.term.Exited == 0;
}

fn runSingleTest(
    allocator: std.mem.Allocator,
    test_name: []const u8,
    test_dir: *std.fs.Dir,
    parser_backend: ParserBackend,
    total_tests: *u32,
    passing_tests: *u32,
    failing_tests: *std.ArrayList([]const u8),
    verbose: bool,
) !void {
    // Read the YAML input
    const yaml_file = try test_dir.openFile("in.yaml", .{});
    defer yaml_file.close();
    
    const yaml_input = try yaml_file.readToEndAlloc(allocator, 1024 * 1024); // 1MB max
    defer allocator.free(yaml_input);
    
    // Check if this test is expected to fail
    const has_error_file = if (test_dir.access("error", .{})) |_| true else |_| false;
    
    // Run parser based on backend
    const parse_success = switch (parser_backend) {
        .zig => blk: {
            // Create an arena allocator for parsing
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            
            const doc = parser.parse(arena.allocator(), yaml_input) catch {
                break :blk false;
            };
            _ = doc;
            break :blk true;
        },
        .typescript => try runTypescriptParser(allocator, yaml_input),
        .rust => try runRustParser(allocator, yaml_input),
    };
    
    // Check if test passed
    const test_passed = if (has_error_file) !parse_success else parse_success;
    
    total_tests.* += 1;
    if (test_passed) {
        passing_tests.* += 1;
        if (verbose) {
            std.debug.print("✓ yaml-test-suite/{s}\n", .{test_name});
        } else {
            std.debug.print(".", .{});
        }
    } else {
        if (verbose) {
            const expected = if (has_error_file) "error" else "success";
            const got = if (parse_success) "success" else "error";
            std.debug.print("✗ yaml-test-suite/{s} (expected {s}, got {s})\n", .{ test_name, expected, got });
        } else {
            std.debug.print("F", .{});
        }
        const name_copy = try allocator.dupe(u8, test_name);
        try failing_tests.append(name_copy);
    }
}