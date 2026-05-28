/**
 * tiss-hash — port CJS espelhando `src/index.js` (ESM).
 *
 * A lógica é idêntica à versão ESM; mantemos duplicação leve (≈100 LOC)
 * em vez de dynamic import (que retornaria Promise e quebraria a API
 * síncrona de `hashTiss`). Ver `src/index.js` para a documentação
 * completa de decisões de parser, algoritmo e referências.
 *
 * Em caso de divergência entre os dois arquivos, a versão ESM é a fonte
 * canônica — atualizar este arquivo em conjunto.
 */
'use strict';

const { DOMParser } = require('@xmldom/xmldom');
const { createHash } = require('node:crypto');
const { readFile } = require('node:fs/promises');

const TISS_NAMESPACE = 'http://www.ans.gov.br/padroes/tiss/schemas';

class InvalidTissXmlError extends Error {
  constructor(message, options) {
    super(message, options);
    this.name = 'InvalidTissXmlError';
  }
}

function hashTiss(xmlBytes) {
  if (!(xmlBytes instanceof Uint8Array)) {
    throw new TypeError(
      `hashTiss espera Uint8Array/Buffer, recebeu ${typeof xmlBytes}`,
    );
  }

  const buf = Buffer.isBuffer(xmlBytes) ? xmlBytes : Buffer.from(xmlBytes);
  const xmlStr = decodeXmlBytes(buf);

  let doc;
  try {
    doc = new DOMParser({
      onError: (level, msg) => {
        if (level === 'error' || level === 'fatalError') {
          throw new InvalidTissXmlError(
            `XML inválido (${level}): ${msg}`,
          );
        }
      },
    }).parseFromString(xmlStr, 'text/xml');
  } catch (err) {
    if (err instanceof InvalidTissXmlError) throw err;
    throw new InvalidTissXmlError(
      `falha ao parsear XML: ${err instanceof Error ? err.message : String(err)}`,
      { cause: err },
    );
  }

  const root = doc.documentElement;
  if (!root) {
    throw new InvalidTissXmlError('XML não tem documentElement');
  }

  const hashNode = findFirstHash(root);

  let buffer = '';
  walkInOrder(root, (node) => {
    if (!isLeafForHash(node)) return;
    if (node === hashNode) return;
    const t = node.textContent;
    if (t) buffer += t;
  });

  return createHash('md5').update(buffer, 'utf8').digest('hex');
}

async function hashTissFile(filePath) {
  const raw = await readFile(filePath);
  return hashTiss(raw);
}

function isLeafForHash(node) {
  const nt = node.nodeType;
  if (nt !== 1 && nt !== 8) return false;
  const kids = node.childNodes;
  if (!kids) return true;
  for (let i = 0; i < kids.length; i++) {
    const cnt = kids[i].nodeType;
    if (cnt === 1 || cnt === 7 || cnt === 8) return false;
  }
  return true;
}

function findFirstHash(node) {
  if (
    node.nodeType === 1
    && node.localName === 'hash'
    && node.namespaceURI === TISS_NAMESPACE
  ) {
    return node;
  }
  const kids = node.childNodes;
  if (!kids) return null;
  for (let i = 0; i < kids.length; i++) {
    const r = findFirstHash(kids[i]);
    if (r) return r;
  }
  return null;
}

function walkInOrder(node, visit) {
  visit(node);
  const kids = node.childNodes;
  if (!kids) return;
  for (let i = 0; i < kids.length; i++) {
    walkInOrder(kids[i], visit);
  }
}

function decodeXmlBytes(buf) {
  let bytes = buf;
  if (
    bytes.length >= 3
    && bytes[0] === 0xEF
    && bytes[1] === 0xBB
    && bytes[2] === 0xBF
  ) {
    bytes = bytes.subarray(3);
  }
  const headLen = Math.min(bytes.length, 200);
  const head = bytes.subarray(0, headLen).toString('latin1').toLowerCase();
  const isIso = head.includes('encoding="iso-8859-1"')
    || head.includes("encoding='iso-8859-1'");
  if (isIso) {
    const s = bytes.toString('latin1');
    return s.replace(
      /encoding=(['"])iso-8859-1\1/i,
      'encoding=$1utf-8$1',
    );
  }
  return bytes.toString('utf8');
}

module.exports = {
  TISS_NAMESPACE,
  InvalidTissXmlError,
  hashTiss,
  hashTissFile,
};
