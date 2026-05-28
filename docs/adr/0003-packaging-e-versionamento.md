# ADR-0003: Packaging, nome canônico e versionamento por port

**Status:** Accepted
**Data:** 2026-05-27
**Decisores:** Petrus (autor/dono do projeto)

## Contexto

Cada port (ADR-0001) é publicado no **registry idiomático da sua linguagem**.
Falta decidir:

1. **Nome canônico do pacote** — coerente entre registries, sem colidir
   com pacotes existentes, descritivo do propósito (hash de XML TISS/ANS),
   pesquisável.
2. **Esquema de versão** — SemVer? Calendar? E principalmente: ports
   versionam **sincronizados** (todos sobem juntos) ou **independentes**
   (cada um no seu ritmo)?
3. **Política de pre-release** (`alpha`/`beta`/`rc`).
4. **Convenção de tag git** no monorepo (tags compartilham namespace).

Pesquisa rápida de colisão de nome (mai/2026):

- `tiss-hash`: livre em PyPI, npm, crates.io, Packagist, pub.dev (validar
  no publish).
- `ans-tiss-hash`: livre em todos, mais descritivo mas mais longo.
- `tiss-md5`: livre, porém o algoritmo poderia mudar de hash no futuro (ANS
  já discutiu SHA-256) — nome enviesa.
- `libhashtiss` / `libtisshash`: prefixo `lib*` é desnecessário em registry
  de linguagem alta (PyPI/npm); só faz sentido em C/C++/Conan.

## Decisão

### Nome canônico

**`tiss-hash`** como nome-base em todos os registries que aceitam hyphen.
Para registries com convenção própria, transliterar:

| Registry              | Nome publicado                          | Justificativa de forma                                       |
|-----------------------|-----------------------------------------|--------------------------------------------------------------|
| PyPI                  | `tiss-hash`                             | hyphen aceito; import como `tiss_hash`                       |
| crates.io             | `tiss-hash`                             | hyphen aceito; uso como `tiss_hash::`                        |
| npm                   | `tiss-hash`                             | hyphen idiomático em npm                                     |
| Packagist (PHP)       | `petrinhu/tiss-hash`                    | vendor obrigatório no Packagist                              |
| Maven Central         | `br.dev.petrus:tiss-hash` (groupId real do autor) | reverse-DNS obrigatório                              |
| NuGet                 | `TissHash`                              | PascalCase idiomático .NET                                   |
| pub.dev (Dart/Flutter)| `tiss_hash`                             | snake_case obrigatório                                       |
| Go modules            | `gitea.com/<org>/lib_hash_ans/langs/go` (path do monorepo) | Go usa path do repo; não há "nome" separado |
| Conan (C/C++)         | `tiss-hash/1.0.0@<user>/stable`         | nome + versão + user/channel                                 |
| vcpkg (C/C++)         | `tiss-hash`                             | port name é hyphenated                                       |
| Delphi (manual)       | `TissHash` (unit `TissHash.pas`)        | sem registry — distribuir via GetIt/git tag                  |

**Justificativa do nome `tiss-hash` (vs `ans-tiss-hash`):**

- TISS já é um padrão da ANS — `ans-tiss-hash` é redundante.
- Mais curto = menos atrito em `composer require` / `cargo add` / `npm i`.
- A ambiguidade ("hash de quê?") é resolvida pela primeira linha do README
  de cada port + tags do registry.

### Identificadores em código (por port)

| Linguagem      | Módulo / namespace      | Função principal                |
|----------------|-------------------------|---------------------------------|
| Python         | `tiss_hash`             | `tiss_hash.hash_tiss_bytes(b)`  |
| Rust           | `tiss_hash`             | `tiss_hash::hash_tiss_bytes(&[u8])` |
| Node/TS        | `tiss-hash`             | `hashTissBytes(buf: Buffer)`    |
| PHP            | `TissHash\TissHash`     | `TissHash::hashTissBytes(string)`|
| C              | header `tiss_hash.h`    | `tiss_hash_bytes(const uint8_t*, size_t, char out[33])` |
| C++            | `tiss_hash::`           | `tiss_hash::hash_tiss_bytes(std::span<const std::byte>) -> std::string` |
| Go             | package `tisshash`      | `tisshash.HashTissBytes([]byte) string` |
| Java           | `dev.petrus.tisshash`   | `TissHash.hashTissBytes(byte[]) -> String` |
| Kotlin         | `dev.petrus.tisshash`   | `TissHash.hashTissBytes(ByteArray): String` |
| C#/.NET        | `Petrus.TissHash`       | `TissHash.HashTissBytes(byte[]) -> string` |
| Delphi         | unit `TissHash`         | `function HashTissBytes(const RawBytes: TBytes): string;` |
| Dart/Flutter   | `tiss_hash`             | `hashTissBytes(Uint8List): String` |
| WASM (do JS)   | `tissHashWasm`          | `tissHashWasm(buf: Uint8Array): string` |

### Versionamento

**SemVer 2.0.0 por port (versões independentes).** Cada port tem sua
própria sequência. Exemplos co-existindo:

- `tiss-hash` (Python) `1.4.2`
- `tiss-hash` (Rust)   `0.2.0`
- `tiss-hash` (Node)   `1.0.1`

**Mapeamento SemVer ↔ algoritmo:**

- **MAJOR**: muda quando o **algoritmo muda** (vetor antigo deixa de valer
  e isso é intencional). Quebra de compatibilidade real.
- **MINOR**: adiciona API pública nova (ex.: helper `hash_tiss_file`,
  versão streaming) mantendo o hash idêntico.
- **PATCH**: bugfix de port (ex.: parser entity expansion, edge case),
  bumps de dependência, perf. **Não muda hash.**

**Vetores são o regulador.** Subir MINOR/PATCH **sem** o port passar 100%
de `vectors.json` é proibido por CI. Subir MAJOR exige bump correspondente
em `conformance/vectors.json` (vetor de algoritmo v2) e ADR explicando.

### Tags git no monorepo

Convenção: `<lang>-v<semver>`.

- `python-v1.4.2`
- `rust-v0.2.0`
- `conformance-v1.0.0` (versão da suíte; bump quando vetores mudam de
  forma incompatível)

CI dispara publish do port X quando aparece tag `^x-v\d+\.\d+\.\d+$`.

### Pre-release

`-alpha.N`, `-beta.N`, `-rc.N` conforme SemVer. Ex.: `python-v2.0.0-rc.1`.
Publish em pre-release vai pra canal de pre-release do registry quando
existir (npm `--tag next`, PyPI implícito via PEP 440, crates.io implícito).

## Alternativas consideradas

### Q1 — Nome canônico

**A. `tiss-hash`** *(escolhida)* — curto, descritivo, pesquisável.
- Prós: digitação rápida; semanticamente claro; ainda livre nos registries.
- Contras: pode colidir no futuro se alguém publicar primeiro (validar
  imediatamente antes do release v1.0.0).

**B. `ans-tiss-hash`** — mais qualificado.
- Prós: explicita órgão regulador; menos chance de colisão.
- Contras: redundante (TISS é da ANS por definição); mais longo.

**C. `hashtiss` / `libtisshash`** — colado.
- Prós: improvável colisão.
- Contras: feio, anti-idiomático em PyPI/npm/crates.

### Q2 — Sincronizado vs independente

**A. Versões sincronizadas** (todo port em `v1.4.2` ao mesmo tempo).
- Prós: usuário multi-linguagem (raro neste caso) sabe que `1.4.2` em
  qualquer registry é a mesma "geração".
- Contras: força release coordenado mesmo quando só um port mudou;
  inflaciona MAJOR (port A precisa breaking change → todos sobem MAJOR
  falsamente); contraditório com ADR-0001 ("cada port evolui independente");
  bumps "vazios" poluem changelog.

**B. Versões independentes** *(escolhida)* — cada port no seu ritmo.
- Prós: alinhado com decisão de port nativo; bug em um port não obriga
  release dos outros; semver de cada port reflete realidade daquele port.
- Contras: usuário multi-linguagem tem que olhar tabela de compatibilidade
  no README pra saber "qual versão de cada port implementa o mesmo
  algoritmo". Mitigado: `vectors.json` tem versão própria
  (`conformance-vN`), e cada port declara no README "compatível com
  conformance v1".

**C. Calendar versioning** (`2026.05`).
- Prós: sem ambiguidade temporal; bom pra projetos que liberam regular.
- Contras: não comunica breaking change; usuário não sabe se atualizar é
  seguro. Inadequado para lib reutilizável.

### Q3 — Vendor de Packagist e groupId Maven

Decidir **no momento de publicar primeiro pacote PHP/Java**. Sugestões
provisórias:

- Packagist: `petrinhu/tiss-hash` (autor já tem conta GitHub `petrinhu`).
- Maven groupId: `br.dev.petrus` (reverse-DNS de domínio próprio se
  existir) ou `io.github.petrinhu`.

Marcar como pendência em `TODO.md` quando o port PHP/Java for iniciado.

## Consequências

**Positivas:**

- Nome consistente facilita encontrar a lib em qualquer ecossistema.
- Versões independentes respeitam ritmo de cada port (algumas linguagens
  liberam frequentemente, outras quase nunca).
- `conformance-vN` desacopla a versão do contrato da versão dos ports —
  o que é correto, já que o algoritmo evolui em ritmo próprio.
- SemVer regulado por vetores: impossível subir release inválido (CI
  bloqueia).

**Negativas / aceitas como custo:**

- Mapa de compatibilidade no README precisa ser mantido (qual versão de
  cada port implementa qual `conformance-vN`).
- Usuário multi-linguagem (raro) precisa checar tabela.
- Nome `tiss-hash` precisa ser registrado/squattado em todos os registries
  antes do primeiro release, pra evitar typosquatting.

**Riscos / pontos de atenção:**

- **Colisão de nome** futura. Mitigação: criar conta de organização nos
  registries-chave (PyPI, npm, crates.io, Packagist) e fazer reserve
  publish (versão `0.0.1` placeholder) o quanto antes.
- **MAJOR do algoritmo** (improvável, mas a ANS pode trocar de MD5) —
  exige plano de transição: `conformance-v2` coexiste com `v1`;
  ports publicam `2.0.0` mas mantêm `1.x` em maintenance.
- **Delphi não tem registry público canônico** — distribuir via git tag
  + Boss (gerenciador comunitário) + instruções manuais.

## Reversibilidade

- **Nome do pacote:** one-way door **após primeiro publish público**.
  Renomear depois exige deprecate + republicar sob novo nome. Por isso
  validar disponibilidade nos registries antes de v1.0.0.
- **Estratégia SemVer:** two-way door com custo médio. Mudar de
  independente pra sincronizado depois é só convenção (forçar bump
  coordenado nos próximos releases). O inverso é mais incômodo (renumerar)
  mas viável.
- **Convenção de tag:** two-way door barato — basta documentar e seguir
  daqui pra frente; tags antigas podem coexistir.
