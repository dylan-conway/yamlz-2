const fs = require('fs');
const path = require('path');
const yaml = require('./yaml-ts/dist/index.js');

// Read input from stdin or file
const input = fs.readFileSync(0, 'utf8'); // 0 = stdin

try {
  const doc = yaml.parseDocument(input);
  if (doc.errors && doc.errors.length > 0) {
    process.exit(1);
  }
  process.exit(0);
} catch (e) {
  process.exit(1);
}