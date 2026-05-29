# tiss-hash (Rust)

Hash MD5 do epílogo XML **TISS/ANS** (Padrão TISS: Troca de
Informações em Saúde Suplementar, ANS). Port Rust da biblioteca
[`lib_hash_ans`](https://github.com/petrinhu/TISS_ANS_hash).

Status: **alpha**. 20/20 vetores sintéticos PASS contra a referência Python (18 positivos + 2 negativos).

## Quickstart

```bash
cargo add tiss-hash
```

```rust
use tiss_hash::{hash_tiss, hash_tiss_file, TissHashError};

fn main() -> Result<(), TissHashError> {
    // A partir de bytes
    let raw = std::fs::read("envio.xml")?;
    let digest = hash_tiss(&raw)?;
    println!("{digest}"); // 32 chars hex lowercase

    // Atalho pra arquivo
    let digest = hash_tiss_file("envio.xml")?;
    assert_eq!(digest.len(), 32);
    Ok(())
}
```

## API pública

| Símbolo | Tipo | Descrição |
| --- | --- | --- |
| `hash_tiss(xml: &[u8]) -> Result<String, TissHashError>` | função | Hash MD5 (hex, 32 chars lowercase) a partir dos bytes do XML. |
| `hash_tiss_file<P: AsRef<Path>>(path: P) -> Result<String, TissHashError>` | função | Atalho que lê arquivo do disco e delega para `hash_tiss`. |
| `TissHashError` | enum | `InvalidXml(String)` para XML malformado, `Io(std::io::Error)` para falha de leitura. |
| `TISS_NAMESPACE` | const | URI do namespace TISS: `http://www.ans.gov.br/padroes/tiss/schemas`. |

`TissHashError` implementa `std::error::Error`, `Display`, `Debug` e
conversões `From<io::Error>` / `From<roxmltree::Error>`.

## Algoritmo

Resumo (spec canônica em
[`docs/SPEC.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md)):

1. Parse do XML.
2. Zera o conteúdo de `<ans:hash>` (namespace TISS).
3. Concatena o `.text` de cada **nó-folha** (elemento ou comentário sem
   filhos `Element`/`Comment`/`PI`), em ordem de documento.
4. MD5 sobre os bytes **UTF-8** da string concatenada.
5. Retorna `hexdigest()` em minúsculo (32 chars).

> **Crítico:** o encoding dos bytes que alimentam o MD5 é **UTF-8**, não
> ISO-8859-1, apesar do que diz o Componente Organizacional do TISS
> (pág 53, item 146). Ver
> [`docs/SPEC.md §4`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1).

### Decisões fixadas pela conformance

15 comportamentos canônicos documentados em
[`conformance/AMBIGUITY_NOTES.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/AMBIGUITY_NOTES.md).
Resumo do que esta crate reproduz:

- Comentários XML `<!---->` **entram** no concat (subproduto de
  `lxml.iter()` na referência; replicado aqui via
  `roxmltree::Node::is_comment()`).
- CDATA tratado como texto literal.
- Entidades XML predefinidas decodificadas pelo parser antes do concat.
- Atributos e prefixos de namespace **não** entram.
- Whitespace dentro de valor preservado literalmente.
- Indentação entre tags **não** entra (não-folhas são puladas).
- Valores numéricos com zeros à esquerda preservados como string.
- BOM UTF-8 aceito e descartado pelo parser.
- Múltiplos `<ans:hash>` no documento são **rejeitados** (erro), não tolerados.
- Encodings suportados: ISO-8859-1 e UTF-8. UTF-16/UTF-32 são **rejeitados** (fora de escopo).

### Encoding ISO-8859-1

Roxmltree exige `&str` UTF-8 (não aceita ISO-8859-1 nativamente). Esta crate
detecta a declaração `encoding="iso-8859-1"` no prólogo e converte os bytes
para UTF-8 via mapping bijetivo (byte `n` vira `U+00n`), reescrevendo a
declaração para `encoding="utf-8"` antes de passar ao parser. A semântica é
idêntica à da referência Python que delega ao `lxml`.

## Parser escolhido: `roxmltree`

Decisão: **roxmltree** (não `quick-xml`, não `xmltree`).

Justificativa registrada no topo de [`src/lib.rs`](src/lib.rs):

- roxmltree é DOM puro com API próxima de `ElementTree`/`lxml`. Iteração
  `descendants()` inclui nós `Comment` por padrão, batendo com a
  semântica da referência sem ginástica.
- quick-xml seria mais rápido (SAX), mas exige reconstruir manualmente o
  conceito de "folha" e tracking de pilha de profundidade. XMLs TISS reais
  geralmente < 5 MB; o ganho não justifica complexidade.
- xmltree é DOM básico, sem `descendants()` ergonômico.

## Conformance

Esta crate passa **20/20 vetores** sintéticos públicos em
`conformance/vectors.json`: 18 positivos (mínimo, acento, vazio, CR/LF,
multi-guia, entidades, CDATA, comentário, atributos, namespace, whitespace,
leading zeros, ISO-8859-1 símbolos, namespace default, sem hash, entidade
numérica, perf grande ~600 KB, BOM UTF-8) e 2 negativos rejeitados
(`syn_multi_hash.xml` = múltiplos `<ans:hash>`; `syn_utf16.xml` = UTF-16
fora de escopo). A lista canônica vive em `conformance/vectors.json`.

Além dos vetores sintéticos públicos, o algoritmo foi validado contra
goldens reais (privados, fora do repo, em `_private_tiss_real_xmls/`).
Esses arquivos contêm PII e não são distribuídos; rodá-los exige acesso ao
diretório privado.

### Rodar localmente

A partir da raiz do repositório:

```bash
cd langs/rust
cargo build
cargo test
cargo clippy -- -D warnings
cargo fmt --check
```

Esperado: `20/20` no teste `todos_vetores_passam`, sem warnings de clippy.

## Comparação com o port Python

| Aspecto                          | Python (`langs/python`)         | Rust (`langs/rust`)             |
| -------------------------------- | ------------------------------- | ------------------------------- |
| Parser                           | `defusedxml` (sobre stdlib)     | `roxmltree`                     |
| Decode ISO-8859-1                | feito pelo parser nativo        | conversão manual (byte vira codepoint) |
| Comentários entram no concat     | sim (`lxml`-like)               | sim (`is_comment()` + filtro)   |
| API                              | `hash_tiss`, `hash_tiss_file`   | idem (`Result<String, _>`)      |
| Erro                             | `InvalidTissXml`                | `TissHashError::InvalidXml`/`Io` |
| Vetores                          | 20/20 PASS                      | 20/20 PASS                      |
| MSRV / Python                    | Python 3.10+                    | rustc 1.75+                     |
| Dependências runtime             | `defusedxml>=0.7.1`             | `roxmltree`, `md-5`             |

## Dependências e licenças

Dependências de runtime:

| Dependência | Licença | Uso |
| --- | --- | --- |
| [`roxmltree`](https://crates.io/crates/roxmltree) | MIT OR Apache-2.0 | parser DOM |
| [`md-5`](https://crates.io/crates/md-5) (RustCrypto) | MIT OR Apache-2.0 | MD5 |

Atribuição consolidada de todos os ports em
[`THIRD_PARTY_LICENSES.md`](../../THIRD_PARTY_LICENSES.md) na raiz do repo.

## Licença

[MIT](LICENSE) (c) 2026 Petrus Silva Costa.

## Ver também

- [`docs/SPEC.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md):
  especificação canônica do algoritmo.
- [`conformance/AMBIGUITY_NOTES.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/AMBIGUITY_NOTES.md):
  15 decisões canônicas fixadas pela referência.
- [`conformance/reference.py`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/reference.py):
  implementação canônica em Python.
- [`docs/PORTING_GUIDE.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/PORTING_GUIDE.md):
  guia para portar para outras linguagens.
