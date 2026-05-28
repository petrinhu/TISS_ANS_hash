---
name: Bug report
about: Reportar comportamento incorreto da lib (ex.: hash divergente do esperado)
title: "[bug] "
labels: ["bug", "triage"]
assignees: []
---

## Resumo

(uma frase descrevendo o problema)

## Versão da lib

- **Port afetado:** (Python / C / C++ / Rust / PHP / Node.js / outro)
- **Versão do pacote:** (ex.: `tiss-hash 0.1.0`)
- **Versão da SPEC** (se relevante): (ver `docs/SPEC.md` frontmatter)

## Ambiente

- **Runtime / compilador:** (ex.: Python 3.12.1, rustc 1.78, gcc 13)
- **Sistema operacional:** (ex.: Ubuntu 24.04, macOS 14.4, Windows 11)
- **Arquitetura:** (ex.: x86_64, arm64)

## Comportamento esperado

(o que você esperava acontecer)

## Comportamento observado

(o que aconteceu)

## XML de exemplo

> **CRÍTICO, ZERO PII:** **NÃO** cole XML real com nome de paciente, CPF, número de carteirinha, prontuário, data de nascimento, código de procedimento ligado a paciente, etc. Anonimize antes de colar (substitua por placeholders genéricos: `PACIENTE_TESTE`, `00000000000`, etc.).
>
> Se o problema só reproduz com dados reais, descreva os campos relevantes em prosa, **não** cole o XML, e proponha um sintético equivalente.

XML **mínimo** e **anonimizado** que reproduz o problema:

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">
  ...
</ans:mensagemTISS>
```

## Hash obtido vs esperado

- **Hash obtido pela lib:** `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- **Hash esperado (e fonte do esperado):** `yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy`
  - Fonte: (ex.: confirmado pela operadora; calculado pela impl. de referência `conformance/reference.py`; outra lib X versão Y)

## Repro

Passos exatos para reproduzir:

```bash
# 1. ...
# 2. ...
# 3. ...
```

Ou snippet de código:

```python
from tiss_hash import hash_tiss
# ...
```

## Logs / saída

```
(cole aqui a saída relevante, com qualquer PII removida)
```

## Notas adicionais

(qualquer contexto extra, hipótese de causa, links para discussões relacionadas)

## Checklist

- [ ] Verifiquei que **não há PII** no XML colado.
- [ ] Reproduzi o bug numa versão atualizada da lib.
- [ ] Procurei se já existe issue aberta sobre o mesmo problema.
- [ ] Se for divergência de hash, comparei com `conformance/reference.py`.
