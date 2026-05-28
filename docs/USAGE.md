---
title: Guia de uso do lib_hash_ans
type: how-to
audience: integrador (dev backend, fornecedor TISS, ERP hospitalar)
version: 0.1.0
last-reviewed: 2026-05-27
owner: petrinhu@yahoo.com.br
status: estável (port Python pronto; demais ports planejados)
---

# Guia de uso

Este documento mostra **como usar** as bibliotecas `lib_hash_ans` no dia-a-dia: instalação, exemplos práticos, receitas comuns, pegadinhas e perguntas frequentes. Para a especificação canônica do algoritmo, ver [`SPEC.md`](SPEC.md). Para implementar em uma linguagem nova, ver [`PORTING_GUIDE.md`](PORTING_GUIDE.md).

## 1. Visão geral por linguagem

| Linguagem | Pacote                  | Status      | Instalação                        |
|-----------|-------------------------|-------------|-----------------------------------|
| Python    | `tiss-hash`             | pronto      | `pip install tiss-hash`           |
| C         | `libtiss-hash`          | em breve    | n/a                               |
| C++       | `tiss-hash` (header)    | em breve    | n/a                               |
| Rust      | crate `tiss-hash`       | em breve    | `cargo add tiss-hash`             |
| PHP       | `petrinhu/tiss-hash`    | em breve    | `composer require ...`            |
| Node.js   | `tiss-hash`             | em breve    | `npm install tiss-hash`           |
| Outras    | ver `langs/`            | planejado   | contribuições bem-vindas          |

Todas as implementações reproduzem o mesmo hash byte-a-byte para o mesmo XML de entrada. Não há diferença de comportamento entre linguagens.

## 2. Instalação (Python)

### Requisitos

- Python **3.10** ou superior.
- Sistema operacional independente (testado em Linux; deve funcionar em macOS e Windows sem ajustes).

### Pacote padrão

```bash
pip install tiss-hash
```

Isso instala a lib com parser XML **da stdlib endurecido com `defusedxml`** (proteção contra XXE, billion-laughs). Zero dependência além de `defusedxml`.

### Extra opcional para `lxml`

Para parsing mais rápido em arquivos grandes:

```bash
pip install "tiss-hash[lxml]"
```

Reservado para uma implementação alternativa baseada em `lxml`. Atualmente o core continua usando stdlib mesmo com o extra instalado.

### Instalação a partir do checkout (dev)

```bash
git clone https://github.com/petrinhu/TISS_ANS_hash.git
cd TISS_ANS_hash/langs/python
pip install -e ".[dev]"
```

## 3. Quickstart (Python)

### Exemplo 1: Hash de bytes na memória

Caso de uso: você já tem o XML em memória (recebeu de um endpoint HTTP, leu de um banco, gerou em runtime).

```python
from tiss_hash import hash_tiss

xml_bytes = b"""<?xml version="1.0" encoding="ISO-8859-1"?>
<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">
  <ans:cabecalho><ans:identificacaoTransacao>123</ans:identificacaoTransacao></ans:cabecalho>
  <ans:epilogo><ans:hash></ans:hash></ans:epilogo>
</ans:mensagemTISS>"""

digest = hash_tiss(xml_bytes)
print(digest)   # 32 chars hex minúsculos
```

A função aceita `bytes`, `bytearray` ou `memoryview`. Não passe `str`: o algoritmo precisa controlar o decode.

### Exemplo 2: Hash de arquivo no disco

Atalho conveniente que lê e calcula:

```python
from tiss_hash import hash_tiss_file

digest = hash_tiss_file("envio.xml")
print(digest)

# Também aceita PathLike
from pathlib import Path
digest = hash_tiss_file(Path("./envios/lote_01.xml"))
```

### Exemplo 3: Tratamento de erro

XML malformado, com DOCTYPE proibido ou contendo entidades externas dispara `InvalidTissXml` (subclasse de `ValueError`):

```python
from tiss_hash import InvalidTissXml, hash_tiss

try:
    hash_tiss(b"<isto-nao-fecha>")
except InvalidTissXml as exc:
    print(f"parse falhou: {exc}")

# Também é capturável como ValueError (idiomático Python)
try:
    hash_tiss(b"<isto-nao-fecha>")
except ValueError as exc:
    print(f"input inválido: {exc}")

# Tipo errado dispara TypeError (não InvalidTissXml)
try:
    hash_tiss("string nao eh bytes")   # type: ignore
except TypeError as exc:
    print(f"tipo errado: {exc}")
```

### Exemplo 4: Validação local contra `conformance/vectors.json`

Garante que o ambiente reproduz os 15 hashes esperados:

```python
import json
from pathlib import Path
from tiss_hash import hash_tiss

CONF = Path("conformance")   # caminho relativo à raiz do checkout

manifest = json.loads((CONF / "vectors.json").read_text(encoding="utf-8"))

for vec in manifest["vectors"]:
    raw = (CONF / vec["input"]).read_bytes()
    got = hash_tiss(raw)
    status = "OK" if got == vec["expected_md5"] else "FAIL"
    print(f"{status}  {vec['id']}  {got}")
```

Saída esperada: `OK` em todas as 15 linhas.

## 4. Receitas comuns

### Receita 1: Pipeline de envio TISS

Fluxo padrão de quem gera uma mensagem TISS para enviar à operadora:

```python
from tiss_hash import hash_tiss
from lxml import etree   # você provavelmente já usa pra montar o XML

def preparar_envio(raw_xml: bytes) -> bytes:
    """Calcula o hash, preenche <ans:hash> e devolve XML pronto pra assinar."""
    digest = hash_tiss(raw_xml)

    # Reabre o XML para escrever o hash no lugar
    root = etree.fromstring(raw_xml)
    ns = {"ans": "http://www.ans.gov.br/padroes/tiss/schemas"}
    hash_el = root.find(".//ans:hash", ns)
    hash_el.text = digest

    return etree.tostring(root, xml_declaration=True, encoding="ISO-8859-1")

# Em produção:
# 1. monte o XML TISS com a sua lib preferida (lxml, xml.etree, geradores próprios)
# 2. zere <ans:hash> antes de chamar hash_tiss (a lib zera internamente, mas o
#    XML que vai pra ANS precisa ter o hash gravado, então quem grava é você)
# 3. assine com XAdES (lib externa, fora do escopo deste projeto)
# 4. envie via SOAP (também fora do escopo)
```

A lib `tiss-hash` faz apenas o passo 1 (cálculo). Os passos 2-4 são responsabilidade do integrador.

### Receita 2: Batch de múltiplos lotes

Para processar uma pasta inteira de lotes:

```python
from pathlib import Path
from tiss_hash import InvalidTissXml, hash_tiss_file

def hashear_pasta(pasta: str) -> dict[str, str]:
    """Devolve {nome_arquivo: hash_ou_erro}."""
    resultados: dict[str, str] = {}
    for xml in Path(pasta).glob("*.xml"):
        try:
            resultados[xml.name] = hash_tiss_file(xml)
        except InvalidTissXml as exc:
            resultados[xml.name] = f"ERRO: {exc}"
    return resultados

for arquivo, valor in hashear_pasta("envios_pendentes").items():
    print(f"{valor}  {arquivo}")
```

A função é **pura** (sem estado mutável). Pode rodar em pool de threads ou processos sem proteção adicional.

### Receita 3: Integração com FastAPI

Endpoint HTTP que recebe XML e devolve hash:

```python
from fastapi import FastAPI, HTTPException, Request
from tiss_hash import InvalidTissXml, hash_tiss

app = FastAPI()

@app.post("/v1/tiss/hash")
async def calcular_hash(request: Request) -> dict[str, str]:
    raw = await request.body()
    try:
        return {"hash": hash_tiss(raw)}
    except InvalidTissXml as exc:
        raise HTTPException(status_code=422, detail=str(exc))
```

Lembre-se: o XML contém PII de pacientes. Esse endpoint **não deve logar o body** e idealmente roda em rede interna apenas. Ver [`legal/LGPD-NOTE.md`](legal/LGPD-NOTE.md).

### Receita 4: Integração com Flask

```python
from flask import Flask, request, jsonify
from tiss_hash import InvalidTissXml, hash_tiss

app = Flask(__name__)

@app.post("/v1/tiss/hash")
def calcular_hash():
    try:
        return jsonify(hash=hash_tiss(request.get_data()))
    except InvalidTissXml as exc:
        return jsonify(error=str(exc)), 422
```

## 5. Pegadinhas

### 5.1 Encoding UTF-8 vs ISO-8859-1

O manual TISS diz que tudo deve ser ISO-8859-1. **Não é o caso para o cálculo do hash.** Os bytes alimentados ao MD5 são **UTF-8** mesmo que o arquivo seja lido como ISO-8859-1.

A lib trata isso internamente: você passa os bytes brutos (qualquer encoding declarado no XML), e a lib re-encoda os valores extraídos em UTF-8 antes do MD5.

**Não faça** decode manual antes de chamar:

```python
# ERRADO
texto = open("envio.xml", encoding="iso-8859-1").read()
hash_tiss(texto.encode("iso-8859-1"))   # vai dar hash diferente

# CERTO
raw = open("envio.xml", "rb").read()
hash_tiss(raw)
```

Detalhes em [`SPEC.md §4`](SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1).

### 5.2 Não normalize o XML antes de hashear

**Não rode** `xmllint --c14n`, `xmllint --format`, `etree.tostring(pretty_print=True)` ou qualquer outra normalização antes de passar para `hash_tiss`. O algoritmo já é robusto a whitespace de indentação (porque ignora `.text` de elementos não-folha), mas **é sensível** a:

- Espaços DENTRO de valores de elemento-folha (`<numeroGuia>00123 </numeroGuia>` é diferente de `<numeroGuia>00123</numeroGuia>`).
- Quebras de linha CR/LF dentro de valores.
- Adicionar/remover comentários (eles entram no concat; ver [`conformance/AMBIGUITY_NOTES.md`](../conformance/AMBIGUITY_NOTES.md) §2).

Passe os bytes que serão efetivamente enviados à ANS. Nada mais.

### 5.3 Thread safety

`hash_tiss` e `hash_tiss_file` são **puras**: sem estado mutável, sem singletons, sem cache. Podem ser chamadas em paralelo de qualquer número de threads ou processos. O parser é instanciado por chamada.

### 5.4 Não confie no hash gravado dentro do arquivo

XMLs legados frequentemente têm um valor **errado** dentro de `<ans:hash>` (gravado com encoding ISO-8859-1, gerando hash que a ANS rejeita). Sempre recalcule com esta lib antes de enviar.

## 6. API de referência (Python)

### `hash_tiss(xml: bytes) -> str`

Calcula o hash MD5 do epílogo TISS/ANS a partir dos bytes do XML.

**Argumentos:**

- `xml` (`bytes` | `bytearray` | `memoryview`): bytes do documento XML completo.

**Retorno:** string com 32 caracteres hex minúsculos (ex.: `"3aa0c578c95cdb861a125f480a8a4de5"`, do vetor sintético `syn_minimal.xml`).

**Exceções:**

- `InvalidTissXml`: XML malformado, com DOCTYPE proibido, com entidade externa, com construção tipo billion-laughs ou que não parseou.
- `TypeError`: argumento não é bytes-like.

**Exemplo:**

```python
from tiss_hash import hash_tiss

with open("envio.xml", "rb") as fh:
    digest = hash_tiss(fh.read())
```

### `hash_tiss_file(path: str | os.PathLike) -> str`

Atalho que abre o arquivo em modo binário e delega para `hash_tiss`.

**Argumentos:**

- `path`: caminho do arquivo (`str` ou `pathlib.Path`).

**Retorno:** idem `hash_tiss`.

**Exceções:**

- `InvalidTissXml`: idem `hash_tiss`.
- `OSError`: arquivo não pôde ser aberto/lido (`FileNotFoundError`, `PermissionError`, etc., são subclasses).

**Exemplo:**

```python
from pathlib import Path
from tiss_hash import hash_tiss_file

digest = hash_tiss_file(Path("envios/lote_01.xml"))
```

### `InvalidTissXml`

Exceção disparada quando o XML não pôde ser parseado ou foi rejeitado pela política de segurança do `defusedxml`. Subclasse de `ValueError`, então tanto

```python
except InvalidTissXml: ...
```

quanto

```python
except ValueError: ...
```

funcionam.

### `__version__`

Versão do pacote instalado (resolvida via metadados PEP 621). Em execução in-tree (sem `pip install`), vale `"0.0.0+unknown"`.

## 7. Como rodar a fixture localmente

```bash
git clone https://github.com/petrinhu/TISS_ANS_hash.git
cd TISS_ANS_hash/langs/python
pip install -e ".[dev]"
pytest -v
```

Saída esperada (resumida):

```
tests/test_conformance.py::test_vector_matches_expected[syn_minimal.xml] PASSED
tests/test_conformance.py::test_vector_matches_expected[syn_acento.xml] PASSED
...
tests/test_conformance.py::test_invalid_xml_raises_invalid_tiss_xml PASSED
tests/test_conformance.py::test_non_bytes_input_raises_type_error PASSED
============================== 19 passed ==============================
```

Os 19 testes cobrem: 15 vetores de conformidade + 4 testes de API auxiliares (manifest core, equivalência file/bytes, erro com XML inválido, erro com tipo errado).

## 8. Outras linguagens (em breve)

Implementação planejada nas linguagens listadas em [`README.md`](../README.md#linguagens-alvo). O contrato será idêntico:

- 1 função: bytes/arquivo → string hex 32 chars minúsculos.
- 1 exceção tipada: XML inválido.
- 0 estado mutável (pura).
- Mesmos 15 vetores de conformidade, byte-a-byte.

Quer ajudar a portar? Ver [`PORTING_GUIDE.md`](PORTING_GUIDE.md) e [`../CONTRIBUTING.md`](../CONTRIBUTING.md).

## 9. FAQ

### Por que UTF-8 e não ISO-8859-1?

Porque o algoritmo real (validado contra hashes confirmados pela ANS) usa UTF-8 nos bytes do MD5, apesar de o manual TISS dizer "ISO-8859-1". É um defeito documental do padrão. Detalhes em [`SPEC.md §4`](SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1) e [`conformance/AMBIGUITY_NOTES.md §1`](../conformance/AMBIGUITY_NOTES.md).

### Posso usar em produção?

O port Python (0.1.0) está pronto: 19 testes passando, parser endurecido contra XXE, código revisado. **Recomendação:** valide você mesmo contra alguns lotes seus que já foram aceitos pela operadora, antes de colocar em prod. A licença [MIT](../LICENSE) é explícita: sem garantias.

### E se a ANS mudar o algoritmo?

A spec em [`SPEC.md`](SPEC.md) está versionada (SemVer). Mudança incompatível no padrão TISS dispara nova major (2.0.0) com migração documentada. Versão atual cobre TISS 4.01.00.

### Por que MD5 sendo fraco criptograficamente?

Porque é o que o padrão TISS exige. MD5 aqui não é primitiva de segurança: serve como checksum de integridade do conteúdo do lote. Para autenticidade e não-repúdio, o padrão usa assinatura digital XAdES (fora do escopo desta lib). Mais em [`legal/DISCLAIMER.md`](legal/DISCLAIMER.md).

### Posso processar XML grande?

Sim. A lib carrega o XML inteiro na memória (não é streaming) e itera elementos com `root.iter()`. O vetor `syn_perf_grande.xml` (~600KB, ~1500 guias) processa em poucos milissegundos. Para arquivos na ordem de centenas de MB, o gargalo será o parser DOM; nesse caso considere paralelizar entre arquivos, não otimizar dentro de um.

### Posso passar `str` em vez de `bytes`?

Não. `hash_tiss` exige bytes-like (`bytes`, `bytearray`, `memoryview`). Se passar `str`, dispara `TypeError`. A razão é controle de encoding: o algoritmo precisa decodar o XML conforme a declaração `<?xml encoding="..."?>`, e isso só é confiável a partir dos bytes brutos.

### Tem WASM para usar no browser?

Ainda não, está no roadmap (Tier 2). Argumento LGPD: rodar o hash client-side evita que o XML transite até o servidor.

## 10. Ver também

- [`SPEC.md`](SPEC.md): especificação canônica (o quê e por quê).
- [`PORTING_GUIDE.md`](PORTING_GUIDE.md): contribuir com nova linguagem.
- [`../conformance/TEST_PLAN.md`](../conformance/TEST_PLAN.md): cobertura dos vetores.
- [`../conformance/AMBIGUITY_NOTES.md`](../conformance/AMBIGUITY_NOTES.md): decisões fixadas.
- [`legal/LGPD-NOTE.md`](legal/LGPD-NOTE.md): obrigações do integrador.
- [`legal/DISCLAIMER.md`](legal/DISCLAIMER.md): limites de responsabilidade.
