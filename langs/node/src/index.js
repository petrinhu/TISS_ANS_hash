/**
 * tiss-hash — Hash MD5 do epílogo `<ans:hash>` em XMLs do **Padrão TISS/ANS**
 * (Padrão TISS 4.01.00 — Troca de Informações em Saúde Suplementar,
 * regulamentado pela Agência Nacional de Saúde Suplementar).
 *
 * Spec canônica: `docs/SPEC.md` no repositório principal
 *   https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md
 * Implementação de referência: `conformance/reference.py` (Python + lxml).
 * Este port **bate byte-a-byte** com a referência nos 15 vetores de
 * conformidade em `conformance/vectors.json`.
 *
 * ## Decisão de parser: @xmldom/xmldom
 *
 * Avaliadas três opções:
 *
 * - **@xmldom/xmldom** (escolhida) — DOM puro, pure-JS, sem deps nativas;
 *   semântica W3C DOM próxima do `ElementTree`/`lxml` do Python. Mantém
 *   nós `Comment` (nodeType 8) em `childNodes` por padrão, o que é
 *   essencial pra reproduzir a ambiguidade #2 da referência (comentários
 *   XML ENTRAM no concat — ver `conformance/AMBIGUITY_NOTES.md`).
 * - **fast-xml-parser** — converte XML para objeto JS; perde ordem natural
 *   e o conceito de "elemento-folha" sem reconstrução manual. Descartado.
 * - **sax / ltx** — streaming/SAX, exige reconstruir manualmente a árvore
 *   e a noção de folha. Sem ganho real (XMLs TISS < 10 MB). Descartado.
 *
 * ## Algoritmo (resumo)
 *
 * 1. Parse do XML.
 * 2. Zerar o conteúdo de `<ans:hash>` (substituir por string vazia).
 * 3. Concatenar o `textContent` de cada **nó-folha** (Element ou Comment
 *    cujos filhos NÃO contêm Element/Comment/PI), em ordem de documento.
 * 4. MD5 dos bytes **UTF-8** da string concatenada (não ISO-8859-1, apesar
 *    do manual TISS dizer o contrário — ver caveat na seção 4 do SPEC).
 * 5. Hex lowercase, 32 caracteres.
 *
 * @module tiss-hash
 */

import { DOMParser } from '@xmldom/xmldom';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';

/**
 * Namespace XML do Padrão TISS/ANS. Usado para localizar `<ans:hash>`.
 *
 * O prefixo convencional é `ans:`, mas o que conta é a **URI**: qualquer
 * prefixo serve, desde que mapeie pra esta URI.
 *
 * @type {string}
 */
export const TISS_NAMESPACE = 'http://www.ans.gov.br/padroes/tiss/schemas';

/**
 * Erro lançado quando o XML é inválido ou rejeitado pelo parser.
 *
 * Subclasse de `Error` com `name === 'InvalidTissXmlError'` para
 * facilitar discriminação via `instanceof` ou `err.name`.
 */
export class InvalidTissXmlError extends Error {
  /**
   * @param {string} message Mensagem descritiva.
   * @param {{ cause?: unknown }} [options] Encadeamento de causa.
   */
  constructor(message, options) {
    super(message, options);
    this.name = 'InvalidTissXmlError';
  }
}

/**
 * Calcula o hash MD5 canônico do epílogo TISS/ANS a partir dos bytes do XML.
 *
 * Retorna uma string hex de **32 caracteres minúsculos** (lowercase).
 *
 * Aceita arquivos declarados como `encoding="iso-8859-1"` (padrão TISS) ou
 * `encoding="utf-8"`, com ou sem BOM UTF-8 no início.
 *
 * @param {Uint8Array | Buffer} xmlBytes Bytes do documento XML completo.
 * @returns {string} Hash MD5 em hex minúsculo (32 chars).
 * @throws {TypeError} Se `xmlBytes` não for Uint8Array/Buffer.
 * @throws {InvalidTissXmlError} Se o parser rejeitar a entrada.
 *
 * @example
 * import { hashTiss } from 'tiss-hash';
 * import { readFileSync } from 'node:fs';
 * const md5 = hashTiss(readFileSync('lote.xml'));
 */
export function hashTiss(xmlBytes) {
  if (!(xmlBytes instanceof Uint8Array)) {
    throw new TypeError(
      `hashTiss espera Uint8Array/Buffer, recebeu ${typeof xmlBytes}`,
    );
  }

  // Buffer estende Uint8Array, então a conversão é barata e segura.
  const buf = Buffer.isBuffer(xmlBytes) ? xmlBytes : Buffer.from(xmlBytes);
  const xmlStr = decodeXmlBytes(buf);

  let doc;
  try {
    doc = new DOMParser({
      // API nova do @xmldom/xmldom 0.9+: callback única `onError`.
      // Convertemos error/fatalError em throw para falhar fast.
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

  // Concat dos textos de folhas em ordem de documento, zerando <ans:hash>.
  let buffer = '';
  walkInOrder(root, (node) => {
    if (!isLeafForHash(node)) return;
    if (node === hashNode) {
      // Zerar conteúdo: equivale a concatenar "".
      return;
    }
    // Em uma folha (Element ou Comment), `textContent` devolve:
    //  - Element: concat dos filhos Text/CDATA (sem filhos Element/Comment).
    //  - Comment: o conteúdo entre `<!--` e `-->`.
    // Ambos coincidem com o `.text` do lxml para folhas.
    const t = node.textContent;
    if (t) buffer += t;
  });

  return createHash('md5').update(buffer, 'utf8').digest('hex');
}

/**
 * Atalho conveniente: lê o arquivo do disco e calcula {@link hashTiss}.
 *
 * @param {string | URL} filePath Caminho do arquivo XML.
 * @returns {Promise<string>} Hash MD5 em hex minúsculo (32 chars).
 * @throws {InvalidTissXmlError} Se o XML for inválido.
 *
 * @example
 * import { hashTissFile } from 'tiss-hash';
 * const md5 = await hashTissFile('lote.xml');
 */
export async function hashTissFile(filePath) {
  const raw = await readFile(filePath);
  return hashTiss(raw);
}

// ---------------------------------------------------------------------------
// Internos
// ---------------------------------------------------------------------------

/**
 * Decide se um nó é "folha pro hash":
 *  - aceita Element (nodeType 1) e Comment (nodeType 8);
 *  - "sem filhos" no sentido da referência `lxml`: sem filhos
 *    Element/Comment/PI. Filhos Text/CDATA NÃO contam (TISS não tem
 *    conteúdo misto, então um elemento com só Text dentro é folha de valor).
 *
 * @param {Node} node
 * @returns {boolean}
 */
function isLeafForHash(node) {
  const nt = node.nodeType;
  if (nt !== 1 && nt !== 8) return false;
  const kids = node.childNodes;
  if (!kids) return true;
  for (let i = 0; i < kids.length; i++) {
    const cnt = kids[i].nodeType;
    // 1 = ELEMENT, 7 = PROCESSING_INSTRUCTION, 8 = COMMENT
    if (cnt === 1 || cnt === 7 || cnt === 8) return false;
  }
  return true;
}

/**
 * Localiza o primeiro `<ans:hash>` (qualquer prefixo, namespace TISS) em
 * busca depth-first/document-order.
 *
 * @param {Node} node Raiz a partir da qual buscar.
 * @returns {Node | null}
 */
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

/**
 * Walker recursivo em ordem de documento (depth-first, pre-order).
 *
 * @param {Node} node
 * @param {(n: Node) => void} visit
 */
function walkInOrder(node, visit) {
  visit(node);
  const kids = node.childNodes;
  if (!kids) return;
  for (let i = 0; i < kids.length; i++) {
    walkInOrder(kids[i], visit);
  }
}

/**
 * Decodifica bytes do XML para `string` UTF-8 que pode ser passada ao
 * `@xmldom/xmldom` (que assume UTF-8).
 *
 * Estratégia:
 *  1. Strippa BOM UTF-8 (`EF BB BF`) se presente.
 *  2. Inspeciona ~200 bytes ASCII do prólogo procurando declaração
 *     `encoding="iso-8859-1"` (case-insensitive, aspas simples ou duplas).
 *  3. Se ISO-8859-1: usa `Buffer.toString('latin1')` (cada byte 0x00..0xFF
 *     vira o codepoint Unicode correspondente — ISO-8859-1 é subset de
 *     Unicode no range baixo, mapping bijetivo). Reescreve a declaração
 *     `encoding=` para `utf-8` para o parser não rejeitar.
 *  4. Caso contrário: assume UTF-8.
 *
 * @param {Buffer} buf
 * @returns {string}
 */
function decodeXmlBytes(buf) {
  // Strip BOM UTF-8
  let bytes = buf;
  if (
    bytes.length >= 3
    && bytes[0] === 0xEF
    && bytes[1] === 0xBB
    && bytes[2] === 0xBF
  ) {
    bytes = bytes.subarray(3);
  }

  // Detecta declaração de encoding no prólogo (primeiros bytes em ASCII).
  const headLen = Math.min(bytes.length, 200);
  const head = bytes.subarray(0, headLen).toString('latin1').toLowerCase();
  const isIso = head.includes('encoding="iso-8859-1"')
    || head.includes("encoding='iso-8859-1'");

  if (isIso) {
    // Latin1 → string: cada byte vira codepoint correspondente.
    const s = bytes.toString('latin1');
    // Reescreve a declaração pra UTF-8 (conteúdo agora é UTF-8 válido).
    return s.replace(
      /encoding=(['"])iso-8859-1\1/i,
      'encoding=$1utf-8$1',
    );
  }
  // Assume UTF-8 (ou ASCII puro, que é subset).
  return bytes.toString('utf8');
}
