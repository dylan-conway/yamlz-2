#!/usr/bin/env python3

import re

# Read the file
with open('src/parser.zig', 'r') as f:
    content = f.read()

# Make the changes
# 1. Change function signature
content = content.replace(
    'fn skipDocumentSeparator(self: *Parser) void {',
    'fn skipDocumentSeparator(self: *Parser) ParseError!void {'
)

# 2. Change the else clause to return error
content = content.replace(
    '                } else {\n                    break;\n                }',
    '                } else {\n                    // Invalid content after document marker on the same line\n                    return error.InvalidDocumentStructure;\n                }'
)

# 3. Update function calls to handle error
content = content.replace(
    'self.skipDocumentSeparator();',
    'try self.skipDocumentSeparator();'
)

# Write the file back
with open('src/parser.zig', 'w') as f:
    f.write(content)

print("Changes applied successfully")