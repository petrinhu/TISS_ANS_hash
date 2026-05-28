---
title: Como portar lib_hash_ans para uma nova linguagem
type: how-to
audience: dev que vai implementar um port
last-reviewed: 2026-05-27
owner: petrinhu@yahoo.com.br
---

# Como portar `lib_hash_ans` para uma nova linguagem

Guia prático para implementar a lib em uma linguagem ainda não suportada. Antes de começar, leia [`SPEC.md`](SPEC.md) inteiro. Este guia assume que você já entendeu o algoritmo e quer escrever código.

## Quando usar este guia

- Você quer adicionar suporte a uma linguagem listada no README (ou propor uma nova).
- Você já tem a linguagem instalada e conhece o ecossistema de parser XML dela.
- Você tem `python3` + `lxml` disponíveis para rodar a referência localmente.

## Pré-requisitos

- Repositório clonado: `git clone <url> && cd lib_hash_ans`.
- Python 3.10+ com `lxml` (`pip install lxml`).
- Confirmar que a referência roda:
  ```bash
  cd conformance
  python3 build_fixture.py
  ```
  Deve imprimir `OK: 8 vetores`. Se não imprimir, **pare e abra issue** antes de portar.

## Passo 1: criar o esqueleto do port

Convenção de diretório: `ports/<linguagem>/`.

Layout mínimo sugerido (adaptar à idiomática da linguagem):
```
ports/<linguagem>/
├── README.md                  # quickstart específico
├── src/                       # ou equivalente
├── tests/
│   └── conformance_test.<ext> # roda os 8 vetores
└── <manifest de build>        # Cargo.toml, package.json, composer.json, CMakeLists.txt, etc.
```

## Passo 2: definir a API pública

API mínima esperada, adaptada ao idioma da linguagem (camelCase em Java/JS, snake_case em Rust/Python, PascalCase em C#).

| Função                     | Entrada         | Saída                      |
|----------------------------|-----------------|----------------------------|
| `hash_tiss(bytes)`         | bytes do XML    | string hex 32 chars (lower)|
| `hash_tiss_file(path)`     | caminho arquivo | string hex 32 chars (lower)|

Versões equivalentes por linguagem (exemplos):

- C: `int hash_tiss(const uint8_t *data, size_t len, char out[33])` (retorno = código de erro, `out` recebe `\0`-terminado).
- C++: `std::string hash_tiss(std::span<const std::byte>)`.
- Rust: `pub fn hash_tiss(raw: &[u8]) -> Result<String, HashTissError>`.
- Java: `static String hashTiss(byte[] raw) throws HashTissException`.
- C#: `public static string HashTiss(ReadOnlySpan<byte> raw)`.
- JS/TS: `export function hashTiss(raw: Uint8Array): string`.
- PHP: `function hash_tiss(string $raw): string`.
- Go: `func HashTiss(raw []byte) (string, error)`.

Erros esperados:
- XML mal-formado → erro tipado, mensagem clara.
- Bytes vazios → erro tipado (não retornar hash de string vazia).
- Entidade externa detectada → erro de segurança (XXE bloqueado).

## Passo 3: implementar o algoritmo

Pseudo-código fiel à referência:

```
function hash_tiss(raw: bytes) -> string:
    # 1. parse
    doc = xml_parse(raw)
        # XXE OFF: desabilitar resolução de entidades externas
        # DTD: pode aceitar, mas não validar
    root = doc.root_element

    # 2. zerar <ans:hash>
    NS = "http://www.ans.gov.br/padroes/tiss/schemas"
    hash_el = find_first(root, NS, "hash")
    if hash_el != null:
        set_text(hash_el, "")

    # 3. concat folhas em ordem de documento
    buffer = StringBuilder()
    for el in iter_descendants_in_document_order(root, include_root=true):
        if count_child_elements(el) == 0:
            buffer.append(text_of(el) or "")
        # else: pular (so contribui via filhos)

    # 4. MD5 dos bytes UTF-8
    md5_bytes = md5(utf8_encode(buffer.to_string()))

    # 5. hexdigest minusculo
    return hex_lower(md5_bytes)
```

Notas obrigatórias:
- **Encoding do MD5 é UTF-8.** Não use o encoding declarado no XML aqui. Ver [SPEC §4](SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1).
- **Folha = sem elementos filhos.** Comentários e nós de texto não contam como filhos. Ver [SPEC §5](SPEC.md#5-definição-de-elemento-folha).
- **Ordem de documento.** Visita pre-order DFS (raiz, depois cada filho da esquerda para a direita, recursivamente).
- **`hash_el.text = ""`** antes de iterar. Não delete o elemento, não remova do pai. Apenas esvazie o texto, para que continue sendo uma folha de texto vazio.

## Passo 4: rodar os vetores de conformidade

O contrato é simples: ler `conformance/vectors.json`, para cada vetor abrir `conformance/inputs/<file>`, calcular o hash, comparar com `expected_md5`.

Esqueleto de teste (pseudo-código):

```
vectors = json_load("conformance/vectors.json")
fails = []
for v in vectors.vectors:
    raw = read_bytes("conformance/" + v.input)
    got = hash_tiss(raw)
    if got != v.expected_md5:
        fails.append((v.id, v.expected_md5, got))

assert fails.empty(), "vetores falhando: " + format(fails)
```

Roda no CI do port. **Sem flexibilidade: 8/8 ou nada.**

## Passo 5: pegadinhas comuns por categoria de parser

### Parser DOM (lxml, ElementTree, DOM4J, System.Xml, libxml2, JDOM)

- Cuidado com auto-normalização de espaços (`remove_blank_text` no lxml). A referência não usa, e o algoritmo é robusto a isso porque não-folhas são puladas. Mas se seu DOM **mutila** `.text` em folhas, vai falhar. Teste com `syn_crlf_value.xml`.
- `iter()` / `descendants()` deve incluir o elemento raiz. Em libxml2, `xmlDocGetRootElement` + walk manual.
- API para "contar filhos elemento" varia: `len(el)` (lxml conta apenas elementos), `childNodes.length` (DOM conta inclusive texto, **errado** para nosso teste). Use o equivalente de `childElementCount`.

### Parser SAX / event-based (Expat, Xerces SAX, sax-js)

- Mantenha um contador de profundidade e um buffer de texto **por elemento aberto**.
- Quando recebe `endElement`, se o elemento atual nunca teve filhos elemento (rastrear com flag por nível), é folha: append do buffer de texto ao buffer final.
- Quando recebe `startElement` enquanto outro elemento já está aberto e ainda não teve filhos, marca o pai como "tem filho elemento" e descarta o buffer de texto dele.
- Tratar `<ans:hash>`: ao abrir `<ans:hash>`, marque flag `inside_hash = true`; ao receber `characters`, descarte se `inside_hash`; ao fechar, deposite string vazia.
- Tratar CDATA: `characters` (ou callback equivalente) já entrega conteúdo desembrulhado.

### Parser streaming pull (StAX, quick-xml, encoding/xml em Go, xmlreader em PHP)

- Modelo parecido com SAX. Manter pilha de contextos (`Vec<NodeCtx>` em Rust, `Stack<NodeCtx>` em Java).
- `NodeCtx { has_child_element: bool, text: String, is_hash: bool }`.
- Em `Start`: push novo contexto; marque o topo anterior `has_child_element = true`.
- Em `Text` / `CData`: append no `text` do topo (se não `is_hash`).
- Em `End`: pop. Se `!has_child_element`, append `text` no buffer de saída.
- Ignorar `Comment`, `PI`, `Decl`, `Doctype`.

### Parsers que normalizam Unicode (cuidado raro)

Alguns parsers fazem normalização NFC/NFD por padrão. **Não normalize.** O hash é sobre bytes UTF-8 literais do `.text`. Se o XML traz `é` como U+00E9, deve sair U+00E9. Se traz como `e` + U+0301, deve sair como `e` + U+0301. Os goldens reais TISS usam pré-composto (NFC), mas a regra é "não tocar".

### Segurança XXE

- Java: `XMLInputFactory.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false)` + `XMLConstants.FEATURE_SECURE_PROCESSING`.
- C# `XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit }`.
- libxml2: `XML_PARSE_NONET | XML_PARSE_NOENT=off`.
- Python lxml: `XMLParser(resolve_entities=False)` (como na referência).
- Node sax/xml2js: configurar `noent: false`.

Não negocie. Falhar feio se o input tentar entidade externa.

## Passo 6: documentar o port

Em `ports/<linguagem>/README.md`:
- Instalação (gerenciador de pacotes da linguagem).
- Exemplo de uso mínimo (5 linhas).
- Como rodar os testes de conformidade.
- Versão da spec implementada (`SPEC v1.0.0`).
- Link de volta para `SPEC.md` e `PORTING_GUIDE.md`.

## Checklist de PR

Antes de abrir PR para inclusão do port, marque tudo:

- [ ] `ports/<linguagem>/` criado seguindo convenção idiomática da linguagem.
- [ ] API pública implementada: `hash_tiss(bytes)` + `hash_tiss_file(path)`.
- [ ] XXE explicitamente desligado no parser.
- [ ] Encoding do MD5 confirmado UTF-8 (não usar encoding do XML).
- [ ] Teste de conformidade lê `conformance/vectors.json` programaticamente (não hardcoded).
- [ ] **Os 8 vetores passam** localmente. Cole a saída no PR.
- [ ] Docstrings/comentários públicos na API.
- [ ] Exemplo de uso de 5 linhas no `ports/<linguagem>/README.md`.
- [ ] Build local funciona com instruções escritas (testado em máquina limpa ou container).
- [ ] Linter/formatter padrão da linguagem rodou sem erros.
- [ ] Commit segue Conventional Commits: `feat(port-<linguagem>): impl. inicial passando 8/8 vetores`.
- [ ] Linha no `README.md` raiz atualizada de `planejado` para `em progresso` ou `pronto`.

## Relacionados

- [`SPEC.md`](SPEC.md): referência canônica do algoritmo.
- [`../README.md`](../README.md): visão geral do projeto.
- [`../conformance/reference.py`](../conformance/reference.py): implementação de referência (use como oráculo durante desenvolvimento).
- [`../conformance/build_fixture.py`](../conformance/build_fixture.py): gera vetores; só altera se for adicionar novo caso de borda **com aprovação**.
