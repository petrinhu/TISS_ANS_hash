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

  // UTF-16/UTF-32 fora de escopo: rejeitar por BOM antes do decode.
  // Ver AMBIGUITY_NOTES.md §11b (A-COV5).
  rejectUnsupportedEncoding(buf);

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

  // Múltiplos <ans:hash> = inválido (TISS tem no máximo 1).
  // Ver AMBIGUITY_NOTES.md §9 (A-COV2).
  const hashNodes = findAllHash(root);
  if (hashNodes.length > 1) {
    throw new InvalidTissXmlError(
      `múltiplos <ans:hash> no documento (encontrados ${hashNodes.length}, esperado no máximo 1)`,
    );
  }
  const hashNode = hashNodes.length === 1 ? hashNodes[0] : null;

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

function findAllHash(node) {
  const out = [];
  walkInOrder(node, (n) => {
    if (
      n.nodeType === 1
      && n.localName === 'hash'
      && n.namespaceURI === TISS_NAMESPACE
    ) {
      out.push(n);
    }
  });
  return out;
}

function rejectUnsupportedEncoding(buf) {
  // UTF-32 BOM (checar antes de UTF-16: FF FE 00 00 contém FF FE).
  if (
    buf.length >= 4
    && (
      (buf[0] === 0xFF && buf[1] === 0xFE && buf[2] === 0x00 && buf[3] === 0x00)
      || (buf[0] === 0x00 && buf[1] === 0x00 && buf[2] === 0xFE && buf[3] === 0xFF)
    )
  ) {
    throw new InvalidTissXmlError(
      'encoding UTF-32 não suportado (escopo: ISO-8859-1, UTF-8)',
    );
  }
  // UTF-16 BOM: FF FE (LE) ou FE FF (BE).
  if (
    buf.length >= 2
    && (
      (buf[0] === 0xFF && buf[1] === 0xFE)
      || (buf[0] === 0xFE && buf[1] === 0xFF)
    )
  ) {
    throw new InvalidTissXmlError(
      'encoding UTF-16 não suportado (escopo: ISO-8859-1, UTF-8)',
    );
  }
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
