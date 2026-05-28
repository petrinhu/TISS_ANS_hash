# Como contribuir

Obrigado pelo interesse em contribuir com `lib_hash_ans` / `TISS_ANS_hash`.

Este documento descreve o fluxo de trabalho, convenções e checklist para submeter código, documentação ou novos vetores de conformidade.

## Sumário

- [Onde abrir issues e PRs](#onde-abrir-issues-e-prs)
- [Configuração local](#configuração-local)
- [Convenções de commit](#convenções-de-commit)
- [Dual push (GitHub + Codeberg)](#dual-push-github--codeberg)
- [Tipos de contribuição](#tipos-de-contribuição)
- [Checklist do Pull Request](#checklist-do-pull-request)
- [Code of Conduct](#code-of-conduct)
- [Licença e DCO/CLA](#licença-e-dcocla)

## Onde abrir issues e PRs

O projeto vive em **dois mirrors públicos**:

- GitHub: [`petrinhu/TISS_ANS_hash`](https://github.com/petrinhu/TISS_ANS_hash) (principal para discoverability).
- Codeberg: [`petrinhu/TISS_ANS_hash`](https://codeberg.org/petrinhu/TISS_ANS_hash) (mirror priorizando soberania europeia / não-Microsoft).

Você pode:

- **Abrir issues** em qualquer um dos dois. O mantenedor monitora ambos.
- **Abrir PRs** em qualquer um dos dois. GitHub é a opção principal por ferramentas e CI; Codeberg é válido para contribuintes que preferem evitar conta GitHub.
- **Reportar segurança**: ver [`SECURITY.md`](SECURITY.md) (canal privado por e-mail).

Não duplique a mesma issue nos dois mirrors. Escolha um e linka pra ele se precisar referenciar do outro lado.

## Configuração local

### Pré-requisitos

- Git 2.40+.
- Python 3.10+ (para rodar a suíte de conformidade do port Python).
- `lxml` (para rodar a implementação de referência diretamente).

### Clone

```bash
git clone https://github.com/petrinhu/TISS_ANS_hash.git
cd TISS_ANS_hash
```

(ou via Codeberg: `git clone https://codeberg.org/petrinhu/TISS_ANS_hash.git`).

### Rodar a suíte de conformidade

```bash
# Implementação de referência (1 comando, sem instalar nada além de lxml)
cd conformance
python3 build_fixture.py     # regera vectors.json a partir dos inputs

# Port Python (instala em modo dev, roda pytest)
cd ../langs/python
pip install -e ".[dev]"
pytest -v
```

Saída esperada do `pytest -v`: `19 passed`.

## Convenções de commit

Usamos **Conventional Commits**: [`https://www.conventionalcommits.org/`](https://www.conventionalcommits.org/).

Formato:

```
<tipo>(<escopo opcional>): <descrição curta>

[corpo opcional explicando "por quê"]

[footers opcionais: BREAKING CHANGE, Refs, Co-authored-by]
```

Tipos aceitos:

| Tipo       | Quando usar                                                    |
|------------|----------------------------------------------------------------|
| `feat`     | Nova funcionalidade visível ao usuário (ex.: novo port, nova API). |
| `fix`      | Correção de bug.                                               |
| `docs`     | Mudança apenas em documentação.                                |
| `test`     | Adição/correção de testes ou vetores de conformidade.          |
| `refactor` | Mudança de código sem alterar comportamento observável.        |
| `perf`     | Otimização de performance.                                     |
| `build`    | Mudança em sistema de build / packaging.                       |
| `ci`       | Mudança em CI (workflows GitHub Actions / Woodpecker).         |
| `chore`    | Tarefa de manutenção sem efeito de produto.                    |

Escopos sugeridos: nome da linguagem do port (`python`, `c`, `rust`, etc.), `spec`, `conformance`, `docs`, `ci`.

Exemplos:

```
feat(python): expor InvalidTissXml na API pública
fix(spec): corrigir descrição do passo 3 (folha vs nó-folha)
test(conformance): adicionar vetor syn_namespace_xsi.xml
docs(usage): explicar pegadinha de encoding em receita FastAPI
```

Mensagens em português ou inglês são ambas aceitas. Mantenha consistência dentro de cada PR.

## Dual push (GitHub + Codeberg)

O mantenedor configura o repositório local com **push duplo**: um único `git push` envia para ambos os mirrors.

Para configurar localmente (apenas se você é mantenedor ou tem permissão de push direto):

```bash
git remote set-url --add --push origin git@github.com:petrinhu/TISS_ANS_hash.git
git remote set-url --add --push origin git@codeberg.org:petrinhu/TISS_ANS_hash.git

# Verificar:
git remote -v
# origin  ...  (fetch)
# origin  git@github.com:...    (push)
# origin  git@codeberg.org:...  (push)
```

Resultado: `git push origin main` empurra para os dois automaticamente. Os mirrors permanecem sincronizados.

Contribuidores externos **não precisam** dessa configuração: basta fazer fork no mirror que preferirem e abrir PR normalmente. O merge no upstream replica para o outro lado.

## Tipos de contribuição

### Adicionar um novo port (nova linguagem)

Procedimento, dependências, layout de pastas e critérios de aceitação estão em [`docs/PORTING_GUIDE.md`](docs/PORTING_GUIDE.md). Resumo:

1. Criar `langs/<linguagem>/` com layout idiomático da linguagem.
2. Implementar `hash_tiss(bytes) -> str` (ou equivalente idiomático).
3. Implementar exceção tipada para XML inválido.
4. Rodar os 15 vetores de [`conformance/vectors.json`](conformance/vectors.json). **Todos devem passar byte-a-byte.**
5. Adicionar CI (GitHub Actions e/ou Woodpecker no Codeberg).
6. Adicionar entrada na tabela de status do `README.md` e do `docs/USAGE.md`.
7. Atualizar `CHANGELOG.md`.
8. PR com checklist abaixo preenchido.

### Adicionar um novo vetor de conformidade

Procedimento completo em [`conformance/TEST_PLAN.md`](conformance/TEST_PLAN.md). Resumo:

1. Criar `conformance/inputs/syn_<nome>.xml` com o caso de borda.
2. **Garantir zero PII** no XML (ver regra crítica abaixo).
3. Rodar `python3 conformance/build_fixture.py` para regerar `vectors.json` com o hash esperado.
4. Adicionar entrada com `desc:` explicando o que o vetor testa.
5. Rodar `pytest` em todos os ports prontos: todos devem continuar passando, incluindo o vetor novo.
6. PR com checklist abaixo.

### Reportar bug

Use [`Issue Template: Bug Report`](.github/ISSUE_TEMPLATE/bug_report.md). **Não cole XML real com PII**: anonimize antes (substitua nomes, CPFs, números de carteirinha, datas de nascimento por placeholders genéricos).

### Sugerir feature

Use [`Issue Template: Feature Request`](.github/ISSUE_TEMPLATE/feature_request.md).

### Propor novo port (antes de implementar)

Use [`Issue Template: New Port Proposal`](.github/ISSUE_TEMPLATE/new_port.md). Útil para alinhar manutenção planejada e escolha de parser XML antes de gastar tempo.

## Checklist do Pull Request

Cole no corpo do PR ou marque no template [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md):

- [ ] **Conventional Commit** no título do PR e em cada commit.
- [ ] **Lint passou** localmente (rodar a tool específica da linguagem: `ruff`, `clippy`, `gofmt`, etc.).
- [ ] **Testes passaram** localmente (`pytest`, `cargo test`, etc.).
- [ ] **15 vetores de conformidade** passam no port afetado.
- [ ] **Docstring/comentário** em qualquer API pública nova ou modificada.
- [ ] **`CHANGELOG.md` atualizado** (entrada em `[Unreleased]`).
- [ ] **Sem PII em fixtures**: nenhum nome, CPF, carteirinha, prontuário, data de nascimento real em XMLs commitados.
- [ ] **Sem dado real de paciente**: se o exemplo veio de produção, anonimize antes.
- [ ] **Doc atualizada**: `USAGE.md`, `SPEC.md`, `PORTING_GUIDE.md` se aplicável.
- [ ] **CI passou** nos dois mirrors (GitHub Actions + Woodpecker no Codeberg) quando disponível.

## Code of Conduct

Este projeto adota o [Contributor Covenant 2.1](CODE_OF_CONDUCT.md). Contribuições, issues e revisões devem seguir o código de conduta. Reportes de violação vão para `petrinhu@yahoo.com.br`.

## Licença e DCO/CLA

O projeto é licenciado sob [MIT](LICENSE).

**Não exigimos DCO nem CLA.** Ao abrir um PR, você concorda implicitamente em licenciar sua contribuição sob os mesmos termos MIT. Essa é a prática padrão de projetos open source permissivos, e a MIT é compatível com qualquer outra licença que você queira usar derivando do projeto.

Se sua contribuição inclui código de terceiros, indique no PR a origem e a licença (preferimos MIT, BSD-2/3, Apache-2.0, ou domínio público; outras licenças compatíveis com MIT podem ser aceitas após revisão).
