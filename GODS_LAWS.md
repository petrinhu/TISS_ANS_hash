# GODS_LAWS.md: TISS_ANS_hash (lib_hash_ans)

> Ordens do líder para este projeto. Cada lei tem um gatilho, conferido no momento da ação.

## Protocolo de uso

1. Antes de agir, confira o índice de gatilhos do `CLAUDE.md` deste projeto; se um gatilho casa, leia a lei inteira antes do primeiro comando.
2. Siga o protocolo de uso do `~/.claude/GODS_LAWS.md`. No que este arquivo silencia, vale a lei global; `L-NN` sem prefixo é lei global e `LH-NN` é lei daqui.

---

## LH-01

**Data:** regra permanente.

**Privacidade (LGPD), crítico.** Nunca commite arquivo `real_*.xml` nem qualquer XML TISS com dados reais de pacientes. O `.gitignore` bloqueia `**/real_*.xml`, `_private_*/`, `.private/` e `*.pii.xml`: confie, mas verifique.

Mantenha os 3 XMLs reais que validam o algoritmo em `/home/petrus/IDrive/Documentos/projetos_claudebrain/Projects/_private_tiss_real_xmls/`, fora do repo. O `conformance/build_fixture.py` os detecta pela env `TISS_PRIVATE_XMLS` ou pelo caminho padrão e valida em memória, sem copiar para `inputs/`.

Mantenha só sintéticos no `vectors.json` distribuído. Rejeite qualquer tentativa de agente de reintroduzir dados reais no manifesto público.

## LH-02

**Data:** regra permanente.

Não invente o algoritmo. A definição canônica está em `docs/SPEC.md` e a implementação em `conformance/reference.py`. Codifique os bytes para o MD5 em **UTF-8**, nunca em ISO-8859-1: está documentado, e não se "corrige" para ISO. A origem está na memória do projeto, `~/.claude/projects/-home-petrus-IDrive-Documentos-projetos-claudebrain-Projects-lib-hash-ans/memory/tiss-hash-algoritmo.md`.

## LH-03

**Data:** regra permanente.

Não modifique `conformance/reference.py` nem `vectors.json` casualmente, porque `conformance/` é o contrato compartilhado entre os ports: regenere sempre via `build_fixture.py`.

## LH-04

**Data:** regra permanente.

Registre cada decisão arquitetural nova como ADR novo em `docs/adr/` e não edite os ADRs antigos.

## LH-05

**Data:** regra permanente.

Não use `--force` sem justificativa. Ponha `Co-Authored-By` na mensagem de commit quando o Claude contribuir de forma significativa.

## LH-06

**Data:** regra permanente.

Despache cada tipo de trabalho ao agente especializado típico:

- port novo: `backend-engineer`, ou `embedded-firmware-engineer` se for C bare-metal;
- mudança em algoritmo ou conformance: `qa-engineer`;
- decisão arquitetural: `software-architect`;
- docs novas: `technical-writer`;
- implicação legal ou regulatória: `compliance-legal`;
- setup de CI/CD: `devops-sre`.

Em despacho paralelo, mande todos numa única mensagem.
