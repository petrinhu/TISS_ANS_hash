# tiss-hash (Python)

Hash MD5 do epílogo TISS/ANS (Padrão TISS de troca de informações em saúde
suplementar). Implementação portável, com parsing XML endurecido contra
ataques (XXE, billion-laughs).

Este é o port Python da biblioteca `lib_hash_ans`. Outras linguagens
(C, C++, Rust, PHP, Node.js, etc.) seguem o mesmo contrato e os mesmos
vetores de conformidade.

## Quickstart

> Instalação via PyPI ainda não publicada. Por enquanto, instale a partir
> do checkout do repositório:

```bash
pip install ./langs/python
```

Quando publicada:

```bash
pip install tiss-hash
```

Uso:

```python
from tiss_hash import hash_tiss, hash_tiss_file

# A partir de bytes
with open("lote_tiss_exemplo.xml", "rb") as fh:
    digest = hash_tiss(fh.read())
print(digest)  # hex MD5 de 32 chars, ex.: '3aa0c578c95cdb861a125f480a8a4de5'

# A partir de um caminho de arquivo
digest = hash_tiss_file("lote_tiss_exemplo.xml")
```

Tratamento de erro:

```python
from tiss_hash import InvalidTissXml, hash_tiss

try:
    hash_tiss(b"<nao-eh-xml")
except InvalidTissXml as exc:
    print(f"falhou ao parsear: {exc}")
```

## API

| Símbolo | Tipo | Descrição |
| --- | --- | --- |
| `hash_tiss(xml: bytes) -> str` | função | Hash MD5 (hex, 32 chars) a partir dos bytes do XML. |
| `hash_tiss_file(path: str \| os.PathLike) -> str` | função | Atalho que lê o arquivo e delega para `hash_tiss`. |
| `InvalidTissXml` | classe | Exceção (subclasse de `ValueError`) para XML malformado ou rejeitado por política de segurança. |
| `__version__` | str | Versão do pacote. |

## Algoritmo

Resumo do que `hash_tiss` faz, em prosa:

1. Parseia o XML (com `defusedxml`, isto é, sem expansão de entidades e
   sem DOCTYPE externo).
2. Zera o conteúdo de `<ans:hash>` (namespace
   `http://www.ans.gov.br/padroes/tiss/schemas`).
3. Concatena o `.text` de cada elemento-folha (sem filhos) em ordem
   documental.
4. Calcula MD5 sobre os bytes **UTF-8** da string resultante.
5. Devolve o `hexdigest()` minúsculo (32 caracteres).

Atenção: o encoding dos bytes alimentados ao MD5 é **UTF-8**, não
ISO-8859-1. O manual TISS afirma o contrário, mas o valor que bate com os
goldens reais é UTF-8.

Especificação canônica completa: `docs/SPEC.md` (na raiz do repositório).
Implementação de referência: `conformance/reference.py`.

## Conformidade

Esta lib passa os **15 vetores de conformidade** em
`conformance/vectors.json`, todos sintéticos (`source: derived`). O
conjunto público de conformidade é 100% sintético, sem qualquer XML real
de paciente. Cobrem: mínimo, acentuação, campos vazios, CR/LF embutido,
múltiplas guias, entidades XML, CDATA, comentário, atributo de folha,
namespace alternativo, whitespace puro, zeros à esquerda, símbolos
ISO-8859-1, performance e BOM UTF-8.

Rodar os testes localmente, a partir da raiz do repositório:

```bash
python -m pip install -e ./langs/python[dev]
pytest langs/python/tests/ -v
```

Saída esperada: `19 passed`. Desses, 15 testes são os vetores de
conformidade (um por vetor, parametrizados) e 4 são testes de API
auxiliares (`hash_tiss_file`, XML inválido, tipo de entrada errado e
integridade do manifesto).

## Dependências

- Runtime: `defusedxml>=0.7.1` (pure-Python, sem deps próprias). Usado
  no lugar de `xml.etree.ElementTree.parse` da stdlib para mitigar XXE
  e billion-laughs em XMLs vindos de terceiros.
- Extra `lxml`: opcional, reservado para uma implementação alternativa
  mais performática no futuro.
- Extra `dev`: `pytest`, `pytest-cov`.

## Licença

[MIT](https://github.com/petrinhu/TISS_ANS_hash/blob/main/LICENSE)
Copyright (c) 2026 Petrus Silva Costa. Licença única do projeto, na raiz
do repositório.

## Ver também

- Repositório (origin): https://github.com/petrinhu/TISS_ANS_hash
- Mirror: https://codeberg.org/petrinhu/TISS_ANS_hash
- [`docs/SPEC.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md):
  especificação canônica do algoritmo.
- [`docs/PORTING_GUIDE.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/PORTING_GUIDE.md):
  guia para portar para outras linguagens.
- [`conformance/reference.py`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/reference.py):
  implementação de referência (oráculo).
