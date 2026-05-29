# TISS_ANS_hash — Planejamento

Tabela canônica de pendências do projeto. Atualizar via `/tab_pendencias`.

**Ordenação:** linhas de cima para baixo = ordem de execução que minimiza retrabalho (topological sort por pré-requisito + WSJF dentro de cada nível). Coluna **Onda** (`W1`, `W2`, …) marca passos de igual valor sem dependência mútua = **paralelizáveis**.

Status: ✅ Concluído / 🔄 Em andamento / 🟡 Parcial / ⏳ Pendente / 💡 Decisão tomada / 🎨 Pendente design / 🔍 Pendente verificação. Estado Auditado: `—` não auditado / `✓` aprovado / `⚠` com ressalvas.

---

## Pendências ordenadas (execução)

| ID | Onda | Grupo | Descrição Técnica | Prioridade | Pré-requisito | Dificuldade | Status | Estado Auditado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| A-QA2 | W6 | QA | cargo-mutants achou 4 mutantes sobreviventes em rust/src/lib.rs (asserts fracos, NÃO bugs): Display::fmt texto, Error::source cadeia, allow_dtd (sem vetor com DTD interno), is_leaf ramo PI. Matar com vetores DTD+PI no conformance + assert de msg/source de erro (toca conformance → qa-engineer) | Baixa | A-QA1 | Média | ⏳ Pendente | — |
| F7.1 | — | Release | **Tag v0.1.0 criada + empurrada (2 remotes) @ 534fc2f.** Go publicado pela tag (`go get .../langs/go@v0.1.0`). PyPI = gated (PYPI_ENABLED, espera conta+pending publisher do líder) | Alta | F1.9, F4.1, A-DOC4 | Baixa | ✅ Concluído | ✓ |
| F4.4 | — | CI | Release automation: release-python.yml (PyPI OIDC gated) + 4 workflows registry gated + .forgejo/release.yml. Tudo pronto, liga por var+secret | Média | F7.1 | Média | ✅ Concluído | ✓ |
| F7.2 | — | Release | **GitHub Release v0.1.0 NO AR** (run release-python.yml success): 13 assets = 9 ports (whl+sdist/tgz/crate/jar/nupkg/.a+.so) + source.tar.gz + SHA256SUMS + SBOM. Codeberg release dispatchado (run #71) | Alta | F7.1 | Baixa | ✅ Concluído | ✓ |
| A-REL1 | — | Release | SHA256SUMS + SBOM CycloneDX anexados no GitHub release (gerados na CI) | Baixa | F7.2 | Média | ✅ Concluído | ✓ |
| F7.3 | W6 | Release | Anúncio (DEV.to, LinkedIn, fórum de saúde suplementar BR) | Baixa | F7.2 | Baixa | ⏳ Pendente | — |
| F7.4 | W6 | Release | Submeter pacote pra mirrors (conda-forge se aplicável) | Baixa | F7.1 | Baixa | ⏳ Pendente | — |
| F8.7 | W6 | SEO (Tier 3) | Submit PR awesome-brasil + awesome-health-tech + awesome-tiss (se existir) | Baixa | F7.1 | Baixa | ⏳ Pendente | — |
| F8.8 | W6 | SEO (Tier 3) | Blog post anúncio: DEV.to + LinkedIn + fóruns TI saúde suplementar BR | Baixa | F7.1 | Média | ⏳ Pendente | — |
| F8.9 | W6 | SEO (Tier 3) | GitHub Pages site (Hugo/MkDocs) com domínio próprio ou subpath github.io | Baixa | F8.1 | Média | ⏳ Pendente | — |
| F8.10 | W6 | SEO (Tier 3) | Submit conda-forge (overlap c/ F7.4) | Baixa | F7.1 | Baixa | ⏳ Pendente | — |
| F6.2 | W6 | Port Kotlin | langs/kotlin/ (JVM, espelha Java/DocumentBuilder). **v0.2.0**. Toolchain kotlinc 2.1.0 em ~/sdks. backend-engineer | Média | F6.1 | Baixa | 🔄 Em andamento | — |
| F6.6 | W6 | Port Dart | langs/dart/ (package:xml, pub.dev). **v0.2.0**. Toolchain dart 3.12.1 em ~/sdks. backend-engineer | Baixa | F2.4 | Média | 🔄 Em andamento | — |
| F6.4 | W6 | Port Delphi/FPC | langs/delphi/ (Object Pascal, fcl-xml DOM, FPC compat). **v0.2.0**. Toolchain fpc 3.2.3. backend-engineer | Média | F2.4 | Alta | 🔄 Em andamento | — |
| F6.7 | W6 | Port WASM | langs/wasm/ (core Rust via wasm-bindgen → browser; LGPD: hash client-side, XML não sai da máquina). **v0.2.0**. rust wasm32 + wasm-pack. ADR-0006 + backend-engineer | Baixa | F5.1 | Alta | 🔄 Em andamento | — |
| F4.2b | W6 | CI | Alternativa self-host forgejo-runner (backup) | Baixa | F4.2 | Média | ⏳ Pendente | — |
| A-DOC11 | W6 | Docs | Ratificar ou agendar decisão sobre AMBIGUITY_NOTES §2 (comentários XML entram no concat) — travado em 9 ports mas ninguém decidiu de propósito | Baixa | — | Baixa | 💡 Decisão tomada | — |

---

## Concluído

| ID | Onda | Grupo | Descrição Técnica | Prioridade | Pré-requisito | Dificuldade | Status | Estado Auditado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| F1.1 | — | Setup | Engenharia reversa do algoritmo TISS hash (3 goldens reais) | Alta | — | Alta | ✅ Concluído | ✓ |
| F1.2 | — | Setup | Fixture de conformidade (15 vetores sintéticos públicos) | Alta | F1.1 | Média | ✅ Concluído | ✓ |
| F1.3 | — | Setup | Mover XMLs reais pra dir privada fora do repo (LGPD) | Alta | F1.2 | Baixa | ✅ Concluído | ✓ |
| F1.4 | — | Setup | Implementação Python de referência + 19 testes passando | Alta | F1.2 | Média | ✅ Concluído | ✓ |
| F1.5 | — | Setup | ADRs 0001-0004 + ARCHITECTURE + SPEC + PORTING_GUIDE | Alta | F1.1 | Média | ✅ Concluído | ✓ |
| F1.6 | — | Setup | LICENSE MIT na raiz | Alta | — | Baixa | ✅ Concluído | ✓ |
| F1.7 | — | Setup | .gitignore (bloqueia real_*.xml, _private_*/, multi-stack) | Alta | — | Baixa | ✅ Concluído | ✓ |
| F1.8 | — | Setup | Substituir langs/python/LICENSE por MIT | Alta | F1.6 | Baixa | ✅ Concluído | ✓ |
| F1.9 | — | Setup | Ajustar langs/python/pyproject.toml (classifier MIT + URLs) | Alta | F1.8 | Baixa | ✅ Concluído | ✓ |
| F2.1 | — | Repos | Criar repo TISS_ANS_hash no GitHub (público) | Alta | F1.6 | Baixa | ✅ Concluído | ✓ |
| F2.2 | — | Repos | Criar repo TISS_ANS_hash no Codeberg (público) | Alta | F1.6 | Baixa | ✅ Concluído | ✓ |
| F2.3 | — | Repos | git init + branch main + dual-push remote | Alta | F1.7, F2.1, F2.2 | Baixa | ✅ Concluído | ✓ |
| F2.4 | — | Repos | Primeiro commit + push aos dois remotes | Alta | F2.3 | Baixa | ✅ Concluído | ✓ |
| F2.5 | — | Repos | Habilitar Discussions no GitHub | Baixa | F2.4 | Baixa | ✅ Concluído | ✓ |
| F2.6 | — | Repos | Topics aos repos (tiss, ans, hash, saude-suplementar, brasil) | Baixa | F2.4 | Baixa | ✅ Concluído | ✓ |
| F3.1 | — | Docs | README com badges + tabela de status linguagens | Alta | F1.4 | Baixa | ✅ Concluído | ✓ |
| F3.2 | — | Docs | docs/USAGE.md (uso completo, exemplos, FAQ) | Alta | F1.4 | Média | ✅ Concluído | ✓ |
| F3.3 | — | Docs | CONTRIBUTING + CODE_OF_CONDUCT + SECURITY + CHANGELOG | Alta | — | Baixa | ✅ Concluído | ✓ |
| F3.4 | — | Docs | Templates .github/ (issues, PR, FUNDING, config) | Média | F2.1 | Baixa | ✅ Concluído | ✓ |
| F3.5 | — | Docs | Templates .forgejo/ (issues, PR) | Média | F2.2 | Baixa | ✅ Concluído | ✓ |
| F3.6 | — | Docs | docs/legal/ (LGPD-NOTE, DISCLAIMER, TISS-COMPLIANCE) | Alta | F1.6 | Média | ✅ Concluído | ✓ |
| F3.7 | — | Docs | CLAUDE.md do projeto (perfil + escopo + regras locais) | Baixa | F2.4 | Baixa | ✅ Concluído | ✓ |
| F4.1 | — | CI | Workflow .github/workflows/python.yml (lint+test+cov) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F4.2 | — | CI | Workflow .forgejo/workflows/python.yml | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F4.2a | — | CI | ~~Habilitação Forgejo Actions Codeberg~~ — runners globais já ativos | Média | F4.2 | Baixa | ✅ Concluído | ✓ |
| F4.3 | — | CI | CI matrix — 6/6 workflows verdes GitHub E Codeberg | Média | F5.1 | Alta | ✅ Concluído | ✓ |
| F4.5 | — | CI | Fix rust.yml (cargo fmt diff) | Média | F5.1 | Média | ✅ Concluído | ✓ |
| F4.6 | — | CI | Fix c.yml Codeberg (clang dropado .forgejo, gcc cobre) | Média | F5.2 | Média | ✅ Concluído | ✓ |
| F4.7 | — | CI | Fix node.yml (glob `**` + drop node18) | Média | F5.4 | Baixa | ✅ Concluído | ✓ |
| F4.8 | — | CI | Fix php.yml (require ^8.2; matrix 8.2/8.3/8.4) | Média | F5.5 | Baixa | ✅ Concluído | ✓ |
| F4.9 | — | CI | Workflows Java/Go/C# — 6 verdes nas 2 plataformas | Alta | F6.1, F6.3, F6.5 | Média | ✅ Concluído | ✓ |
| F5.1 | — | Port Rust | langs/rust/ (crate tiss-hash, 15 vetores PASS) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F5.2 | — | Port C | langs/c/ (libxml2+OpenSSL, CMake+Makefile, ASan+valgrind) | Alta | F2.4 | Alta | ✅ Concluído | ✓ |
| F5.3 | — | Port C++ | langs/cpp/ (pugixml+OpenSSL, doctest, C++20) | Alta | F5.2 | Média | ✅ Concluído | ✓ |
| F5.4 | — | Port Node | langs/node/ (@xmldom/xmldom, ESM+CJS) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F5.5 | — | Port PHP | langs/php/ (DOMDocument stdlib, composer) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F6.1 | — | Port Java | langs/java/ (DocumentBuilder, Maven, JDK 17+) 23/23 PASS | Média | F5.1 | Média | ✅ Concluído | ✓ |
| F6.3 | — | Port C# | langs/csharp/ (XDocument + xUnit, .NET 8) 21/21 PASS | Média | F2.4 | Média | ✅ Concluído | ✓ |
| F6.5 | — | Port Go | langs/go/ (encoding/xml + x/text) 21/21 PASS | Média | F2.4 | Média | ✅ Concluído | ✓ |
| F8.1 | — | SEO (Tier 1) | Reescrever 1ª frase README (keyword density, sem versão TISS) | Alta | F2.4 | Baixa | ✅ Concluído | ✓ |
| F8.2 | — | SEO (Tier 1) | Description repos GitHub+Codeberg (denso, 6 linguagens) | Alta | F2.4 | Baixa | ✅ Concluído | ✓ |
| F8.3 | — | SEO (Tier 1) | +5 topics (library, epilogo, hash-md5, ans-saude, xml-tiss) | Alta | F2.4 | Baixa | ✅ Concluído | ✓ |
| F8.4 | — | SEO (Tier 1) | Seção "Termos relacionados" no README (tag cloud SEO) | Alta | F8.1 | Baixa | ✅ Concluído | ✓ |
| F8.5 | — | SEO (Tier 2) | Sincronizar `keywords` em packaging (10 canon; 5 Rust) | Média | F8.3 | Baixa | ✅ Concluído | ✓ |
| F8.6 | — | SEO (Tier 2) | Seção "Por que existe (história)" no README | Média | F8.1 | Baixa | ✅ Concluído | ✓ |
| A-SEC1 | — | Segurança | XXE no port C — fix `deny_external_entity_loader` via `xmlSetExternalEntityLoader`; `tests/test_xxe.c` regressão; conformance 15/15; valgrind 0 leak; `-Werror` limpo | Alta | — | Baixa | ✅ Concluído | ✓ |
| A-DOC1 | — | Privacidade | Removida TODA PII (3 hashes reais) do repo: SPEC §2/§4/§8/§9/§10 reescrito p/ 15 sintéticos; USAGE.md + READMEs node/php/java + docstring Python trocados p/ hash ilustrativo `syn_minimal`; `build_fixture.py` refatorado — hashes-esperados saíram do script público p/ `<PRIVATE>/expected_hashes.json` (fora do repo). `git grep` dos 3 hashes = vazio | Alta | — | Baixa | ✅ Concluído | ✓ |
| A-DOC2 | — | Docs | Contagem corrigida p/ 15 vetores sintéticos (SPEC, PORTING_GUIDE, TEST_PLAN, Python README); Python README "19 passed (15 conformance + 4 API)" | Alta | — | Média | ✅ Concluído | ✓ |
| A-DOC3 | — | Docs | PORTING_GUIDE `ports/` → `langs/` (texto, árvore, checklist PR); "8/8"→"15/15"; lista 9 ports | Alta | — | Baixa | ✅ Concluído | ✓ |
| A-DOC4 | — | Docs | Python README licença MIT (aponta LICENSE raiz) + URLs canônicas GitHub/Codeberg + seção "Ver também". **Resolve F1.10** | Alta | F1.6 | Baixa | ✅ Concluído | ✓ |
| F1.10 | — | Setup | Atualizar langs/python/README.md (MIT + URLs) — fechado via A-DOC4 | Média | F1.8 | Baixa | ✅ Concluído | ✓ |
| A-LEG1 | — | Legal | Criado `THIRD_PARTY_LICENSES.md` (atribuição 3rd-party por port; runtime vs test-only; doctest versionado atribuído). Nome escolhido sobre `NOTICE` (semântica Apache-2.0) | Alta | — | Baixa | ✅ Concluído | ✓ |
| A-LEG4 | — | Legal | vendor/ node_modules/ .venv/ NÃO no índice git — git ls-files limpo | Baixa | — | Baixa | ✅ Concluído | ✓ |
| A-COV1 | — | Conformance | Vetor `syn_default_ns.xml` (namespace default `xmlns=` sem prefixo). Todos os 9 ports já casam `<hash>` por URI → PASS sem fix | Alta | — | Baixa | ✅ Concluído | ✓ |
| A-COV2 | — | Conformance | Multi-hash FIXADO = **rejeitar** (decisão líder). reference.py `findall`+raise; 9 ports rejeitam via erro de XML inválido; vetor negativo `syn_multi_hash.xml` (`expect:error`); AMBIGUITY §9 reescrito | Média | — | Baixa | ✅ Concluído | ✓ |
| A-COV3 | — | Conformance | Vetor `syn_sem_hash.xml` (sem `<ans:hash>` = VÁLIDO, concatena tudo). 9 ports PASS sem erro | Média | — | Baixa | ✅ Concluído | ✓ |
| A-COV4 | — | Conformance | Vetor `syn_entidade_numerica.xml` (`&#xE9;` hex + `&#231;&#227;` dec). 9 ports PASS (parser decodifica) | Baixa | — | Baixa | ✅ Concluído | ✓ |
| A-COV5 | — | Conformance | UTF-16/UTF-32 FIXADO = **rejeitar** (escopo ISO-8859-1+UTF-8). reference + 9 ports detectam BOM e rejeitam; vetor negativo `syn_utf16.xml`; AMBIGUITY §11b + SPEC §2/§7 | Baixa | — | Baixa | ✅ Concluído | ✓ |
| A-DOC5 | — | Docs | README raiz: 9 ports prontos (✅), "6"→"9 ports", árvore lista os 9, contagem→20 vetores | Média | — | Baixa | ✅ Concluído | ✓ |
| A-DOC6 | — | Docs | README raiz: `langs/nodejs/`→`langs/node/`; árvore Estrutura com 9 ports; "LICENSE a criar"→existe MIT | Média | — | Baixa | ✅ Concluído | ✓ |
| A-DOC7 | — | Docs | README badges: removido badge Woodpecker 404 + badge python.yml; substituído por "CI: GitHub Actions + Forgejo Actions" textual (sem URL inventada) | Média | F4.9 | Baixa | ✅ Concluído | ✓ |
| A-DOC8 | — | Docs | USAGE.md: bloco de uso pros 9 ports (removido "em breve"); contagem→20; API real verificada por linguagem | Média | — | Média | ✅ Concluído | ✓ |
| A-DOC9 | — | Docs | CHANGELOG: Unreleased com 8 ports Tier 2 + expansão 5→15→20 vetores + rejeições + remoção PII + THIRD_PARTY_LICENSES | Média | — | Baixa | ✅ Concluído | ✓ |
| A-LEG2 | — | Legal | Seção "Dependências e licenças" nos READMEs C/Go/Node/Rust (aponta THIRD_PARTY_LICENSES; OpenSSL Apache-2.0 atribuído no C) | Média | A-LEG1 | Baixa | ✅ Concluído | ✓ |
| A-LEG3 | — | Legal | Versão TISS "4.01.00" removida de TUDO (5 da lista + 12 extras: READMEs, comentários código, CMakeLists, USAGE, LGPD-NOTE, TISS-COMPLIANCE). `git grep 4.01` = só falsos-positivos | Média | — | Baixa | ✅ Concluído | ✓ |
| A-DOC10 | — | Docs | Memória atualizada: reference.py=lxml (oracle) vs port Python=xml.etree+defusedxml; comentário-no-concat = artefato lxml.iter congelado | Baixa | — | Baixa | ✅ Concluído | ✓ |
| A-DOC12 | — | Docs | ADR-0005 criado: nomenclatura `hash_tiss`, groupId `dev.petrus`, convenção `<lang>.yml`; emenda 0003/0004 (ponteiro, sem reescrever) | Baixa | — | Baixa | ✅ Concluído | ✓ |
| A-DOC13 | — | Docs | ADR-0004 workflows reconciliados no ADR-0005 (sem conformance.yml/release-*.yml; `<lang>.yml` nas 2 plataformas) | Baixa | — | Baixa | ✅ Concluído | ✓ |
| A-DOC14 | — | Docs | "3 goldens reais" suavizado em prosa READMEs rust/node/php (sem hash, sem nome de arquivo PII) | Baixa | — | Baixa | ✅ Concluído | ✓ |
| A-CI1 | — | CI | ASan+UBSan no cpp.yml (Debug) espelhando c.yml; ASAN/UBSAN_OPTIONS estritos. .github+.forgejo | Média | F5.3 | Baixa | ✅ Concluído | ✓ |
| A-CI2 | — | CI | Matrix gcc+clang × Debug+Release em C e C++ (.github); .forgejo só gcc (libclang-rt do catthehacker não bate com sanitizer) | Média | F5.3 | Baixa | ✅ Concluído | ✓ |
| A-CI3 | — | CI | Lint gate: Node eslint, PHP phpstan(lvl6), Java checkstyle(0 viol), C# dotnet format, C/C++ **clang-tidy** (0 warn). clang-format DROPADO (version-frágil; redaria CI). Rust/Go/Python já tinham | Média | — | Média | ✅ Concluído | ✓ |
| A-CI4 | — | CI | Coverage non-gating: c8(node), jacoco(java), coverlet(c#), tarpaulin(rust), go -cover, pytest-cov, phpunit(.github). Só mede, sem threshold | Baixa | — | Média | ✅ Concluído | ✓ |
| A-CI5 | — | CI | C/C++ test runner lê env `TISS_CONFORMANCE_DIR` (robusto a CWD); fallback default | Baixa | — | Baixa | ✅ Concluído | ✓ |
| A-SUP1 | — | Supply-chain | `.github/dependabot.yml` 8 ecosystems (pip/npm/cargo/composer/maven/gomod/nuget/gh-actions), semanal | Média | — | Baixa | ✅ Concluído | ✓ |
| A-SUP2 | — | Supply-chain | CVE gate por port: npm/composer/cargo audit, govulncheck, pip-audit, dotnet --vulnerable; Java=versions watch (dependency-check pesado). Todos limpos hoje | Média | — | Média | ✅ Concluído | ✓ |
| A-SUP3 | — | Supply-chain | golang.org/x/text v0.14→**v0.21** (não @latest=v0.37: exige Go 1.25, quebraria matrix 1.22). go test verde | Baixa | — | Baixa | ✅ Concluído | ✓ |
| A-QA1 | — | QA | cargo-mutants no core Rust: 43 mutantes, 35 mortos, 4 sobreviventes (asserts fracos, doc em A-QA2), 89.7% kill. Job manual non-blocking (.github workflow_dispatch) | Baixa | — | Média | ✅ Concluído | ✓ |

---

## Resumo

- **Concluído:** 79 itens (algoritmo, fixture **20 vetores** [18 positivos + 2 negativos], 9 ports byte-a-byte + rejeições, CI hardened [sanitizers, clang-tidy, coverage, CVE gate, dependabot], repos públicos dual-push, docs, ADRs 0001-0005, SEO Tier 1+2, A-SEC1 XXE, **W1+W2+W3+W4**, A-LEG4).
- **Auditoria bigtech 2026-05-28:** 0 achado que quebra o algoritmo (núcleo SÓLIDO). 31 achados; **A-SEC1 + W1 (5) + W2 (5) + W3 (11) + W4 (9) + A-LEG4 = 32 fechados** (1 follow-up novo A-QA2). **Todos os achados de auditoria fechados**; resta só release (W5) + pós-release (W6). **Nenhum CRÍTICO restante** — v0.1.0 pronta.
- **W4 (2026-05-28):** hardening CI. ASan/UBSan(cpp), matrix gcc+clang×Debug+Release(C/C++), lint gate 9 ports (clang-tidy/eslint/phpstan/checkstyle/dotnet-format; clang-format dropado por version-fragilidade), coverage non-gating, dependabot 8 ecosystems, CVE gate por port (todos limpos), cargo-mutants (89.7% kill, 4 survivors→A-QA2), bump x/text→0.21. Verificado local: C 20/20+clang-tidy 0, C++ ctest+clang-tidy 0, Java checkstyle 0+26... (Java 28/C# 26 test), Node/PHP/Rust/Go/Python por agents. Nota: CI real valida nos 2 hosts (push).
- **W3 (2026-05-28):** accuracy de docs/legal. README raiz (9 ports, badges sem 404), USAGE 9 ports, CHANGELOG, ADR-0005 (nomenclatura/CI), atribuição 3rd-party por port, **remoção total da versão TISS "4.01.00"** (17 ocorrências), contagem 15→20 em todas as docs/READMEs, suavização goldens, memória A-DOC10. `git grep 4.01` e `15/15` limpos.

### Ondas de execução (paralelizáveis dentro da onda)

| Onda | Foco | Itens | Gate |
| :--- | :--- | :--- | :--- |
| ~~**W1**~~ | ~~CRÍTICOS doc/legal~~ | ✅ A-DOC1, A-LEG1, A-DOC4/F1.10, A-DOC3, A-DOC2 | **FECHADA** |
| ~~**W2**~~ | ~~Robustez conformance~~ | ✅ A-COV1-5 (3 vetores positivos + 2 negativos; reject multi-hash + UTF-16) | **FECHADA** |
| ~~**W3**~~ | ~~Docs/legal accuracy~~ | ✅ A-DOC5/6/7/8/9/10/12/13/14 + A-LEG2/3 (+ ADR-0005) | **FECHADA** |
| ~~**W4**~~ | ~~Hardening CI + supply-chain~~ | ✅ A-CI1-5 + A-SUP1-3 + A-QA1 (sanitizers, clang-tidy lint, coverage, dependabot, CVE gate, mutation) | **FECHADA** |
| **W5** | Release v0.1.0 | F7.1 → F4.4 → F7.2 → A-REL1 | PyPI + GitHub/Codeberg + SBOM |
| **W6** | Pós-release | F7.3/7.4, F8.7-8.10, F6.2/4/6/7, F4.2b, A-DOC11, A-QA2 | ports restantes, SEO Tier 3, anúncio |

- **Ordem de ataque:** W1-W4 ✅ FECHADAS (auditoria inteira) → **W5 = release v0.1.0** → W6 expande pós-release.
- **Caminho crítico p/ v0.1.0:** W5 (F7.1 → F7.2). Tudo que bloqueava já fechou; resta empacotar e publicar.
