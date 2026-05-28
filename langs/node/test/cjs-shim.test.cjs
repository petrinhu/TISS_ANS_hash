/**
 * Sanidade do shim CJS — `require('tiss-hash')` deve expor a mesma API
 * que o ESM e produzir hashes idênticos para um vetor representativo.
 *
 * Roda com `node --test`, que detecta `.cjs` automaticamente.
 */
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join, resolve } = require('node:path');

const {
  hashTiss,
  hashTissFile,
  InvalidTissXmlError,
  TISS_NAMESPACE,
} = require('../src/index.cjs');

const conformanceDir = resolve(__dirname, '..', '..', '..', 'conformance');

test('CJS shim: hashTiss bate em vetor representativo', () => {
  const bytes = readFileSync(join(conformanceDir, 'inputs/syn_acento.xml'));
  assert.equal(hashTiss(bytes), 'a20afc9a89aadaa2179d03d225337662');
});

test('CJS shim: exports presentes', () => {
  assert.equal(typeof hashTiss, 'function');
  assert.equal(typeof hashTissFile, 'function');
  assert.equal(typeof InvalidTissXmlError, 'function');
  assert.equal(TISS_NAMESPACE, 'http://www.ans.gov.br/padroes/tiss/schemas');
});

test('CJS shim: hashTissFile retorna Promise', async () => {
  const path = join(conformanceDir, 'inputs/syn_minimal.xml');
  const h = await hashTissFile(path);
  assert.equal(h, '3aa0c578c95cdb861a125f480a8a4de5');
});
