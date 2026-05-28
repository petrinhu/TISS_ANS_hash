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
| F4.2 | CI | Workflow .forgejo/workflows/python.yml | Alta | F2.4 | Média | 🟡 Parcial | ⚠ |
| F4.2a | CI | Solicitar habilitação Forgejo Actions público no Codeberg (form: codeberg.org/Codeberg-e.V./requests) — runners não pegam fila sem aprovação | Média | F4.2 | Baixa | ⏳ Pendente | — |
| F4.2b | CI | Alternativa: self-host forgejo-runner em máquina própria pra evitar fila pública | Baixa | F4.2 | Média | ⏳ Pendente | — |
| F4.3 | CI | Workflow CI matrix (futuro: roda todo port contra vectors.json) | Média | F5.1 | Alta | 💡 Decisão tomada | — |
| F4.4 | CI | Release automation (PyPI via trusted publishing) | Média | F7.1 | Média | ⏳ Pendente | — |
| F5.1 | Port Rust | langs/rust/ (quick-xml ou roxmltree, crate tiss-hash, 15 vetores PASS) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F5.2 | Port C | langs/c/ (libxml2 + OpenSSL EVP MD5, CMake + Makefile + pkg-config, ASan+valgrind clean) | Alta | F2.4 | Alta | ✅ Concluído | ✓ |
| F5.3 | Port C++ | langs/cpp/ (pugixml + OpenSSL EVP, CMake, doctest, C++20) | Alta | F5.2 | Média | ✅ Concluído | ✓ |
| F5.4 | Port Node | langs/node/ (@xmldom/xmldom, ESM+CJS, tiss-hash NPM) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F5.5 | Port PHP | langs/php/ (DOMDocument stdlib, composer package) | Alta | F2.4 | Média | ✅ Concluído | ✓ |
| F6.1 | Port Java | langs/java/ (Maven, javax.xml stdlib) | Média | F5.1 | Média | ⏳ Pendente | — |
| F6.2 | Port Kotlin | langs/kotlin/ ou compartilhado com Java via JVM | Média | F6.1 | Baixa | ⏳ Pendente | — |
| F6.3 | Port C# | langs/csharp/ (.NET 8, NuGet) | Média | F2.4 | Média | ⏳ Pendente | — |
| F6.4 | Port Delphi | langs/delphi/ (Object Pascal, OmniXML/MSXML, FPC compat) | Média | F2.4 | Alta | ⏳ Pendente | — |
| F6.5 | Port Go | langs/go/ (encoding/xml stdlib, go module) | Média | F2.4 | Média | ⏳ Pendente | — |
| F6.6 | Port Dart | langs/dart/ (package:xml, pub.dev) | Baixa | F2.4 | Média | ⏳ Pendente | — |
| F6.7 | Port WASM | langs/wasm/ (Rust core compilado, browser-side, LGPD-friendly) | Baixa | F5.1 | Alta | 💡 Decisão tomada | — |
| F7.1 | Release | Tag v0.1.0 Python + publicar PyPI | Alta | F1.9, F4.1 | Baixa | ⏳ Pendente | — |
| F7.2 | Release | Release v0.1.0 no GitHub + Codeberg (notes + checksums) | Alta | F7.1 | Baixa | ⏳ Pendente | — |
| F7.3 | Release | Anúncio (DEV.to, LinkedIn, fórum de saúde suplementar BR) | Baixa | F7.2 | Baixa | ⏳ Pendente | — |
| F7.4 | Release | Submeter pacote pra mirrors (conda-forge se aplicável) | Baixa | F7.1 | Baixa | ⏳ Pendente | — |

## Resumo

- **Concluído:** 16 (algoritmo, fixture, lib Python, docs canônicos, ADRs, repos criados, LICENSE/gitignore raiz, templates).
- **Pendência crítica imediata:** F1.8 → F1.9 → F2.3 → F2.4 (ajustes Python + git setup + primeiro push duplo).
- **Próxima onda:** F4.1-F4.2 (CI) + F5.1-F5.5 (Tier 1 ports).
- **Médio prazo:** F6.x (Tier 2) + F7.x (release).
