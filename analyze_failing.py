#!/usr/bin/env python3

# Manual list from test output
failing_tests = [
    ("UV7Q", "expected success, got error"),
    ("8XDJ", "expected error, got success"),
    ("4JVG", "expected error, got success"),
    ("JKF3", "expected error, got success"),
    ("BF9H", "expected error, got success"),
    ("GT5M", "expected error, got success"),
    ("DK95/01", "expected error, got success"),
    ("236B", "expected error, got success"),
    ("RHX7", "expected error, got success"),
    ("G9HC", "expected error, got success"),
    ("YJV2", "expected error, got success"),
    ("BD7L", "expected error, got success"),
    ("N4JP", "expected error, got success"),
    ("H7TQ", "expected error, got success"),
    ("9C9N", "expected error, got success"),
    ("5LLU", "expected error, got success"),
    ("5TRB", "expected error, got success"),
    ("ZXT5", "expected error, got success"),
    ("2G84/00", "expected error, got success"),
    ("M6YH", "expected success, got error"),
    ("TD5N", "expected error, got success"),
    ("J3BT", "expected success, got error"),
    ("SF5V", "expected error, got success"),
    ("7MNF", "expected error, got success"),
    ("KS4U", "expected error, got success"),
    ("DMG6", "expected error, got success"),
    ("QLJ7", "expected error, got success"),
    ("SU74", "expected error, got success"),
    ("9CWY", "expected error, got success"),
    ("U44R", "expected error, got success"),
    ("HS5T", "expected success, got error"),
    ("9MQT/01", "expected error, got success"),
    ("4HVU", "expected error, got success"),
    ("GDY7", "expected error, got success"),
    ("B63P", "expected error, got success"),
    ("RXY3", "expected error, got success"),
    ("S98Z", "expected error, got success"),
    ("P2EQ", "expected error, got success"),
    ("LHL4", "expected error, got success"),
    ("62EZ", "expected error, got success"),
    ("3HFZ", "expected error, got success"),
    ("3GZX", "expected success, got error"),
    ("MUS6/00", "expected error, got success"),
    ("MUS6/01", "expected error, got success"),
    ("6S55", "expected error, got success"),
    ("E76Z", "expected success, got error"),
    ("EB22", "expected error, got success"),
    ("6CA3", "expected success, got error"),
    ("VJP3/01", "expected success, got error"),
    ("W9L4", "expected error, got success"),
    ("U99R", "expected error, got success"),
    ("Q4CL", "expected error, got success"),
    ("BS4K", "expected error, got success"),
    ("JY7Z", "expected error, got success"),
    ("C2SP", "expected error, got success"),
    ("9MMA", "expected error, got success"),
    ("D49Q", "expected error, got success"),
    ("FH7J", "expected success, got error"),
    ("5U3A", "expected error, got success"),
    ("SR86", "expected error, got success"),
    ("ZF4X", "expected success, got error"),
    ("DC7X", "expected success, got error"),
    ("CXX2", "expected error, got success"),
    ("2SXE", "expected success, got error"),
    ("DK4H", "expected error, got success"),
    ("7LBH", "expected error, got success"),
    ("9HCY", "expected error, got success"),
    ("UT92", "expected success, got error"),
    ("G5U8", "expected error, got success"),
    ("SY6V", "expected error, got success"),
    ("ZCZ6", "expected error, got success"),
    ("6M2F", "expected success, got error"),
]

too_permissive = [test for test, error in failing_tests if "expected error, got success" in error]
too_restrictive = [test for test, error in failing_tests if "expected success, got error" in error]

print(f"=== FAILURE ANALYSIS ===")
print(f"Total failing tests: {len(failing_tests)}")
print(f"Too permissive (expected error, got success): {len(too_permissive)}")
print(f"Too restrictive (expected success, got error): {len(too_restrictive)}")
print()
print("=== TOO PERMISSIVE TESTS (should error but don't) ===")
for test in too_permissive[:20]:  # First 20
    print(test)
if len(too_permissive) > 20:
    print(f"... and {len(too_permissive) - 20} more")

print()
print("=== TOO RESTRICTIVE TESTS (should pass but error) ===")
for test in too_restrictive:
    print(test)