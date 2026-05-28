# TISS_ANS_hash — Planejamento

Tabela canônica de pendências do projeto. Atualizar via `/tab_pendencias`.

Convenções: F1-F7 = fases. Status: ✅ Concluído / 🔄 Em andamento / 🟡 Parcial / ⏳ Pendente / 💡 Decisão tomada / 🎨 Pendente design / 🔍 Pendente verificação.

| ID | Grupo | Descrição Técnica | Prioridade | Pré-requisito | Dificuldade | Status | Estado Auditado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| F1.1 | Setup | Engenharia reversa do algoritmo TISS hash (3 goldens reais) | Alta | — | Alta | ✅ Concluído | ✓ |
| F1.2 | Setup | Fixture de conformidade (15 vetores sintéticos públicos) | Alta | F1.1 | Média | ✅ Concluído | ✓ |
| F1.3 | Setup | Mover XMLs reais pra dir privada fora do repo (LGPD) | Alta | F1.2 | Baixa | ✅ Concluído | ✓ |
| F1.4 | Setup | Implementação Python de referência + 19 testes passando | Alta | F1.2 | Média | ✅ Concluído | ✓ |
| F1.5 | Setup | ADRs 0001-0004 + ARCHITECTURE + SPEC + PORTING_GUIDE | Alta | F1.1 | Média | ✅ Concluído | ✓ |
| F1.6 | Setup | LICENSE MIT na raiz | Alta | — | Baixa | ✅ Concluído | ✓ |
| F1.7 | Setup | .gitignore (bloqueia real_*.xml, _private_*/, multi-stack) | Alta | — | Baixa | ✅ Concluído | ✓ |
| F1.8 | Setup | Substituir langs/python/LICENSE por MIT | Alta | F1.6 | Baixa | ✅ Concluído | ✓ |
| F1.9 | Setup | Ajustar langs/python/pyproject.toml (classifier MIT + URLs reais GitHub/Codeberg) | Alta | F1.8 | Baixa | ✅ Concluído | ✓ |
| F1.10 | Setup | Atualizar langs/python/README.md (mencionar MIT + URLs) | Média | F1.8 | Baixa | ⏳ Pendente | — |
| F2.1 | Repos | Criar repo TISS_ANS_hash no GitHub (público) | Alta | F1.6 | Baixa | ✅ Concluído | ✓ |
| F2.2 | Repos | Criar repo TISS_ANS_hash no Codeberg (público) | Alta | F1.6 | Baixa | ✅ Concluído | ✓ |
| F2.3 | Repos | git init + branch main + configurar dual-push remote | Alta | F1.7, F2.1, F2.2 | Baixa | ✅ Concluído | ✓ |
| F2.4 | Repos | Primeiro commit (feat inicial) + push aos dois remotes | Alta | F2.3 | Baixa | ✅ Concluído | ✓ |
| F2.5 | Repos | Habilitar Discussions no GitHub | Baixa | F2.4 | Baixa | ✅ Concluído | ✓ |
| F2.6 | Repos | Adicionar topics aos repos (tiss, ans, hash, saude-suplementar, brasil) | Baixa | F2.4 | Baixa | ✅ Concluído | ✓ |
| F3.1 | Docs | README com badges + tabela de status linguagens | Alta | F1.4 | Baixa | ✅ Concluído | ✓ |
| F3.2 | Docs | docs/USAGE.md (uso completo, exemplos, FAQ) | Alta | F1.4 | Média | ✅ Concluído | ✓ |
| F3.3 | Docs | CONTRIBUTING.md + CODE_OF_CONDUCT.md + SECURITY.md + CHANGELOG.md | Alta | — | Baixa | ✅ Concluído | ✓ |
| F3.4 | Docs | Templates .github/ (issues, PR, FUNDING, config) | Média | F2.1 | Baixa | ✅ Concluído | ✓ |
| F3.5 | Docs | Templates .forgejo/ (issues, PR) | Média | F2.2 | Baixa | ✅ Concluído | ✓ |
| F3.6 | Docs | docs/legal/ (LGPD-NOTE, DISCLAIMER, TISS-COMPLIANCE) — MIT adaptado | Alta | F1.6 | Média | ✅ Concluído | ✓ |
| F3.7 | Docs | CLAUDE.md do projeto (perfil + escopo + regras locais) | Baixa | F2.4 | Baixa | ✅ Concluído | ✓ |
| F4.1 | CI | Workflow .github/workflows/python.yml (lint+test+coverage) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F4.2 | CI | Workflow .forgejo/workflows/python.yml | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F4.2a | CI | ~~Solicitar habilitação Forgejo Actions Codeberg~~ — desnecessário; runners codeberg-small/medium globais já ativos por default | Média | F4.2 | Baixa | ✅ Concluído | ✓ |
| F4.2b | CI | Alternativa self-host forgejo-runner (backup) | Baixa | F4.2 | Média | ⏳ Pendente | — |
| F4.3 | CI | Workflow CI matrix — 6/6 workflows verdes em GitHub E Codeberg (python, cpp, c, rust, node, php) | Média | F5.1 | Alta | ✅ Concluído | ✓ |
| F4.5 | CI | Fix rust.yml (cargo fmt diff em tests/conformance.rs:38-40) | Média | F5.1 | Média | ✅ Concluído | ✓ |
| F4.6 | CI | Fix c.yml Codeberg (clang dropado da matrix .forgejo, gcc cobre; GitHub mantém gcc+clang) — run #4311698 PASS | Média | F5.2 | Média | ✅ Concluído | ✓ |
| F4.7 | CI | Fix node.yml (glob `**` não expandia; matrix drop node18) | Média | F5.4 | Baixa | ✅ Concluído | ✓ |
| F4.8 | CI | Fix php.yml (require ^8.2 — codigo usa `static fn(): null`; matrix 8.2/8.3/8.4) | Média | F5.5 | Baixa | ✅ Concluído | ✓ |
| F4.9 | CI | Workflows .github + .forgejo pros 3 ports Tier 2: Java (mvn matrix 17/21), Go (matrix 1.22/1.23), C# (.NET 8) — 6 workflows verdes nas 2 plataformas; armadilhas (apt install maven; drop tidy -diff) documentadas no cookbook global | Alta | F6.1, F6.3, F6.5 | Média | ✅ Concluído | ✓ |
| F4.4 | CI | Release automation (PyPI via trusted publishing) | Média | F7.1 | Média | ⏳ Pendente | — |
| F5.1 | Port Rust | langs/rust/ (quick-xml ou roxmltree, crate tiss-hash, 15 vetores PASS) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F5.2 | Port C | langs/c/ (libxml2 + OpenSSL EVP MD5, CMake + Makefile + pkg-config, ASan+valgrind clean) | Alta | F2.4 | Alta | ✅ Concluído | ✓ |
| F5.3 | Port C++ | langs/cpp/ (pugixml + OpenSSL EVP, CMake, doctest, C++20) | Alta | F5.2 | Média | ✅ Concluído | ✓ |
| F5.4 | Port Node | langs/node/ (@xmldom/xmldom, ESM+CJS, tiss-hash NPM) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F5.5 | Port PHP | langs/php/ (DOMDocument stdlib, composer package) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F6.1 | Port Java | langs/java/ (DocumentBuilder stdlib, Maven, JDK 17+ alvo) — 23/23 PASS (15 conformance + 8 aux) | Média | F5.1 | Média | ✅ Concluído | ✓ |
| F6.2 | Port Kotlin | langs/kotlin/ ou compartilhado com Java via JVM | Média | F6.1 | Baixa | ⏳ Pendente | — |
| F6.3 | Port C# | langs/csharp/ (XDocument stdlib + xUnit, .NET 8) — 21/21 PASS | Média | F2.4 | Média | ✅ Concluído | ✓ |
| F6.4 | Port Delphi | langs/delphi/ (Object Pascal, OmniXML/MSXML, FPC compat) | Média | F2.4 | Alta | ⏳ Pendente | — |
| F6.5 | Port Go | langs/go/ (encoding/xml stdlib + golang.org/x/text, module) — 21/21 PASS | Média | F2.4 | Média | ✅ Concluído | ✓ |
| F6.6 | Port Dart | langs/dart/ (package:xml, pub.dev) | Baixa | F2.4 | Média | ⏳ Pendente | — |
| F6.7 | Port WASM | langs/wasm/ (Rust core compilado, browser-side, LGPD-friendly) | Baixa | F5.1 | Alta | 💡 Decisão tomada | — |
| F7.1 | Release | Tag v0.1.0 Python + publicar PyPI | Alta | F1.9, F4.1 | Baixa | ⏳ Pendente | — |
| F7.2 | Release | Release v0.1.0 no GitHub + Codeberg (notes + checksums) | Alta | F7.1 | Baixa | ⏳ Pendente | — |
| F7.3 | Release | Anúncio (DEV.to, LinkedIn, fórum de saúde suplementar BR) | Baixa | F7.2 | Baixa | ⏳ Pendente | — |
| F7.4 | Release | Submeter pacote pra mirrors (conda-forge se aplicável) | Baixa | F7.1 | Baixa | ⏳ Pendente | — |
| F8.1 | SEO (Tier 1) | Reescrever primeira frase do README maximizando keyword density (Python, Rust, C, C++, Node, PHP, hash MD5, epílogo XML, Padrão TISS/ANS, saúde suplementar BR) — SEM versão TISS (muda anualmente) | Alta | F2.4 | Baixa | ✅ Concluído | ✓ |
| F8.2 | SEO (Tier 1) | Reescrever description dos repos GitHub+Codeberg (denso, 121 chars, com nomes das 6 linguagens; sem versão TISS) | Alta | F2.4 | Baixa | ✅ Concluído | ✓ |
| F8.3 | SEO (Tier 1) | Adicionar 5 topics extras: library, epilogo, hash-md5, ans-saude, xml-tiss (vai pra 16/20; tiss-401 evitado — versão muda anualmente) | Alta | F2.4 | Baixa | ✅ Concluído | ✓ |
| F8.4 | SEO (Tier 1) | Seção "Termos relacionados" no README com aliases (hash tiss ans, calculo hash padrao tiss, md5 epilogo tiss, etc) — vira tag cloud SEO | Alta | F8.1 | Baixa | ✅ Concluído | ✓ |
| F8.5 | SEO (Tier 2) | Sincronizar `keywords` em pyproject.toml/package.json/Cargo.toml/composer.json (10 canon Python/Node/PHP; 5 Rust por limite crates.io) | Média | F8.3 | Baixa | ✅ Concluído | ✓ |
| F8.6 | SEO (Tier 2) | Seção "Por que existe (história)" no README — problema encoding ANS, 3 goldens, manual ambíguo, cross-port equivalence (matches semânticos pra dúvidas reais) | Média | F8.1 | Baixa | ✅ Concluído | ✓ |
| F8.7 | SEO (Tier 3) | Submit PR awesome-brasil + awesome-health-tech + awesome-tiss (se existir) | Baixa | F7.1 | Baixa | ⏳ Pendente | — |
| F8.8 | SEO (Tier 3) | Blog post anúncio: DEV.to + LinkedIn + fóruns TI saúde suplementar BR | Baixa | F7.1 | Média | ⏳ Pendente | — |
| F8.9 | SEO (Tier 3) | GitHub Pages site (Hugo/MkDocs) com domínio próprio ou subpath github.io | Baixa | F8.1 | Média | ⏳ Pendente | — |
| F8.10 | SEO (Tier 3) | Submit conda-forge (overlap c/ F7.4) | Baixa | F7.1 | Baixa | ⏳ Pendente | — |

## Fase 9 — Auditoria bigtech (2026-05-28)

Pipeline `/bigtech` porte=solo (elevação cirúrgica CISO+CLO). 4 frentes paralelas: qa-engineer (técnico), compliance-legal (LGPD/licença), devops-sre (supply-chain/CI/release), technical-writer (docs). Achados por severidade.

### CRÍTICO (bloqueia release v0.1.0)

| ID | Grupo | Descrição Técnica | Prioridade | Pré-requisito | Dificuldade | Status | Estado Auditado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| A-SEC1 | Segurança | XXE explorável no port C — `XML_PARSE_NONET` não bloqueia `file://`; com `NOENT` payload `<!ENTITY xxe SYSTEM "file:///etc/passwd">` vaza arquivo local (comprovado empírico). Fix: `xmlSetExternalEntityLoader(deny)` em `tiss_hash_init_libxml` (tiss_hash.c:90) + vetor regressão XXE | Alta | — | Baixa | ⏳ Pendente | ⚠ |
| A-DOC1 | Privacidade | `docs/SPEC.md` §8/§2/§10 EXPÕE hashes dos 3 XMLs reais (adc506.../df52c4.../6f3349...) e os lista como vetores públicos — vazamento indireto de PII, contradiz política LGPD. Remover hashes reais, listar os 15 sintéticos | Alta | — | Baixa | ⏳ Pendente | ⚠ |
| A-DOC2 | Docs | Contagem falsa de vetores em docs: SPEC "8 vetores/5 sintéticos", PORTING_GUIDE "8/8", TEST_PLAN "18 vetores/3 reais no manifesto", Python README "8 passed". Real = 15 sintéticos. Instruções enganam quem porta/valida | Alta | — | Média | ⏳ Pendente | ⚠ |
| A-DOC3 | Docs | `docs/PORTING_GUIDE.md` manda usar diretório `ports/<lang>/` inexistente (canônico = `langs/`). Quem segue cria no lugar errado | Alta | — | Baixa | ⏳ Pendente | ⚠ |
| A-LEG1 | Legal | `NOTICE` referenciado em CLAUDE.md+snapshot mas NÃO existe. C++ embarca doctest (MIT) + pugixml (MIT); C usa libxml2+OpenSSL(Apache-2.0) — atribuição de terceiros exigida ao distribuir. Criar NOTICE/THIRD_PARTY_LICENSES OU corrigir docs | Alta | — | Baixa | ⏳ Pendente | ⚠ |
| A-DOC4 | Docs | `langs/python/README.md` licença = placeholder "a cargo do compliance-legal" + sem URLs canônicas (F1.10 nunca resolvida); LICENSE raiz já é MIT real. Único port com licença em placeholder | Alta | F1.6 | Baixa | ⏳ Pendente | ⚠ |

### IMPORTANTE (qualidade / release-readiness)

| ID | Grupo | Descrição Técnica | Prioridade | Pré-requisito | Dificuldade | Status | Estado Auditado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| A-COV1 | Conformance | Vetor `syn_default_ns.xml` (namespace default sem prefixo `ans:`) — risco ALTO: ports que casam `<ans:hash>` por string de prefixo falham; gerador TISS pode emitir sem prefixo | Alta | — | Baixa | ⏳ Pendente | — |
| A-COV2 | Conformance | Decidir comportamento + vetor `syn_multi_hash.xml` (múltiplos `<ans:hash>`) — AMBIGUITY_NOTES §9 "não-fixado"; ports divergem silenciosos (getElementsByTagName vs .find) | Média | — | Baixa | ⏳ Pendente | — |
| A-COV3 | Conformance | Vetor `syn_sem_hash.xml` (documento sem `<ans:hash>`) — caminho "hash ausente" não exercitado; ports que assumem presença podem dar NPE/panic | Média | — | Baixa | ⏳ Pendente | — |
| A-COV4 | Conformance | Vetor `syn_entidade_numerica.xml` (`&#xE9;`/`&#233;` → `é`) — entidade de caractere numérica não coberta; complementa syn_acento | Baixa | — | Baixa | ⏳ Pendente | — |
| A-COV5 | Conformance | Decidir suporte UTF-16 (vetor ou rejeição documentada) — ports com detecção manual de encoding (Rust/Node/Go) só tratam iso/utf-8 | Baixa | — | Baixa | ⏳ Pendente | — |
| A-CI1 | CI | ASan+UBSan no `cpp.yml` (espelhar c.yml) — C++ com pugixml+walker manual é onde sanitizer pega bug; infra local existe (build_san) mas não está no CI | Média | F5.3 | Baixa | ⏳ Pendente | — |
| A-CI2 | CI | clang na matrix C++ + Release em C/C++ (hoje C++ só g++-13 Debug; C só Debug) | Média | F5.3 | Baixa | ⏳ Pendente | — |
| A-CI3 | CI | Lint gate nos 6 ports sem lint (PHP phpstan/phpcs, C/C++ clang-tidy+format, Node eslint, Java checkstyle/spotbugs, C# dotnet format). Só Python/Rust/Go têm | Média | — | Média | ⏳ Pendente | — |
| A-CI4 | CI | Coverage diferencial + baseline onde barato (tarpaulin Rust, go test -cover, jacoco Java, c8 Node, coverlet C#); hoje só Python mede, PHP tem coverage:none | Baixa | — | Média | ⏳ Pendente | — |
| A-SUP1 | Supply-chain | `.github/dependabot.yml` multi-ecosystem (pip/npm/cargo/composer/maven/gomod/nuget/gh-actions) — sem update automático de deps | Média | — | Baixa | ⏳ Pendente | — |
| A-SUP2 | Supply-chain | Gate de CVE por port em CI (pip-audit/npm audit/cargo audit/govulncheck/composer audit/dotnet --vulnerable) — hoje zero scan, regride silencioso | Média | — | Média | ⏳ Pendente | — |
| A-LEG2 | Legal | Padronizar seção "Dependências e licenças" nos READMEs de C, Go, Node, Rust (C++ já tem); OpenSSL Apache-2.0 exige atribuição | Média | A-LEG1 | Baixa | ⏳ Pendente | — |
| A-LEG3 | Legal | Versão TISS "4.01.00" hard-coded em packaging (Cargo/npm/composer/pom) + TISS-COMPLIANCE.md contradiz decisão de remover versão; risco de afirmação enganosa quando ANS publicar nova | Média | — | Baixa | ⏳ Pendente | — |
| A-DOC5 | Docs | README raiz tabela de status: 9 ports prontos marcados como "planejado"; "6 ports" deveria ser "9 ports". Subvende o projeto | Média | — | Baixa | ⏳ Pendente | — |
| A-DOC6 | Docs | README raiz: caminho `langs/nodejs/` quebrado (real = `langs/node/`); árvore "Estrutura" lista só python/; "LICENSE (a criar inline)" desatualizado | Média | — | Baixa | ⏳ Pendente | — |
| A-DOC7 | Docs | README badges: badge Codeberg/Woodpecker tende 404 (CI real é Forgejo Actions, sem .woodpecker.yml); GitHub badge aponta só python.yml de 9 | Média | F4.9 | Baixa | ⏳ Pendente | — |
| A-DOC8 | Docs | `docs/USAGE.md` documenta só Python; 8 ports prontos marcados "em breve" | Média | — | Média | ⏳ Pendente | — |
| A-DOC9 | Docs | CHANGELOG parou no 0.1.0 (só Python); Unreleased vazio; 8 ports Tier 2 + expansão 5→15 vetores ausentes | Média | — | Baixa | ⏳ Pendente | — |
| A-LEG4 | Legal | Confirmar que vendor/ node_modules/ .venv/ NÃO estão no índice git — VERIFICADO: git ls-files limpo, zero artefato trackeado | Baixa | — | Baixa | ✅ Concluído | ✓ |

### COSMÉTICO

| ID | Grupo | Descrição Técnica | Prioridade | Pré-requisito | Dificuldade | Status | Estado Auditado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| A-DOC10 | Docs | Memória + CLAUDE.md dizem Python ref usa "xml.etree+defusedxml"; `reference.py` usa lxml. Importa: ambiguidade #2 (comentários no concat) é subproduto do `lxml.iter()` | Baixa | — | Baixa | ⏳ Pendente | — |
| A-DOC11 | Docs | Ratificar ou agendar decisão sobre AMBIGUITY_NOTES §2 (comentários XML entram no concat) — marcado "não-intencional"; travado em 9 ports mas ninguém decidiu de propósito | Baixa | — | Baixa | 💡 Decisão tomada | — |
| A-CI5 | CI | C/C++ test runner depende de CWD pra achar conformance/inputs (falha se rodado fora do ctest); dar resolução robusta (env TISS_CONFORMANCE_DIR) | Baixa | — | Baixa | ⏳ Pendente | — |
| A-DOC12 | Docs | ADR-0003 cita `hash_tiss_bytes`/`HashTissBytes`; impl real = `hash_tiss`/`HashTiss`. groupId Maven `br.dev.petrus` (ADR) vs `dev.petrus` (Java README) — fixar um. Abrir ADR-0005 | Baixa | — | Baixa | ⏳ Pendente | — |
| A-DOC13 | Docs | ADR-0004 cita workflows `lang-<x>.yml`+`conformance.yml`+`release-*.yml`; reais = `<x>.yml` sem extras. Nota de superseção / ADR-0005 | Baixa | — | Baixa | ⏳ Pendente | — |
| A-REL1 | Release | SBOM (syft/cyclonedx) + SHA256SUMS no release GitHub/Codeberg (F7.2 prevê mas nada existe); assinatura GPG nice-to-have | Baixa | F7.2 | Média | ⏳ Pendente | — |
| A-SUP3 | Supply-chain | Bump preventivo `golang.org/x/text` v0.14→latest (govulncheck hoje clean, ~6 versões atrás) | Baixa | — | Baixa | ⏳ Pendente | — |
| A-DOC14 | Docs | Suavizar menção a "3 goldens reais" em prosa nos README rust/node/php (sem hash exposto, só contagem) | Baixa | — | Baixa | ⏳ Pendente | — |
| A-QA1 | QA | Mutation testing onde barato (cargo-mutants/mutmut/stryker) sobre função core pra revelar asserts que passam por inércia | Baixa | — | Média | ⏳ Pendente | — |

## Resumo

- **Concluído:** 46 itens (algoritmo, fixture, 9 ports 15/15, 18 jobs CI verdes, repos públicos dual-push, docs, ADRs, SEO Tier 1+2).
- **Auditoria bigtech 2026-05-28:** 0 achado que quebra o algoritmo (núcleo SÓLIDO, 9/9 ports byte-a-byte). **6 CRÍTICOS** pré-release: A-SEC1 (XXE port C, comprovado), A-DOC1 (SPEC vaza hash real/PII), A-DOC2/3 (docs com contagem falsa + dir errado), A-LEG1 (NOTICE ausente), A-DOC4 (Python README licença placeholder).
- **Ordem de ataque sugerida:** A-SEC1 (segurança, bloqueia tudo) → A-DOC1 (PII) → A-LEG1+A-DOC4 (licença/atribuição) → A-DOC2/3 (docs falsas) → A-COV1 (vetor namespace default, maior risco de divergência) → resto IMPORTANTE → release F7.
- **Não-bloqueante pós-release:** ports F6.x restantes (Kotlin/Delphi/Dart/WASM), SEO Tier 3, mutation testing.
