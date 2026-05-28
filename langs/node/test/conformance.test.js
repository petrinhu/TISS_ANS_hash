/**
 * Suite de conformidade do port Node — roda os vetores de
 * `conformance/vectors.json` e compara byte-a-byte com `expected_md5` da
 * referência Python (`conformance/reference.py`).
 *
 * Usa `node:test` (runner nativo) para não exigir mocha/jest/vitest.
 * Resolução de caminhos via `import.meta.url` (independe do CWD do runner).
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readFileSync } from 'node:fs';
import { readFile as readFileAsync } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

import {
  hashTiss,
  hashTissFile,
  InvalidTissXmlError,
  TISS_NAMESPACE,
} from '../src/index.js';

const here = dirname(fileURLToPath(import.meta.url));
// langs/node/test → langs/node → langs → raiz → conformance
const conformanceDir = resolve(here, '..', '..', '..', 'conformance');
const vectorsPath = join(conformanceDir, 'vectors.json');

// Carga síncrona para definir testes dinamicamente (uma chamada `test()`
// por vetor, com nome bom no relatório).
const manifestRaw = readFileSync(vectorsPath, 'utf8');
const manifest = JSON.parse(manifestRaw);

for (const vec of manifest.vectors) {
  test(`conformance ${vec.id} — ${vec.desc}`, async () => {
    const inputPath = join(conformanceDir, vec.input);
    const bytes = await readFileAsync(inputPath);
    const got = hashTiss(bytes);
    assert.equal(
      got,
      vec.expected_md5,
      `hash divergente para ${vec.id}: got=${got} expected=${vec.expected_md5}`,
    );
  });
}

test('TISS_NAMESPACE exporta a URI correta', () => {
  assert.equal(
    TISS_NAMESPACE,
    'http://www.ans.gov.br/padroes/tiss/schemas',
  );
});

test('hashTissFile bate com hashTiss(read)', async () => {
  const inputPath = join(conformanceDir, 'inputs/syn_acento.xml');
  const fromFile = await hashTissFile(inputPath);
  const fromBytes = hashTiss(await readFileAsync(inputPath));
  assert.equal(fromFile, fromBytes);
  // Hash conhecido da referência: prova UTF-8 nos bytes do MD5.
  assert.equal(fromFile, 'a20afc9a89aadaa2179d03d225337662');
});

test('hashTiss lança TypeError se input não for bytes', () => {
  assert.throws(
    () => hashTiss('string ao invés de bytes'),
    TypeError,
  );
  assert.throws(
    () => hashTiss({ foo: 'bar' }),
    TypeError,
  );
});

test('hashTiss lança InvalidTissXmlError em XML mal-formado', () => {
  const malformed = Buffer.from('<root><sem-fechar>');
  assert.throws(
    () => hashTiss(malformed),
    (err) => err instanceof InvalidTissXmlError,
  );
});

test('hashTiss aceita Uint8Array (não só Buffer)', () => {
  // Pega um XML válido pequeno e converte pra Uint8Array puro.
  const xml = `<?xml version='1.0' encoding='utf-8'?>` +
    `<ans:mensagemTISS xmlns:ans="${TISS_NAMESPACE}">` +
    `<ans:epilogo><ans:hash>LIXO</ans:hash></ans:epilogo>` +
    `</ans:mensagemTISS>`;
  const buf = Buffer.from(xml, 'utf8');
  const u8 = new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
  // Sem conteúdo de folha além do <ans:hash> zerado → MD5("") esperado.
  assert.equal(
    hashTiss(u8),
    'd41d8cd98f00b204e9800998ecf8427e',
  );
});

// Sanidade adicional: comentário XML ENTRA no concat (ambiguidade #2 da
// referência). Já coberta indiretamente pelo vetor syn_comentario.xml, mas
// vale teste explícito que documenta a intenção.
test('comentário XML contribui textContent ao concat (ambiguidade #2)', () => {
  // Documento minimalista com um único comentário antes do <ans:hash>.
  // Sem o comentário, o hash seria MD5("") = d41d8cd9...
  // Com o comentário, o hash muda — basta provar que ≠ MD5("").
  const xml = `<?xml version='1.0' encoding='utf-8'?>` +
    `<ans:mensagemTISS xmlns:ans="${TISS_NAMESPACE}">` +
    `<ans:cabecalho><!-- COMENTARIO --></ans:cabecalho>` +
    `<ans:epilogo><ans:hash></ans:hash></ans:epilogo>` +
    `</ans:mensagemTISS>`;
  const h = hashTiss(Buffer.from(xml));
  assert.notEqual(h, 'd41d8cd98f00b204e9800998ecf8427e');
});

// Suppress unused warning para `readFile` callback variant.
void readFile;
