#!/usr/bin/env node
// Exemplo mínimo de uso do port WASM em Node.
//
// Uso:
//   node examples/node/run.mjs caminho/para/lote.xml
//
// Carrega o binding target=nodejs (CommonJS) e imprime o hash. Tudo roda
// em memória; o arquivo nunca sai da máquina.

import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const { hashTiss } = require(
  join(__dirname, '..', '..', 'pkg', 'node', 'tiss_hash_wasm.js'),
);

const path = process.argv[2];
if (!path) {
  console.error('uso: node examples/node/run.mjs <arquivo.xml>');
  process.exit(2);
}

try {
  const bytes = new Uint8Array(readFileSync(path));
  console.log(hashTiss(bytes)); // 32 chars hex lowercase
} catch (err) {
  console.error(`XML rejeitado: ${err.message}`);
  process.exit(1);
}
