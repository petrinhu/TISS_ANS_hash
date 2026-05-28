# tiss-hash (Node.js)

Hash MD5 do epílogo `<ans:hash>` em XMLs do **Padrão TISS/ANS** (Padrão
TISS 4.01.00, Troca de Informações em Saúde Suplementar, regulamentado
pela Agência Nacional de Saúde Suplementar).

Este é o port Node.js da biblioteca [`lib_hash_ans`](https://github.com/petrinhu/TISS_ANS_hash).
Outras linguagens (Python, Rust, C, C++, PHP, etc.) seguem o mesmo
contrato e os mesmos vetores de conformidade.

- **Status:** alpha. 15/15 vetores sintéticos PASS (`conformance/vectors.json`).
- **Licença:** MIT.
- **Engines:** Node.js `>=20` (testado em 20 LTS e 22 LTS).
- **Dependência runtime única:** [`@xmldom/xmldom`](https://github.com/xmldom/xmldom) (DOM puro, pure-JS, sem deps nativas).

## Instalação

```bash
npm install tiss-hash
```

> A publicação no npm registry ainda não foi feita. Por enquanto, instalar
> diretamente a partir do checkout do repositório:
>
> ```bash
> npm install /caminho/para/lib_hash_ans/langs/node
> ```

## Quickstart

### ESM (recomendado)

```js
import { hashTiss, hashTissFile } from 'tiss-hash';
import { readFileSync } from 'node:fs';

// A partir de bytes (sincrono)
const md5 = hashTiss(readFileSync('lote.xml'));
console.log(md5); // ex.: '3aa0c578c95cdb861a125f480a8a4de5'

// A partir de um caminho de arquivo (assincrono)
const md5b = await hashTissFile('lote.xml');
```

### CommonJS

```js
const { hashTiss, hashTissFile } = require('tiss-hash');
const { readFileSync } = require('node:fs');

const md5 = hashTiss(readFileSync('lote.xml'));
```

### Tratamento de erro

```js
import { hashTiss, InvalidTissXmlError } from 'tiss-hash';

try {
  hashTiss(Buffer.from('<nao-eh-xml'));
} catch (err) {
  if (err instanceof InvalidTissXmlError) {
    console.error('XML rejeitado:', err.message);
  } else {
    throw err;
  }
}
```

## API

| Símbolo | Tipo | Descrição |
| --- | --- | --- |
| `hashTiss(xmlBytes)` | `(Uint8Array \| Buffer) => string` | Hash MD5 (hex, 32 chars minúsculo) a partir dos bytes do XML. Sincrono. |
| `hashTissFile(filePath)` | `(string \| URL) => Promise<string>` | Atalho assíncrono: lê o arquivo e calcula o hash. |
| `InvalidTissXmlError` | `class extends Error` | Lançada quando o XML é mal-formado ou rejeitado pelo parser. |
| `TISS_NAMESPACE` | `string` | URI do namespace TISS: `http://www.ans.gov.br/padroes/tiss/schemas`. |

## Algoritmo

Resumo do que `hashTiss` faz:

1. Decodifica os bytes do XML respeitando a declaração `encoding="..."`:
   - `iso-8859-1` (padrão TISS): mapeia byte para codepoint (latin1) e
     reescreve a declaração para `utf-8` antes de passar ao parser.
   - `utf-8`: usa direto. Strippa BOM UTF-8 se presente.
2. Parseia o XML com [`@xmldom/xmldom`](https://github.com/xmldom/xmldom)
   (DOM W3C compliant, mantém comentários em `childNodes`).
3. Localiza o primeiro `<ans:hash>` (por **namespace URI**, não por
   prefixo) e marca-o para ser zerado.
4. Caminha a árvore em ordem de documento (depth-first, pre-order).
   Para cada **nó-folha**, isto é, `Element` ou `Comment` cujos filhos
   NÃO contêm `Element`/`Comment`/`ProcessingInstruction`, concatena
   `textContent` ao buffer. O `<ans:hash>` contribui `""`.
5. Calcula `MD5` sobre os bytes **UTF-8** da string concatenada.
6. Devolve o `hexdigest()` em minúsculo (32 caracteres).

### Atenção: encoding do MD5 é UTF-8, não ISO-8859-1

O manual TISS (Componente Organizacional nov/2025, pág 53, item 146) diz
"O encoding a ser utilizado será sempre o ISO-8859-1". **Essa frase é
ambígua** e foi historicamente mal interpretada. Refere-se ao encoding do
arquivo XML, **não** dos bytes que alimentam o MD5.

Na prática (validada contra 3 goldens reais aceitos pela ANS), os valores
extraídos do XML são re-encodados em **UTF-8** antes do MD5.
Implementações que aplicam MD5 sobre bytes ISO-8859-1 produzem hash
diferente e **errado**.

Spec completa: [`docs/SPEC.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md).
Catálogo das 15 decisões canônicas (CDATA, entidades, atributos,
comentários, etc.): [`conformance/AMBIGUITY_NOTES.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/AMBIGUITY_NOTES.md).

## Decisão de parser: `@xmldom/xmldom`

Avaliadas três opções:

| Parser | Decisão | Motivo |
| --- | --- | --- |
| **@xmldom/xmldom** | escolhido | DOM puro, pure-JS, sem deps nativas. Semântica W3C DOM próxima do `ElementTree`/`lxml` do Python. Mantém nós `Comment` (nodeType 8) em `childNodes` por padrão, essencial pra reproduzir a ambiguidade #2 da referência (comentários XML ENTRAM no concat). |
| `fast-xml-parser` | descartado | Converte XML para objeto JS, perde noção de ordem e o conceito de "elemento-folha" sem reconstrução manual. |
| `sax` / `ltx` | descartado | Streaming/SAX exigem reconstruir manualmente a árvore. Sem ganho real (XMLs TISS < 10 MB). |

## Conformidade

Esta lib passa os **15 vetores sintéticos** em
[`conformance/vectors.json`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/vectors.json),
cobrindo:

- mínimo, acentuação (UTF-8 vs ISO-8859-1), campos vazios, CR/LF,
  múltiplas guias, entidades XML, CDATA, comentários, atributos,
  namespaces variados, whitespace puro, zeros à esquerda, símbolos
  ISO-8859-1, performance (~600 KB), BOM UTF-8.

Rodar os testes localmente, a partir desta pasta:

```bash
npm install
npm test
```

Saída esperada: 15 vetores passando + asserts de API auxiliares.

## Limitações conhecidas

- **Múltiplos `<ans:hash>` no mesmo documento:** seguimos a referência,
  zerando apenas o **primeiro**. Cenário patológico, não previsto pelo
  padrão TISS.
- **Bytes inválidos no encoding declarado:** comportamento não fixado
  pela suite. O parser tipicamente substitui ou rejeita; a lib não tenta
  recuperar.

## Licença

[MIT](LICENSE) Copyright (c) 2026 Petrus Silva Costa
