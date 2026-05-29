# tiss-hash (Python)

Calcula o "hash" do trecho final de um documento TISS/ANS. Vamos por partes,
sem pressa:

- **XML** é um formato de arquivo de texto que organiza dados em etiquetas
  (tags) aninhadas, parecido com as caixas dentro de caixas de uma pasta de
  arquivos. O Padrão TISS é o formato XML que as operadoras de saúde e os
  consultórios usam para trocar informações de atendimento no Brasil.
- **Hash** é uma "impressão digital" do conteúdo: uma sequência curta e fixa
  de caracteres calculada a partir de um texto. Se uma única letra do texto
  mudar, o hash muda completamente. Serve para conferir que dois lados estão
  falando do mesmo documento.
- **MD5** é uma das receitas (algoritmos) que produzem esse hash. Ele sempre
  devolve 32 caracteres hexadecimais (os dígitos `0-9` e as letras `a-f`).
- **Epílogo** é a parte final do documento TISS: a etiqueta `<ans:hash>`, onde
  esse hash precisa ser gravado.

Em uma frase: você entrega os bytes de um XML TISS, esta biblioteca devolve os
32 caracteres do hash que vão dentro de `<ans:hash>`. (Um **byte** é a menor
unidade de dado que o computador manipula; um arquivo de texto é uma fila de
bytes.)

Este é o port Python da biblioteca `lib_hash_ans`. ("Port" = a mesma
biblioteca reescrita em outra linguagem de programação.) Outras linguagens
(C, C++, Rust, PHP, Node.js, etc.) seguem o mesmo contrato e os mesmos
vetores de conformidade. Para entender o problema que esta lib resolve, leia
[`docs/USAGE.md`](../../docs/USAGE.md) (guia de uso) e
[`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) (conceitos e visão geral).

## Antes de começar: instalar o Python

Python é a linguagem de programação usada neste port. Se você nunca instalou:

- Baixe e instale pelo site oficial: <https://www.python.org/downloads/>
  (precisa da versão 3.10 ou mais nova). No Windows, marque a caixa
  "Add Python to PATH" durante a instalação.
- No Linux/macOS, o Python costuma já vir instalado. Confira com:

```bash
python3 --version
```

Se aparecer algo como `Python 3.12.x`, está pronto. O comando `pip` (gerenciador
que baixa bibliotecas Python) vem junto com o Python.

## Quickstart

Uma **dependência** é uma biblioteca de terceiros que o seu código usa. O `pip`
baixa e instala dependências para você.

> Instalação via PyPI (o repositório oficial de pacotes Python) ainda não
> publicada. Por enquanto, instale a partir do checkout do repositório (isto é,
> da pasta que você baixou com `git clone`):

```bash
pip install ./langs/python
```

Quando publicada, bastará:

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

Resumo do que `hash_tiss` faz, em prosa. ("Parsear" um XML é ler o texto e
montar a árvore de etiquetas na memória; o **parser** é o componente que faz
essa leitura. **Encoding** é a tabela que traduz caracteres em bytes, por
exemplo UTF-8. **Namespace** é um prefixo que evita confusão entre etiquetas de
origens diferentes; aqui o namespace TISS identifica a etiqueta `<ans:hash>`.)

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

"Conformidade" aqui significa: provar que este port produz exatamente o mesmo
hash que a implementação oficial, em todos os casos previstos. Um **vetor de
conformidade** é um par "arquivo de entrada -> hash esperado": rodamos a lib no
arquivo e conferimos se o resultado bate. Um vetor **positivo** deve produzir
um hash; um vetor **negativo** deve ser rejeitado (a lib precisa recusar o
arquivo, em vez de inventar um hash).

Esta lib passa os **20 vetores de conformidade** em
`conformance/vectors.json`, todos sintéticos (`source: derived`): 18
positivos e 2 negativos (que devem ser rejeitados). O conjunto público de
conformidade é 100% sintético, sem qualquer XML real de paciente. Os 18
positivos cobrem: mínimo, acentuação, campos vazios, CR/LF embutido,
múltiplas guias, entidades XML, entidades numéricas, CDATA, comentário,
atributo de folha, namespace alternativo, namespace default, documento sem
`<ans:hash>`, whitespace puro, zeros à esquerda, símbolos ISO-8859-1,
performance e BOM UTF-8. Os 2 negativos (`syn_multi_hash.xml` e
`syn_utf16.xml`) cobrem rejeição de múltiplos `<ans:hash>` e de UTF-16
(fora de escopo: encodings suportados são ISO-8859-1 e UTF-8). A lista
canônica vive em `conformance/vectors.json`.

Rodar os testes localmente, a partir da raiz do repositório:

```bash
python -m pip install -e ./langs/python[dev]
pytest langs/python/tests/ -v
```

Saída esperada: `24 passed`. Desses, 20 testes são os vetores de
conformidade (um por vetor, parametrizados: 18 positivos comparam o hash,
2 negativos verificam a rejeição) e 4 são testes de API auxiliares
(`hash_tiss_file`, XML inválido, tipo de entrada errado e integridade do
manifesto).

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
- [`docs/USAGE.md`](../../docs/USAGE.md): guia de uso, receitas e perguntas
  frequentes (comece por aqui se você quer só usar a lib).
- [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md): conceitos e visão geral
  de como tudo se encaixa.
- [`docs/SPEC.md`](../../docs/SPEC.md): especificação canônica do algoritmo
  (a referência precisa, palavra por palavra).
- [`docs/PORTING_GUIDE.md`](../../docs/PORTING_GUIDE.md): guia para portar para
  outras linguagens.
- [`conformance/reference.py`](../../conformance/reference.py): implementação de
  referência (o "oráculo", isto é, a versão que define a resposta certa).
