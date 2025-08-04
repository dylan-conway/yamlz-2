const YAML = require('./yaml-ts/dist/index.js');
const fs = require('fs');

const content = fs.readFileSync('./test_236b.yaml', 'utf8');
console.log('Input YAML:');
console.log(content);
console.log('\nParsing with TypeScript parser...');

try {
  const result = YAML.parse(content);
  console.log('SUCCESS - unexpected, should have been an error');
  console.log('Result:', JSON.stringify(result, null, 2));
} catch (error) {
  console.log('ERROR (expected):');
  console.log('Message:', error.message);
  console.log('Name:', error.name);
  if (error.linePos) {
    console.log('Line/Col:', error.linePos);
  }
}