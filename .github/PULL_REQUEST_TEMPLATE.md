# Pull Request

## Descrição

(o que muda? por quê? qual problema resolve?)

## Tipo

Marque o(s) que se aplicam:

- [ ] `feat` (nova funcionalidade)
- [ ] `fix` (correção de bug)
- [ ] `docs` (apenas documentação)
- [ ] `test` (adição/correção de testes ou vetores)
- [ ] `refactor` (código sem mudança de comportamento)
- [ ] `perf` (otimização de performance)
- [ ] `build` (sistema de build/packaging)
- [ ] `ci` (pipelines de CI)
- [ ] `chore` (manutenção sem efeito de produto)

## Port afetado (se aplicável)

(Python / C / C++ / Rust / PHP / Node.js / outro / spec apenas / fixture apenas)

## Issue relacionada

Closes #...
Refs #...

## Como testei

```bash
# comandos exatos rodados para validar
```

## Screenshots (se UI)

(remover esta seção se não há UI)

## Checklist

- [ ] Título do PR e commits seguem [Conventional Commits](https://www.conventionalcommits.org/).
- [ ] **Lint passou** localmente (`ruff`, `clippy`, `gofmt`, equivalente).
- [ ] **Testes passaram** localmente.
- [ ] **15 vetores de conformidade** passam no port afetado (se aplicável).
- [ ] **Docstring/comentário** em qualquer API pública nova ou modificada.
- [ ] **`CHANGELOG.md`** atualizado na seção `[Unreleased]`.
- [ ] **Sem PII em fixtures**: nenhum nome, CPF, carteirinha, data de nascimento real em XMLs commitados.
- [ ] **Sem dado real de paciente** em exemplos de doc ou snippets.
- [ ] Documentação atualizada (`USAGE.md`, `SPEC.md`, `PORTING_GUIDE.md`, etc.) quando aplicável.
- [ ] CI passou nos dois mirrors (quando disponível).

## Breaking changes

- [ ] **Não há** breaking changes.
- [ ] **Há** breaking changes (descreva abaixo, e marque BREAKING CHANGE no commit/footer).

(descrição das mudanças incompatíveis e plano de migração, se aplicável)

## Notas para revisão

(qualquer ponto que o revisor precisa olhar com atenção: trade-off considerado, alternativa rejeitada, dependência nova, etc.)
