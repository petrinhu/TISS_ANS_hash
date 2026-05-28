# CLAUDE.md — TISS_ANS_hash

Instruções para Claude Code ao trabalhar neste repo.

## Projeto

`TISS_ANS_hash` é biblioteca multi-linguagem do hash MD5 do epílogo XML TISS/ANS (Padrão TISS). Sucessor do TISSGama (editor desktop legado arquivado).

- Site canônico (origin): https://github.com/petrinhu/TISS_ANS_hash
- Mirror: https://codeberg.org/petrinhu/TISS_ANS_hash
- Licença: MIT
- Predecessor: ver memória global `tissgama-repos-abandonados`.

## Pendências

A tabela de pendências e planejamento do projeto está em `TODO.md` na raiz. Atualizar via `/tab_pendencias`.

## Regras locais

### Privacidade (LGPD) — CRÍTICO

- **NUNCA** commitar arquivos `real_*.xml` ou qualquer XML TISS com dados reais de pacientes. `.gitignore` bloqueia `**/real_*.xml`, `_private_*/`, `.private/`, `*.pii.xml` — confiar mas verificar.
- Os 3 XMLs reais que validam o algoritmo vivem em `/home/petrus/IDrive/Documentos/projetos_claudebrain/Projects/_private_tiss_real_xmls/` (fora do repo). `conformance/build_fixture.py` detecta via env `TISS_PRIVATE_XMLS` ou path default e valida em memória sem copiar pro `inputs/`.
- O `vectors.json` distribuído tem APENAS sintéticos. Se algum agente futuro tentar reintroduzir reais no manifesto público, REJEITAR.

### Algoritmo (não inventar)

- Definição canônica em `docs/SPEC.md` e impl em `conformance/reference.py`.
- Encoding dos bytes pro MD5 = **UTF-8** (NÃO ISO-8859-1). Documentado; não "corrigir" pra ISO.
- Memória do projeto explica origem: `~/.claude/projects/-home-petrus-IDrive-Documentos-projetos-claudebrain-Projects-lib-hash-ans/memory/tiss-hash-algoritmo.md`.

### Git

- **Dual push automático**: `origin` tem 1 fetch URL (GitHub) + 2 push URLs (GitHub + Codeberg). `git push` envia pros dois.
- Conventional Commits obrigatório.
- Sem `--no-verify`, sem `--force` sem justificativa, sem amend em commit publicado.
- Co-Authored-By no commit message quando Claude contribuir significativamente.

### Estrutura

- `conformance/` — contrato compartilhado (NÃO modificar `reference.py` nem `vectors.json` casualmente; sempre regenerar via `build_fixture.py`).
- `langs/<lang>/` — port por linguagem; cada um auto-contido com seu próprio packaging.
- `docs/adr/` — decisões arquiteturais; novas decisões = novo ADR, não editar antigos.
- `docs/legal/` — LGPD/DISCLAIMER/TISS-COMPLIANCE; consultar ao falar de licença/conformidade.

### Agentes

- Usar agentes especializados sempre que aplicável (não fazer tudo inline). Tier típico:
  - Novo port → `backend-engineer` ou `embedded-firmware-engineer` (se C bare-metal).
  - Mudança em algoritmo/conformance → `qa-engineer`.
  - Decisão arquitetural → `software-architect`.
  - Docs novas → `technical-writer`.
  - Implicação legal/regulatória → `compliance-legal`.
  - Setup CI/CD → `devops-sre`.
- Quando dispatch paralelo, mandar em uma única mensagem.

## Stack atual

- Port Python (`langs/python/`): pronto, 19 testes passando. `defusedxml>=0.7.1` única dep runtime.
- Demais ports: planejados (ver `TODO.md` F5/F6).

## Memória persistente

Memórias do projeto em `~/.claude/projects/-home-petrus-IDrive-Documentos-projetos-claudebrain-Projects-lib-hash-ans/memory/` — sempre LER no início da sessão.
