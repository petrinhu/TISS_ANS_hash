#!/usr/bin/env node
// Harness de conformidade do port WASM (carregado no Node).
//
// Carrega o módulo WASM gerado por wasm-bindgen (pkg/node, target nodejs),
// roda os 20 vetores sintéticos de ../../conformance/vectors.json e, se
// disponíveis, os 3 goldens reais privados.
//
// Semântica dos vetores (igual aos outros ports):
//   - `expect` ausente ou "hash" => POSITIVO: hashTiss deve retornar e o hash
//     deve casar com expected_md5.
//   - `expect` === "error"       => NEGATIVO: hashTiss deve lançar exceção.
//
// PRIVACIDADE (LGPD): os goldens reais contêm PII. Este harness só imprime
// PASS/FAIL por arquivo: NUNCA o hash, NUNCA o conteúdo do XML, NUNCA a
// versão TISS ou a operadora. O bg.wasm e os bindings rodam tudo em memória.

import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { createRequire } from 'node:module';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '..', '..', '..'); // langs/wasm/test -> raiz
const conformanceDir = join(repoRoot, 'conformance');

// O binding target=nodejs é CommonJS; carrega via createRequire.
const require = createRequire(import.meta.url);
const wasmModulePath = join(__dirname, '..', 'pkg', 'node', 'tiss_hash_wasm.js');
const { hashTiss, tissNamespace } = require(wasmModulePath);

let pass = 0;
let fail = 0;
const failures = [];

function ok(msg) {
  pass += 1;
  console.log(`[OK]   ${msg}`);
}

function bad(msg) {
  fail += 1;
  failures.push(msg);
  console.log(`[FAIL] ${msg}`);
}

// --- Sanidade da API ------------------------------------------------------

const NS = 'http://www.ans.gov.br/padroes/tiss/schemas';
if (tissNamespace() === NS) {
  ok(`tissNamespace() = namespace TISS canônico`);
} else {
  bad(`tissNamespace() divergente: ${tissNamespace()}`);
}

// --- Vetores sintéticos ---------------------------------------------------

const manifest = JSON.parse(
  readFileSync(join(conformanceDir, 'vectors.json'), 'utf8'),
);

console.log(`\n== Vetores sintéticos (${manifest.vectors.length}) ==`);
for (const v of manifest.vectors) {
  const inputPath = join(conformanceDir, v.input);
  const isError = v.expect === 'error';
  let raw;
  try {
    raw = readFileSync(inputPath); // Buffer (subtype de Uint8Array)
  } catch (e) {
    bad(`${v.id} :: não foi possível ler ${v.input}: ${e.message}`);
    continue;
  }

  // hashTiss aceita Uint8Array; Buffer já é Uint8Array no Node, mas
  // normalizamos para deixar explícito o contrato (e exercitar Uint8Array).
  const bytes = new Uint8Array(raw.buffer, raw.byteOffset, raw.byteLength);

  if (isError) {
    // NEGATIVO: deve lançar.
    try {
      const got = hashTiss(bytes);
      bad(`${v.id} :: esperado erro, obteve hash (len=${got.length})`);
    } catch {
      ok(`${v.id} :: rejeitado como esperado`);
    }
    continue;
  }

  // POSITIVO: deve casar com expected_md5.
  if (typeof v.expected_md5 !== 'string') {
    bad(`${v.id} :: vetor positivo sem expected_md5 no manifesto`);
    continue;
  }
  try {
    const got = hashTiss(bytes);
    if (got === v.expected_md5) {
      ok(`${v.id} :: ${got}`);
    } else {
      bad(`${v.id} :: got=${got} expected=${v.expected_md5}`);
    }
  } catch (e) {
    bad(`${v.id} :: erro inesperado: ${e.message}`);
  }
}

// --- Goldens reais privados (PASS/FAIL apenas) ----------------------------
//
// Localização: env TISS_PRIVATE_XMLS, senão o path default ao lado do repo.
// Nunca commitados (LGPD). Se ausentes, é SKIP (não falha a suite).

const privateDir =
  process.env.TISS_PRIVATE_XMLS ||
  resolve(repoRoot, '..', '_private_tiss_real_xmls');
const expectedPath = join(privateDir, 'expected_hashes.json');

console.log('\n== Goldens reais privados (PASS/FAIL apenas; sem PII) ==');
if (!existsSync(expectedPath)) {
  console.log(
    `[SKIP] goldens privados ausentes (${privateDir}). ` +
      `Defina TISS_PRIVATE_XMLS para validar. Não afeta os vetores sintéticos.`,
  );
} else {
  const expected = JSON.parse(readFileSync(expectedPath, 'utf8'));
  let goldenPass = 0;
  let goldenTotal = 0;
  for (const [fileName, expectedHash] of Object.entries(expected)) {
    goldenTotal += 1;
    const xmlPath = join(privateDir, fileName);
    if (!existsSync(xmlPath)) {
      bad(`golden ${goldenTotal}/${Object.keys(expected).length} :: arquivo ausente`);
      continue;
    }
    try {
      const raw = readFileSync(xmlPath);
      const bytes = new Uint8Array(raw.buffer, raw.byteOffset, raw.byteLength);
      const got = hashTiss(bytes);
      // Compara em memória; NUNCA imprime got nem expectedHash.
      if (got === expectedHash) {
        goldenPass += 1;
        ok(`golden ${goldenPass}/${Object.keys(expected).length} :: PASS`);
      } else {
        bad(`golden ${goldenTotal} :: FAIL (hash divergente, não exibido)`);
      }
    } catch (e) {
      // A mensagem do core não contém PII, mas por garantia não a exibimos.
      bad(`golden ${goldenTotal} :: FAIL (exceção inesperada)`);
    }
  }
  console.log(`Goldens: ${goldenPass}/${goldenTotal} PASS`);
}

// --- Resumo ---------------------------------------------------------------

console.log(`\n==================================================`);
console.log(`Resultado: ${pass} PASS, ${fail} FAIL`);
if (fail > 0) {
  console.error('\nFalhas:');
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log('Tudo verde.');
process.exit(0);
