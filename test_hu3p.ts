import { parse } from './yaml-ts/src/public-api.ts';

const yaml = `key:
  word1 word2
  no: key`;

try {
  const doc = parse(yaml);
  console.log('Parsed successfully (unexpected):', JSON.stringify(doc, null, 2));
} catch (error: any) {
  console.log('Parse error (expected):', error.message);
}