# ADR-0005: Reconciliação de nomenclatura de API, groupId Maven e convenção de workflows CI

**Status:** Accepted
**Data:** 2026-05-28
**Decisores:** Petrus (autor/dono do projeto)
**Emenda:** ADR-0003 (nomes de função e groupId Maven), ADR-0004 (nomes de arquivo de workflow)

## Contexto

Os ADR-0003 (packaging/nomenclatura) e ADR-0004 (CI) foram escritos em
2026-05-27, **antes** dos ports serem implementados. À medida que os 9 ports
(Python, Rust, Node, PHP, C, C++, Java, Go, C#) foram escritos e a CI montada,
três decisões provisórias daqueles ADRs **divergiram da implementação real**,
que é a fonte de verdade:

1. **Nome da função pública por port.** ADR-0003 (seção "Identificadores em
   código") propôs `hash_tiss_bytes` / `hashTissBytes` / `HashTissBytes`.
   A implementação adotou o nome mais curto e idiomático **`hash_tiss`**
   (e equivalentes por linguagem), reservando o sufixo `_bytes` apenas para
   a referência interna `conformance/reference.py` e para o nível C de baixo
   nível. O nome `*_bytes` na API pública não foi adotado.

2. **groupId Maven do port Java.** ADR-0003 listou `br.dev.petrus` como
   sugestão provisória (seção "Q3 — Vendor de Packagist e groupId Maven",
   marcada como "decidir no momento de publicar"). O `langs/java/pom.xml`
   real usa **`dev.petrus`** (sem o prefixo `br.`).

3. **Convenção de nome dos workflows CI.** ADR-0004 (seção "Granularidade")
   propôs `lang-<linguagem>.yml` mais workflows auxiliares `conformance.yml`
   e `release-<lang>.yml`. A implementação adotou o nome curto
   **`<linguagem>.yml`** (ex.: `python.yml`, `rust.yml`) em ambas as
   plataformas, e os workflows `conformance.yml` / `release-*.yml` **não
   existem** — a verificação de conformance roda dentro de cada workflow de
   port.

Pela regra do projeto, decisões registradas **não se reescrevem**: cria-se
novo ADR que as emenda. Este ADR registra a realidade e supersede os pontos
específicos acima, sem invalidar o restante de ADR-0003 e ADR-0004.

## Decisão

### 1. Nome canônico da função pública: `hash_tiss` / `hash_tiss_file`

A API pública de cada port expõe **duas funções**, com o nome-base
`hash_tiss` (recebe bytes/conteúdo XML) e `hash_tiss_file` (recebe caminho),
transliterado para a convenção de cada linguagem. O sufixo `_bytes` **não**
faz parte da API pública.

| Linguagem | Módulo / namespace      | Função (conteúdo)            | Função (arquivo)              |
|-----------|-------------------------|------------------------------|-------------------------------|
| Python    | `tiss_hash`             | `hash_tiss`                  | `hash_tiss_file`              |
| Rust      | `tiss_hash`             | `hash_tiss`                  | `hash_tiss_file`              |
| Node/TS   | `tiss-hash`             | `hashTiss`                   | `hashTissFile` (async)        |
| PHP       | `TissHash\TissHash`     | `hashTiss`                   | `hashTissFile`                |
| C++       | `tiss_hash::`           | `HashTiss`                   | `HashTissFile`                |
| Go        | package `tisshash`      | `HashTiss`                   | `HashTissFile`                |
| Java      | `dev.petrus.tisshash`   | `hashTiss`                   | `hashTissFile`                |
| C#/.NET   | `Petrus.TissHash`       | `HashTiss`                   | `HashTissFile`                |

**Caso especial — C.** O header público `tiss_hash.h` segue o padrão C de
prefixar todo símbolo com o nome do módulo: as funções são
`tiss_hash_bytes(...)` e `tiss_hash_file(...)`. Aqui o `*_bytes` **é real e
idiomático em C** (não confundir com a proposta abandonada de ADR-0003 para
as demais linguagens) — em C não existe namespace, então o prefixo carrega a
semântica que `tiss_hash::HashTiss` carrega em C++.

**Origem do nome `*_bytes` em ADR-0003.** O sufixo veio espelhar a referência
interna `conformance/reference.py` (que tem `hash_tiss_bytes`). Para a API
pública, optou-se por `hash_tiss` por ser mais curto, suficiente (o
overload/segunda função `*_file` cobre o caso de caminho) e mais agradável no
call-site (`hash_tiss(xml)` vs `hash_tiss_bytes(xml)`). O nome `*_bytes`
permanece **apenas** em `conformance/reference.py` (uso interno) e no header C.

### 2. groupId Maven: `dev.petrus`

O port Java publica sob **groupId `dev.petrus`**, artifactId `tiss-hash`
(coordenada Maven `dev.petrus:tiss-hash`). O prefixo `br.` da sugestão
provisória de ADR-0003 **não** foi adotado. A linha do ADR-0003 que cita
`br.dev.petrus:tiss-hash` na tabela de registries fica emendada por esta
decisão.

### 3. Convenção de workflow CI: `<linguagem>.yml`

Cada port tem **um arquivo de workflow** nomeado pela linguagem, sem prefixo
`lang-`, replicado idêntico em forma nas duas plataformas:

```
.forgejo/workflows/        .github/workflows/
├── python.yml             ├── python.yml
├── rust.yml               ├── rust.yml
├── node.yml               ├── node.yml
├── php.yml                ├── php.yml
├── c.yml                  ├── c.yml
├── cpp.yml                ├── cpp.yml
├── go.yml                 ├── go.yml
├── java.yml               ├── java.yml
└── csharp.yml             └── csharp.yml
```

- **Não existe** `conformance.yml` separado. A verificação de conformance
  (rodar o port contra `conformance/vectors.json`) acontece **dentro** de
  cada workflow de port. A proteção da referência canônica contra drift
  permanece um objetivo válido, mas hoje é coberta pela suíte de cada port
  e por review, não por um gatekeeper dedicado.
- **Não existem** workflows `release-<lang>.yml`. A estratégia de publish
  por tag descrita em ADR-0003/0004 ainda é a direção desejada, mas **não
  está implementada** — quando for, decidir se o publish vira workflow
  próprio (`release-<lang>.yml`) ou job condicional dentro de `<lang>.yml`,
  e registrar em novo ADR.
- O prefixo `lang-` de ADR-0004 fica emendado: o nome real é `<linguagem>.yml`.

O restante de ADR-0004 permanece válido: Forgejo Actions primária + GitHub
Actions espelho, um workflow por port, path filter por port, matrix LTS+current.

## Alternativas consideradas

**A. Editar os corpos de ADR-0003 e ADR-0004 para refletir a realidade.**
Rejeitada — viola a regra do projeto ("ADR não se reescreve; emenda-se com
novo ADR"). Apagaria o histórico de que `*_bytes`, `br.dev.petrus` e
`lang-*.yml` foram um dia a intenção, perdendo rastreabilidade da evolução.

**B. Renomear a implementação para casar com os ADRs antigos** (voltar a
`hash_tiss_bytes`, `br.dev.petrus`, `lang-python.yml`). Rejeitada — os nomes
reais já são mais curtos e idiomáticos, 9 ports e 2 plataformas de CI já estão
verdes com eles, e o port Java já está com `dev.petrus`. Reverter geraria
churn e quebraria expectativas sem ganho.

**C. Novo ADR que registra a realidade e emenda os pontos divergentes**
*(escolhida)* — preserva histórico, alinha a documentação canônica com a
implementação (fonte de verdade) e mantém ADR-0003/0004 intactos no corpo.

## Consequências

**Positivas:**

- A documentação de decisão (ADRs) volta a casar com a implementação real:
  quem lê os ADRs em sequência (0003 → 0004 → 0005) chega ao estado atual.
- Single source of truth preservada: a impl é a verdade; o ADR-0005 a
  documenta.
- Histórico de evolução intacto — dá pra ver o que mudou de intenção para
  realidade e por quê.

**Negativas / aceitas como custo:**

- Leitor precisa ler ADR-0005 para saber que ADR-0003/0004 têm pontos
  superados. Mitigado: ponteiro de uma linha no topo de cada um.
- Mais um arquivo no diretório `docs/adr/`.

**Riscos / pontos de atenção:**

- **Publish ainda não implementado.** Quando o pipeline de release for
  construído, revisar se `release-<lang>.yml` (ADR-0003/0004) ou job inline
  é o caminho, e registrar em ADR futuro.
- **Ports futuros** (Kotlin, Delphi, Dart, WASM — previstos em ADR-0001/0003)
  devem seguir `hash_tiss`/`hash_tiss_file` idiomático e workflow
  `<linguagem>.yml`, não os nomes antigos.

## Reversibilidade

- **Nomes de função:** one-way door após primeiro publish público de cada
  port (renomear API pública exige deprecation). Antes disso, two-way door.
  Hoje nenhum port foi publicado em registry, mas a convenção está estável.
- **groupId Maven:** one-way door após publish no Maven Central. Ainda não
  publicado — `dev.petrus` é a coordenada definitiva planejada.
- **Convenção de workflow:** two-way door barato — renomear arquivo `.yml`
  é mecânico em ambas as plataformas.
