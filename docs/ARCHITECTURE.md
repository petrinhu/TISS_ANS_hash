# Arquitetura — lib_hash_ans

Visão consolidada da arquitetura do projeto. As decisões fundamentais
estão registradas como ADRs em [`docs/adr/`](adr/). Este documento é
**descritivo** (espelha decisões já tomadas), não normativo.

## Propósito

`lib_hash_ans` empacota o algoritmo de geração do hash MD5 do epílogo
TISS/ANS (Padrão TISS — Troca de Informações na Saúde Suplementar /
Agência Nacional de Saúde) como **bibliotecas nativas em múltiplas
linguagens**, todas produzindo o mesmo hash byte-a-byte para o mesmo
XML de entrada.

O algoritmo é definido em prosa em [`docs/adr/0001-port-nativo-por-linguagem.md`](adr/0001-port-nativo-por-linguagem.md)
e executável em [`conformance/reference.py`](../conformance/reference.py).

## Visão C4 — nível 1 (System Context)

```
                  +------------------------+
                  | Sistema externo cliente |
                  | (ERP, prontuário,       |
                  |  faturamento, browser,  |
                  |  app mobile, script CLI)|
                  +-----------+-------------+
                              |
                              | input: XML TISS/ANS (bytes)
                              v
                  +------------------------+
                  |    tiss-hash (port da   |
                  |    linguagem do cliente)|
                  +-----------+-------------+
                              |
                              | output: string hex (32 chars, minúsculo)
                              v
                  +------------------------+
                  |  uso pelo cliente:      |
                  |  preencher <ans:hash>,  |
                  |  validar lote recebido, |
                  |  auditoria, integridade |
                  +------------------------+
```

Não há servidor, não há rede, não há persistência. O port é uma
**função pura** `bytes -> string`. Toda complexidade arquitetural é
sobre **distribuição** e **conformidade** entre ports — não sobre runtime.

## Visão C4 — nível 2 (Container) — do monorepo

```
+--------------------------------------------------------------------+
| lib_hash_ans (monorepo)                                            |
|                                                                    |
|  +-------------------+     +----------------------------------+   |
|  | conformance/      |     | langs/                            |   |
|  |  (AUTORIDADE)     |<----+                                   |   |
|  |                   |     |  +---------+  +---------+         |   |
|  | reference.py      |     |  | python/ |  | rust/   |  ...   |   |
|  | vectors.json      |     |  +---------+  +---------+         |   |
|  | build_fixture.py  |     |  +---------+  +---------+         |   |
|  | inputs/*.xml      |     |  | node/   |  | php/    |         |   |
|  +-------------------+     |  +---------+  +---------+         |   |
|         ^                  |  +---------+  +---------+         |   |
|         |                  |  | c/      |  | cpp/    |         |   |
|         | (refere via CI)  |  +---------+  +---------+         |   |
|         |                  |  +---------+  +---------+         |   |
|  +------+------------+     |  | go/     |  | java/   |         |   |
|  | CI                |     |  +---------+  +---------+         |   |
|  | .forgejo/         |     |  +---------+  +---------+         |   |
|  | .github/          |     |  | dotnet/ |  | delphi/ |         |   |
|  +-------------------+     |  +---------+  +---------+         |   |
|                            |  +---------+  +---------+         |   |
|  +-------------------+     |  | dart/   |  | wasm/   |         |   |
|  | docs/             |     |  +---------+  +---------+         |   |
|  | docs/adr/         |     +----------------------------------+   |
|  +-------------------+                                             |
+--------------------------------------------------------------------+

Fluxo de validação:
  langs/<lang>/  --(roda testes em CI)-->  conformance/vectors.json
                                           (aceita ou rejeita port)
```

## Fluxo de dados (sequência de cálculo do hash)

```
Cliente: bytes do arquivo XML TISS
   |
   v
[port.hash_tiss_bytes(raw_bytes)]
   |
   |  1. parse XML
   |     (parser idiomático da linguagem: lxml, quick-xml,
   |      DOMDocument, fast-xml-parser, System.Xml,
   |      pugixml/libxml2, encoding_xml, OmniXML, etc.)
   |
   v
[árvore DOM]
   |
   |  2. localiza <ans:hash> (namespace ANS) e zera .text
   |     (se não existir, segue sem fazer nada — não é erro)
   |
   v
[árvore DOM com <ans:hash> vazio]
   |
   |  3. visita CADA elemento em ordem de documento;
   |     se elemento é FOLHA (sem filhos): pega .text (ou "" se None);
   |     concatena tudo numa única string.
   |
   v
[string única de valores concatenados]
   |
   |  4. encoda como bytes UTF-8 (ATENÇÃO: NÃO ISO-8859-1).
   |     md5(utf-8 bytes) -> digest binário 16 bytes.
   |
   v
[digest 16 bytes]
   |
   |  5. hex encode, lowercase.
   |
   v
[string 32 chars, hex minúsculo]
```

### Pseudocódigo unificado (linguagem-agnóstico)

```
function hash_tiss_bytes(raw: bytes) -> string:
    tree = parse_xml(raw)
    root = tree.root
    NS_ANS = "http://www.ans.gov.br/padroes/tiss/schemas"

    for node in root.iter_all():
        if node.tag == "{NS_ANS}hash":
            node.text = ""
            break  # só o primeiro (existe um único por documento)

    concat = ""
    for node in root.iter_all_in_document_order():
        if node.is_leaf():           # sem filhos elementos
            concat += node.text or ""

    utf8 = concat.encode("utf-8")
    return hex_lowercase(md5(utf8))
```

### Detalhes críticos (pegadinhas)

1. **Encoding do MD5 é UTF-8, não ISO-8859-1.** O arquivo é frequentemente
   lido como ISO-8859-1 (declaração XML), mas os **valores extraídos**
   são re-encodados em UTF-8 antes do MD5. Manual TISS está errado nesse
   ponto — `vectors.json` é a régua.

2. **Folha = sem filhos elementos**, independente de ter texto ou não.
   `<x></x>` e `<y/>` contribuem `""` (string vazia) à concatenação.

3. **Ordem de documento.** Pegar valores na ordem em que aparecem no XML;
   `multi_guia` testa isso.

4. **CR/LF dentro de valores são preservados literalmente.** Não
   normalizar `\r\n` para `\n` antes do hash; testado por `syn_crlf_value`.

5. **Whitespace entre tags** (`\n  <ans:x>`) vai no `.text`/`.tail` de
   elementos não-folha, **não** é incluído na concatenação porque
   elementos não-folha são pulados.

6. **Atributos não entram.** Só `.text` de folhas.

7. **`<ans:hash>` deve ser zerado antes de iterar.** Se não, o hash
   antigo (possivelmente lixo ou hash anterior) contamina o cálculo.

## Bounded contexts / módulos

Cada port é um **bounded context** auto-contido:

- **API pública** mínima: `hash_tiss_bytes(bytes) -> string` (alguns ports
  também expõem `hash_tiss_file(path) -> string` por conveniência).
- **Dependência única externa permitida**: parser XML idiomático da
  linguagem + MD5 (geralmente stdlib).
- **Sem estado mutável global**, sem IO além do que o usuário fornece.
- **Sem dependência de outro port** (princípio do ADR-0001).

O **único contexto compartilhado** é `conformance/` — autoridade canônica
do que é "o algoritmo".

## Stack proposta

| Camada / Aspecto         | Tecnologia / Padrão                                  | Justificativa                                              |
|--------------------------|------------------------------------------------------|------------------------------------------------------------|
| Algoritmo                | MD5 + concat string + parse XML                      | Determinado pela ANS (manual TISS), validado por goldens   |
| Implementação            | Native por linguagem (ADR-0001)                      | Distribuição via registry idiomático sem binários nativos  |
| Contrato                 | `conformance/vectors.json` + `inputs/*.xml`          | Definição executável, byte-a-byte                          |
| Layout                   | Monorepo `langs/<lang>/` (ADR-0002)                  | Truth source única, evolução por port                      |
| Versionamento            | SemVer independente por port (ADR-0003)              | Cada port no seu ritmo, regulado por vectors               |
| Nome canônico            | `tiss-hash` (ADR-0003)                               | Curto, descritivo, livre nos registries                    |
| CI primária              | Forgejo Actions (ADR-0004)                           | Alinhada com infra do usuário                              |
| CI espelho               | GitHub Actions (ADR-0004)                            | Acesso a PRs externos via mirror                           |
| Granularidade CI         | 1 workflow por port + conformance gatekeeper         | Path-filtered, paralelo, debug claro                       |
| Documentação             | Hub `README.md` + ADRs + `ARCHITECTURE.md`           | Padrão hub-and-spoke (preferência do usuário)              |
| Changelog                | `CHANGELOG.md` único agregado, entradas por port     | Visão histórica unificada                                  |
| Pendências               | `TODO.md` único (skill `tab_pendencias`)             | Padrão pessoal do usuário                                  |

## Integrações

Nenhuma. Lib pura, sem rede, sem IO além de input do usuário.

## Dados

Nenhum estado persistente. Inputs do conformance (`conformance/inputs/`)
são fixture estática; não devem crescer indefinidamente. Vetor novo =
arquivo `.xml` pequeno em `inputs/` + entry no `vectors.json` regenerada
via `build_fixture.py`.

## Resiliência

Como função pura, "resiliência" se manifesta como **robustez de input**:

- **XML malformado**: cada port deve **propagar erro do parser** sem
  mascarar (lançar exception/erro idiomático). Não retornar string vazia
  nem hash falso.
- **`<ans:hash>` ausente**: aceita (não é erro); algoritmo segue sem
  zerar (não há o que zerar).
- **Encoding declarado errado** no XML: comportamento depende do parser
  da linguagem; documentar diferenças observadas como notas no README
  do port. `vectors.json` cobre apenas ISO-8859-1 corretamente declarado
  (o caso real).
- **Input gigante** (lote de 100MB+): implementações streaming são
  permitidas como otimização **se** continuarem produzindo o mesmo hash
  byte-a-byte. MINOR bump da lib.

## Segurança

- **MD5 não é resistente a colisão.** Algoritmo é determinado por norma
  externa (ANS); não há escolha. Lib **NÃO deve ser usada para
  autenticação criptográfica** — só para conferência de integridade
  conforme spec TISS. Avisar isso explicitamente no README de cada port.
- **XML External Entity (XXE):** **parsers devem ser configurados com
  entity expansion desabilitada** quando a linguagem permitir
  (Python: `resolve_entities=False`; .NET: `XmlResolver = null`; Java:
  `setFeature(FEATURE_SECURE_PROCESSING, true)`). É **requisito de
  segurança** dos ports — entrada típica é XML de terceiros.
- **Sem segredos.** Lib não lida com chaves, tokens, credenciais.
- **Sem rede.** Lib não fala TLS, não baixa nada, não chama webservice.

## Observabilidade

Não aplicável (função pura). Recomendação para usuários: logar input
hash + output hash quando útil para auditoria; **nunca logar conteúdo
do XML** (pode conter dados sensíveis de saúde — LGPD).

## Trade-offs aceitos

1. **N implementações independentes** = N vezes o esforço de bugfix.
   Aceito porque o algoritmo é pequeno e o contrato (`vectors.json`) é
   rigoroso. Ver ADR-0001.
2. **Sem core compartilhado / sem FFI.** Distribuição muito mais simples,
   ao custo de não ter "uma única fonte" implementacional. Ver ADR-0001.
3. **Versões independentes por port.** Usuário multi-linguagem precisa
   olhar tabela de compatibilidade no README. Ver ADR-0003.
4. **Workflows CI duplicados** (Forgejo + GitHub). Sync manual via
   script. Ver ADR-0004.

## Riscos top-3

1. **Vetores incompletos.** Caso de borda real (ex.: namespace prefix
   diferente, XML com BOM, encoding latin-1 sem declaração) pode passar
   CI e quebrar em produção. Mitigação: adicionar vetor toda vez que
   aparecer XML real que diverge.
2. **Parser XML divergente entre linguagens.** Cada lib XML lida com
   whitespace/entity/namespace de jeito sutilmente diferente. Mitigação:
   vetores sintéticos cobrindo CR/LF, vazios, acento, multi-guia
   (já presentes); adicionar mais conforme bugs aparecem.
3. **MD5 quebrado por mudança normativa da ANS.** Pouco provável a
   curto prazo, mas se acontecer exige `conformance-v2` + bump MAJOR de
   todos os ports. Mitigação: ADR registrando plano de transição se
   chegar a hora.

## Próximos passos (sequenciados)

1. **Port Python** (`langs/python/`) — primeiro, porque a referência já
   é Python; reusa lógica direto.
2. **Port Rust** — toolchain madura, fácil de configurar CI; valida
   independência (Rust não compartilha runtime com Python).
3. **Port Node/TypeScript** — cobre ecossistema web/JS, valida parser
   XML JS (historicamente problemático).
4. **Port C** — útil pra Conan/vcpkg e como base para integrações
   embedded; valida ausência de garbage collector.
5. **Port PHP** — alta demanda no ecossistema TISS (sistemas de
   faturamento médico BR).
6. **Ports Tier 2** conforme demanda concreta aparecer (Java, .NET,
   Delphi, Go, Dart, WASM).

Cada port novo segue o checklist em `CONTRIBUTING.md` (a criar):

- [ ] `langs/<lang>/` com layout idiomático da linguagem.
- [ ] API `hash_tiss_bytes(bytes) -> string` exposta.
- [ ] Testes rodam contra `../../conformance/vectors.json` byte-a-byte.
- [ ] `.forgejo/workflows/lang-<lang>.yml` + espelho GitHub.
- [ ] README do port + entrada no README hub.
- [ ] Entry no `CHANGELOG.md` agregado.
- [ ] Nome de pacote reservado no registry (validado livre).

## Referências

- [ADR-0001 — Port nativo por linguagem](adr/0001-port-nativo-por-linguagem.md)
- [ADR-0002 — Layout monorepo](adr/0002-layout-monorepo.md)
- [ADR-0003 — Packaging e versionamento](adr/0003-packaging-e-versionamento.md)
- [ADR-0004 — CI matrix](adr/0004-ci-matrix.md)
- [Referência executável do algoritmo](../conformance/reference.py)
- [Vetores de conformidade](../conformance/vectors.json)
