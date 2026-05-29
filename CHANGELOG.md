# Changelog

Todas as mudanças notáveis a este projeto serão documentadas neste arquivo.

O formato segue [Keep a Changelog 1.1.0](https://keepachangelog.com/pt-BR/1.1.0/), e o projeto adere a [Versionamento Semântico (SemVer)](https://semver.org/lang/pt-BR/).

A versão da **especificação canônica** do algoritmo é versionada separadamente em [`docs/SPEC.md`](docs/SPEC.md) (frontmatter `version:`). Mudanças no algoritmo que afetem o hash produzido para um mesmo XML quebram a major version de TODOS os ports.

A versão de **cada port** é independente, declarada em seu próprio pacote (ex.: `langs/python/pyproject.toml`). Este changelog agrega os marcos relevantes do monorepo.

## [Unreleased]

## [0.2.1] - 2026-05-29

Patch: corrige o conjunto de artefatos do release e adiciona guia para IA. Sem mudança no algoritmo (13 ports seguem 20/20 + 3/3 goldens).

### Fixed

- **CI do port Kotlin**: `build.sh` resolvia `kotlin-stdlib.jar` por caminho frágil e falhava no runner (kotlinc instalado via symlink/versão diferente). Agora resolve dinâmico (`readlink -f` do binário + fallbacks). Como efeito, o **jar prebuilt do Kotlin volta a ser anexado ao release** (estava ausente no GitHub v0.2.0).

### Added

- **`AGENTS.md`** na raiz: guia tool-agnóstico para uma IA/agente de código que baixa e USA a lib (não reimplementar; contrato de rejeição; validar contra os vetores; regras de privacidade/LGPD; nunca expor hash real, versão do Padrão TISS ou operadora). README aponta para ele.

### Changed

- Documentação alinhada para **13 ports** em todas as páginas (CONCEITOS, TUTORIAL, FAQ, SPEC, PORTING_GUIDE, USAGE); nota de artefatos prebuilt atualizada (todos presentes nos releases dos dois hosts, incluindo o jar do Kotlin).

## [0.2.0] - 2026-05-29

Expansão para **13 ports**. Quatro linguagens novas, todas passando os mesmos 20 vetores de conformidade (18 positivos + 2 negativos) byte a byte e validadas contra os 3 goldens reais (13/13 ports x 3/3 goldens PASS). Os 9 ports da 0.1.0 seguem inalterados.

### Added

- **Kotlin** (`langs/kotlin/`): alvo JVM (Android/multiplatform), espelha o port Java (DocumentBuilder, namespace por URI, comentários no concat). API `hashTiss`/`hashTissFile` + `InvalidTissXmlException`. Manifestos Gradle + Maven (`dev.petrus`).
- **Object Pascal / Free Pascal** (`langs/delphi/`): para o legado de faturamento médico BR (muito Delphi). `fcl-xml` DOM, compat Delphi. API `HashTiss`/`HashTissFile` + `EInvalidTissXml`.
- **Dart** (`langs/dart/`): mobile cross-platform (Flutter), publicável em pub.dev. `package:xml` + `package:crypto`. API `hashTiss`/`hashTissFile` + `InvalidTissXmlException`.
- **WASM** (`langs/wasm/`): reusa o core Rust via `wasm-bindgen` (browser + Node). Argumento LGPD: o hash roda **client-side**, o XML com dados pessoais nunca sai da máquina do usuário. Ver `docs/adr/0006-wasm-port.md`.
- **ADR-0006**: decisão de implementar o WASM reusando o core Rust (em vez de uma décima reimplementação).
- CI (GitHub Actions + Forgejo) e workflows de release estendidos para os 4 ports novos.

### Notes

- Cada port novo inicia no seu próprio `0.1.0`; o monorepo marca `0.2.0` por adicionar os 4. Versão de cada port permanece independente.
- Gotchas de toolchain documentados nos READMEs: `kotlinc` 2.1.0 não roda sob JDK 25 (CI usa JDK 21); `TEncoding.UTF8` quebrado no FPC 3.2.3 (usa `UTF8Encode`); WASM via `wasm-bindgen-cli` (não `wasm-pack`, que exige rustup).

## [0.1.0] - 2026-05-29

Primeiro release público. Algoritmo do hash MD5 do epílogo do Padrão TISS/ANS extraído, especificado, validado e empacotado em **9 linguagens**, todas passando os mesmos vetores de conformidade byte-a-byte.

### Added

- **Algoritmo de referência** em Python (`conformance/reference.py`), validado byte-a-byte contra 3 XMLs reais com hashes confirmados pela ANS (validação privada, fora do repo).
- **9 ports nativos**, todos passando a suíte de conformidade byte-a-byte contra a referência e entre si:
  - **Python** (`langs/python/`, `tiss-hash`): `hash_tiss(bytes)`, `hash_tiss_file(path)`, `InvalidTissXml`; parser endurecido com `defusedxml`; Python 3.10+.
  - **Rust** (`langs/rust/`, crate `tiss-hash`): `hash_tiss(&[u8])`, `hash_tiss_file(P)`, `TissHashError`.
  - **C** (`langs/c/`, lib + `tiss_hash.h`): `tiss_hash_bytes(...)`, `tiss_hash_file(...)`, `tiss_hash_status_t`; CMake + Makefile.
  - **C++** (`langs/cpp/`, header-only): `tiss_hash::HashTiss(...)`, `HashTissFile(...)`, `InvalidTissXml`; CMake, C++20.
  - **Node.js** (`langs/node/`, `tiss-hash`): `hashTiss(bytes)`, `hashTissFile(path)`, `InvalidTissXmlError`; ESM + CJS.
  - **PHP** (`langs/php/`, `petrinhu/tiss-hash`): `TissHash::hashTiss(string)`, `hashTissFile(string)`, `InvalidTissXmlException`.
  - **Java** (`langs/java/`, `dev.petrus.tisshash`): `TissHash.hashTiss(byte[])`, `hashTissFile(Path)`, `InvalidTissXmlException`; Maven, JDK 17+.
  - **Go** (`langs/go/`, módulo `tisshash`): `HashTiss([]byte)`, `HashTissFile(string)`, `error` idiomático.
  - **C#/.NET** (`langs/csharp/`, `TissHash`): `TissHash.HashTiss(byte[])`, `HashTissFile(string)`, `InvalidTissXmlException`; .NET 8.
- **Suíte de conformidade pública** com **20 vetores 100% sintéticos** (18 positivos + 2 negativos) em `conformance/vectors.json` + `conformance/inputs/`, cobrindo: mínimo, acentuação (discriminador de encoding UTF-8), campos vazios, CR/LF em valor, múltiplas guias, entidades XML predefinidas, entidades numéricas, CDATA, comentários (entram no concat), atributos de folha (não entram), namespace `xsi`, namespace TISS default (sem prefixo), documento sem `<ans:hash>`, whitespace puro, zeros à esquerda, símbolos ISO-8859-1, performance (~600 KB), BOM UTF-8; e 2 negativos de **rejeição**: múltiplos `<ans:hash>` e encoding UTF-16/UTF-32.
- **Especificação canônica** em [`docs/SPEC.md`](docs/SPEC.md) (pseudo-código, diagrama de fluxo, caveat de encoding UTF-8, escopo de encoding, vetores positivos e negativos).
- **Guia de port** [`docs/PORTING_GUIDE.md`](docs/PORTING_GUIDE.md), visão arquitetural [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), uso multi-linguagem [`docs/USAGE.md`](docs/USAGE.md).
- **Architecture Decision Records** 0001-0005 em [`docs/adr/`](docs/adr/): port nativo por linguagem, layout monorepo, packaging/versionamento, matriz de CI, e reconciliação de nomenclatura/groupId/workflows.
- **`THIRD_PARTY_LICENSES.md`**: inventário de dependências de terceiros por port + licenças.
- **CI dual-host**: 9 workflows × GitHub Actions + Forgejo Actions (Codeberg). Hardening: sanitizers ASan/UBSan (C/C++), matriz gcc+clang, lint gate por port (clang-tidy/eslint/phpstan/checkstyle/dotnet-format), coverage, `dependabot.yml` multi-ecosystem, gate de CVE por port, mutation testing (Rust).
- **Documentação legal**: [`LGPD-NOTE`](docs/legal/LGPD-NOTE.md), [`DISCLAIMER`](docs/legal/DISCLAIMER.md), [`TISS-COMPLIANCE`](docs/legal/TISS-COMPLIANCE.md) (agnóstico à versão do Padrão TISS).
- **Política de contribuição**: [`CONTRIBUTING.md`](CONTRIBUTING.md), [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) (Contributor Covenant 2.1), [`SECURITY.md`](SECURITY.md). Templates de issue/PR para GitHub e Codeberg/Forgejo.
- **Repositórios públicos** dual-push: GitHub [`petrinhu/TISS_ANS_hash`](https://github.com/petrinhu/TISS_ANS_hash) e Codeberg [`petrinhu/TISS_ANS_hash`](https://codeberg.org/petrinhu/TISS_ANS_hash).
- **Licença MIT** ([`LICENSE`](LICENSE)).

### Security

- **XXE fechado no port C**: `xmlSetExternalEntityLoader` nega entidade externa (`XML_PARSE_NONET` não cobre `file://`); teste de regressão `test_xxe.c`.
- **Rejeição explícita** (em vez de hash silenciosamente errado): múltiplos `<ans:hash>` e encoding UTF-16/UTF-32 fora de escopo são rejeitados por todos os ports.
- **Sem PII no repositório público**: nenhum hash de XML real nem dado de paciente; toda a documentação usa apenas vetores sintéticos. Os hashes-esperados dos goldens reais vivem em diretório privado fora do repo (LGPD, Lei 13.709/2018).

### Notes

- **Predecessor arquivado**: `TISSGama` (editor desktop legado) foi arquivado nos dois mirrors; o algoritmo de hash foi extraído e migrou para este projeto.
- **Encoding**: o manual do Padrão TISS diz "ISO-8859-1", mas os bytes alimentados ao MD5 são **UTF-8** (validado contra os goldens reais aceitos pela ANS). Ver `docs/SPEC.md` §4.

---

[Unreleased]: https://github.com/petrinhu/TISS_ANS_hash/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/petrinhu/TISS_ANS_hash/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/petrinhu/TISS_ANS_hash/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/petrinhu/TISS_ANS_hash/releases/tag/v0.1.0
