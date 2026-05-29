# AGENTS.md - guia para IA / agentes de código que USAM esta lib

> **Audience:** uma IA ou agente de código (qualquer ferramenta, qualquer modelo) que precisa
> calcular o hash MD5 do epílogo TISS/ANS dentro de um projeto. Convenção `AGENTS.md`,
> tool-agnóstica. Se você é humano, comece pelo [`README.md`](README.md) e pelo
> [`docs/USAGE.md`](docs/USAGE.md).
>
> **last-reviewed:** 2026-05-29 · **owner:** petrinhu@yahoo.com.br · **versão do projeto:** v0.2.1

## O que é

`TISS_ANS_hash` é uma biblioteca multi-linguagem que calcula o **hash MD5 do elemento
`<ans:hash>` (o "epílogo") de um documento XML do Padrão TISS/ANS** (saúde suplementar
brasileira). Entra: bytes do XML. Sai: 32 caracteres hexadecimais minúsculos. Nada mais
(não persiste, não transmite, não assina, não valida contra XSD).

- Conceito sem código: [`docs/CONCEITOS.md`](docs/CONCEITOS.md).
- Definição técnica canônica: [`docs/SPEC.md`](docs/SPEC.md).

---

## REGRA 1 (a mais importante): NÃO reimplemente o algoritmo

Se você está prestes a escrever uma função MD5 sobre um XML TISS do zero: **pare.** Use um dos
**13 ports** prontos. O algoritmo parece trivial e não é; quem reimplementa do zero erra e a ANS
**rejeita o lote**.

Ports disponíveis (todos produzem o **mesmo hash byte a byte**):

| Linguagem | Diretório | | Linguagem | Diretório |
|-----------|-----------|-|-----------|-----------|
| Python | `langs/python/` | | C# / .NET | `langs/csharp/` |
| Rust | `langs/rust/` | | Kotlin | `langs/kotlin/` |
| C | `langs/c/` | | Delphi / Object Pascal (FPC) | `langs/delphi/` |
| C++ | `langs/cpp/` | | Dart | `langs/dart/` |
| Node.js | `langs/node/` | | WASM (browser/Node) | `langs/wasm/` |
| PHP | `langs/php/` | | | |
| Java | `langs/java/` | | Go | `langs/go/` |

### Por que reimplementar dá errado (as sutilezas que quebram quem refaz)

1. **Os bytes do MD5 são UTF-8, NÃO ISO-8859-1.** O manual oficial do Padrão TISS diz
   textualmente "ISO-8859-1", mas isso se refere ao encoding do **arquivo**, não dos bytes que
   alimentam o MD5. Calcular MD5 sobre bytes ISO-8859-1 gera um hash **errado** que a ANS recusa.
   Esta é a pegadinha número um. Ver [`docs/SPEC.md §4`](docs/SPEC.md).
2. **Comentários XML (`<!-- ... -->`) entram na concatenação.** Na referência atual, um comentário
   satisfaz a condição de "folha" e contribui texto. Removê-los ou ignorá-los muda o hash.
3. **Só nós-folha contribuem.** Concatena-se apenas o `.text` de elementos **sem elementos filhos**,
   em ordem de documento, sem separador, sem nome de tag, sem atributos. Elementos com filhos não
   contribuem (a indentação fica neles e é descartada).
4. **`<ans:hash>` é casado pela URI do namespace** (`http://www.ans.gov.br/padroes/tiss/schemas`)
   **+ nome local `hash`**, NÃO pelo prefixo literal `ans:`. Funciona com namespace default
   (`xmlns=...` sem prefixo). O conteúdo de `<ans:hash>` é zerado antes do cálculo (o hash não
   entra em si mesmo).
5. **Não normalizar.** Sem `xmllint --format`, sem c14n, sem normalização Unicode (NFC/NFD), sem
   "arrumar" espaços. CR/LF e espaços dentro de um valor são preservados literalmente. Passe
   exatamente os bytes que serão enviados à ANS.

Detalhes completos em [`docs/SPEC.md`](docs/SPEC.md) e
[`conformance/AMBIGUITY_NOTES.md`](conformance/AMBIGUITY_NOTES.md).

### Se você PRECISA portar para uma linguagem nova

Não inventou? Então não existe port para a sua linguagem. Siga
[`docs/PORTING_GUIDE.md`](docs/PORTING_GUIDE.md) passo a passo e **valide contra os 20 vetores**
(18 positivos + 2 negativos) antes de confiar. Sem 20/20, o port está errado. A implementação de
referência (`conformance/reference.py`) é o oráculo durante o desenvolvimento.

---

## Como chamar (por linguagem)

**Não duplicamos os snippets aqui.** Cada linguagem tem instalação, exemplo mínimo executável,
saída esperada e tratamento de erro em [`docs/USAGE.md`](docs/USAGE.md) (uma seção por port). A API
mínima, comum a todas as linguagens, é:

- `hash_tiss(bytes_do_xml)` → string hex de 32 caracteres (nomes ajustados ao idioma: `hashTiss`,
  `HashTiss`, etc.).
- `hash_tiss_file(caminho)` → idem, lendo o arquivo.

**Regra de ouro para o agente:** sempre passe **bytes crus** lidos em modo binário. Nunca decodifique
o XML para string antes de chamar (a lib precisa controlar o encoding internamente). Em Python,
passar `str` dispara `TypeError`.

---

## Contrato de rejeição (o que a lib recusa)

Use isto para decidir o que tratar como erro vs sucesso:

| Entrada | Comportamento |
|---------|---------------|
| XML bem-formado com 1 `<ans:hash>` | hash de 32 chars |
| XML bem-formado **sem** `<ans:hash>` | **válido**: concatena tudo, sem erro |
| **Múltiplos** `<ans:hash>` | **erro** (TISS prevê exatamente um; não adivinhar qual zerar) |
| Encoding **UTF-16 / UTF-32** (por BOM) | **erro** (fora de escopo; só ISO-8859-1 e UTF-8) |
| XML malformado / bytes vazios | **erro** tipado |

Cada port expõe um tipo de erro próprio (`InvalidTissXml`, `InvalidTissXmlException`,
`TissHashError`, retorno `error` em Go, código de status em C, etc.). Veja o tratamento por
linguagem em [`docs/USAGE.md`](docs/USAGE.md). Entidade externa (XXE) é sempre bloqueada.

---

## Validação / conformidade (como confiar num port)

A **verdade** do projeto é o par:

- [`conformance/reference.py`](conformance/reference.py) - implementação de referência executável.
- [`conformance/vectors.json`](conformance/vectors.json) - manifesto com **20 vetores**: 18 positivos
  (entrada válida + hash esperado) + 2 negativos (entrada que o port deve rejeitar). 100% sintéticos.

Antes de confiar num port (ou num port que você acabou de gerar), rode os vetores. Resultado
esperado: **20/20 PASS** (os 2 negativos "passam" porque a lib os rejeita). O comando por linguagem
está na seção "Validar a lib na sua máquina" de [`docs/USAGE.md`](docs/USAGE.md). Para a referência:

```bash
cd conformance
python3 build_fixture.py     # imprime "OK: 20 vetores de conformidade (18 positivos + 2 negativos)"
```

O único hash de exemplo público é o do vetor sintético `syn_minimal.xml`:
`3aa0c578c95cdb861a125f480a8a4de5`. É dado fictício deste projeto, seguro para reproduzir.

---

## PRIVACIDADE / LGPD - leitura obrigatória para um agente

O XML TISS contém **dados pessoais sensíveis de saúde de paciente** (PII sob a LGPD, Lei
13.709/2018): nome, CPF, carteirinha, diagnóstico (CID-10), procedimentos, datas. A lib em si não
guarda nada, mas **você, agente, é o ponto de risco**. Siga estas regras sem exceção:

- **NUNCA** logar, imprimir (stdout/stderr), persistir em disco, commitar, colar em ticket/chat,
  enviar a serviço externo (telemetria, modelo remoto, observabilidade) NEM transmitir o **conteúdo
  do XML real**.
- **NUNCA** exponha o **hash resultante de um XML real.** O hash é **PII indireta**: identifica
  univocamente o lote e, por tabela, o atendimento. Trate-o com o mesmo cuidado do XML.
- **NUNCA** inclua em código, log, mensagem de commit, exemplo ou documentação gerada: hash de XML
  real, **número da versão do Padrão TISS**, nem **nome de operadora de plano de saúde**.
- O único hash que pode aparecer em código/log/exemplo é o sintético `3aa0c578c95cdb861a125f480a8a4de5`
  (de `syn_minimal.xml`). Apenas os 20 vetores sintéticos são públicos; nenhum dado real está no repo.
- A responsabilidade LGPD é do **integrador**, não da lib. Se você gera código que integra a lib,
  garanta: não logar o corpo da requisição, limpar buffers após uso, restringir acesso ao processo,
  preferir execução client-side (port **WASM**) quando o caso de uso permitir (evita o trânsito do
  dado ao servidor).

Detalhamento: [`docs/legal/LGPD-NOTE.md`](docs/legal/LGPD-NOTE.md).

---

## Links

- [`docs/USAGE.md`](docs/USAGE.md) - como instalar e chamar, por linguagem (não duplicado aqui).
- [`docs/SPEC.md`](docs/SPEC.md) - especificação canônica do algoritmo.
- [`docs/PORTING_GUIDE.md`](docs/PORTING_GUIDE.md) - como portar para linguagem nova (e passar os 20 vetores).
- [`docs/CONCEITOS.md`](docs/CONCEITOS.md) - o que é e para que serve, sem código.
- [`docs/legal/LGPD-NOTE.md`](docs/legal/LGPD-NOTE.md) - obrigações de privacidade do integrador.
- [`conformance/vectors.json`](conformance/vectors.json) - os 20 vetores de conformidade.

---

## TL;DR (English summary)

`TISS_ANS_hash` computes the MD5 hash of the `<ans:hash>` epilogue element in Brazilian TISS/ANS
healthcare XML. **Do not reimplement it** - use one of the 13 ready ports
(Python/Rust/C/C++/Node/PHP/Java/Go/C#/Kotlin/Delphi-FPC/Dart/WASM); subtle rules break naive
rewrites (MD5 bytes are **UTF-8, not ISO-8859-1**; XML comments are included; only leaf nodes
contribute; `<ans:hash>` is matched by namespace URI, not prefix). Call `hash_tiss(bytes)` - see
[`docs/USAGE.md`](docs/USAGE.md). Rejection contract: multiple `<ans:hash>` → error; UTF-16/UTF-32 →
error; missing `<ans:hash>` is valid. Trust a port only after it passes the 20 conformance vectors
([`conformance/vectors.json`](conformance/vectors.json)). **LGPD/privacy:** TISS XML carries patient
PII; never log, print, persist, commit or transmit the XML content OR the resulting hash of real data
(the hash is indirect PII). Only synthetic vectors are public.
