# CLAUDE.md: TISS_ANS_hash

`TISS_ANS_hash` é biblioteca multi-linguagem do hash MD5 do epílogo XML TISS/ANS (Padrão TISS). Sucessor do TISSGama (editor desktop legado arquivado).

- Site canônico (origin): https://github.com/petrinhu/TISS_ANS_hash
- Licença: AGPL-3.0
- Predecessor: ver a memória `tissgama-repos-abandonados.md`, na memória do projeto.
- Port Python (`langs/python/`): pronto, 19 testes passando; `defusedxml>=0.7.1` é a única dep runtime. Demais ports: planejados (ver `TODO.md` F5/F6).

## Estrutura

- `conformance/`: contrato compartilhado (LH-03).
- `langs/<lang>/`: um port por linguagem, cada um auto-contido com seu próprio packaging.
- `docs/adr/`: decisões arquiteturais (LH-04).
- `docs/legal/`: LGPD, DISCLAIMER e TISS-COMPLIANCE; consulte ao falar de licença ou conformidade.

## Memória persistente

Memórias do projeto em `~/.claude/projects/-home-petrus-IDrive-Documentos-projetos-claudebrain-Projects-lib-hash-ans/memory/`: leia sempre no início da sessão.

## Leis do projeto

Leia [`GODS_LAWS.md`](GODS_LAWS.md) antes de agir. `L-NN` sem prefixo é lei global.

| Lei | Gatilho: dispara quando você vai... |
|---|---|
| [LH-01](GODS_LAWS.md#lh-01) | commitar, mexer em fixture, XML ou `vectors.json`, ou tocar dado de paciente |
| [LH-02](GODS_LAWS.md#lh-02) | implementar ou alterar o cálculo do hash, ou mexer em encoding |
| [LH-03](GODS_LAWS.md#lh-03) | tocar `conformance/reference.py` ou `vectors.json` |
| [LH-04](GODS_LAWS.md#lh-04) | tomar decisão arquitetural, ou editar ADR |
| [LH-05](GODS_LAWS.md#lh-05) | escrever mensagem de commit, ou pensar em `--force` |
| [LH-06](GODS_LAWS.md#lh-06) | despachar agente |

## Pendências

A tabela de pendências e planejamento do projeto está em `TODO.md` na raiz. Atualizar via `/bigtech:tab_pendencias`.
