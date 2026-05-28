# ADR-0004: Estratégia de CI — Forgejo Actions primária, GitHub Actions espelho

**Status:** Accepted
**Data:** 2026-05-27
**Decisores:** Petrus (autor/dono do projeto)

## Contexto

Cada port (ADR-0001) deve passar 100% de `conformance/vectors.json` antes de
qualquer release (ADR-0003). Falta decidir como organizar a CI:

- **Provider:** Forgejo Actions (preferência declarada do usuário; Woodpecker
  CI é setup pessoal mas Forgejo Actions é runtime upstream nativo) com
  GitHub Actions como espelho/fallback.
- **Granularidade de workflow:** um workflow gigante com matrix global, ou
  um workflow por port?
- **Quando rodar:** todo commit em qualquer arquivo, ou path-filtered?
- **Matrix de versões da linguagem:** quais versões cobrir por port?

Forgejo Actions e GitHub Actions são **compatíveis a nível de schema YAML**
para o subset que importa (jobs, steps, matrix, paths, services, secrets).
Diferenças: alguns marketplace actions (`actions/checkout@v4` etc.) são
mirrored no Forgejo via `https://code.forgejo.org/actions/checkout`. Os
workflows podem ser quase-idênticos com substituição de `uses:`.

## Decisão

### Provider

- **Forgejo Actions** (`.forgejo/workflows/*.yml`) é a **CI primária**.
  Quando o repo for hospedado em Forgejo (instância pessoal ou Codeberg),
  é o que dispara.
- **GitHub Actions** (`.github/workflows/*.yml`) é **espelho** — workflows
  equivalentes funcionais. Mantidos manualmente sincronizados (script de
  sync em `tools/sync_workflows.sh` opcional). Só ativos se o repo for
  mirrored no GitHub.

Convenção de actions:

```yaml
# Forgejo
- uses: https://code.forgejo.org/actions/checkout@v4

# GitHub
- uses: actions/checkout@v4
```

Manter ambos sincronizados é mecânico — o sync script faz `s/actions\//https:\/\/code.forgejo.org\/actions\//g`
para gerar a versão Forgejo a partir da GitHub (ou vice-versa).

### Granularidade — um workflow por port (escolhida)

Arquivo por linguagem, nome canônico `lang-<linguagem>.yml`:

```
.forgejo/workflows/
├── lang-python.yml
├── lang-rust.yml
├── lang-node.yml
├── lang-php.yml
├── lang-c.yml
├── lang-cpp.yml
├── lang-go.yml
├── lang-java.yml
├── lang-kotlin.yml
├── lang-dotnet.yml
├── lang-delphi.yml         # se runner Windows/Wine disponível
├── lang-dart.yml
├── conformance.yml         # roda reference.py + valida vectors.json
└── release-<lang>.yml      # dispara em tag <lang>-vX.Y.Z, publica
```

Cada workflow:

1. **path filter** — só roda quando arquivos do próprio port OU de
   `conformance/` mudam:

   ```yaml
   on:
     push:
       paths:
         - 'langs/python/**'
         - 'conformance/**'
         - '.forgejo/workflows/lang-python.yml'
     pull_request:
       paths:
         - 'langs/python/**'
         - 'conformance/**'
   ```

2. **matrix de versões da linguagem** (interno ao workflow):

   ```yaml
   strategy:
     fail-fast: false
     matrix:
       version: ['3.10', '3.11', '3.12', '3.13']
       os: [ubuntu-latest]
   ```

3. **steps padronizados:**
   - checkout
   - setup-<lang> com versão da matrix
   - instalar deps
   - rodar suíte do port contra `../../conformance/vectors.json`
   - reportar falha por vetor (qual ID divergiu, hash esperado vs hash
     calculado)

4. **release-<lang>.yml** separado, dispara só em tag `<lang>-vX.Y.Z`,
   roda conformance + publish no registry usando secret do registry.

### Matrix de versões (linha de base)

| Port    | Versões cobertas (mínima → atual)                |
|---------|--------------------------------------------------|
| Python  | 3.10, 3.11, 3.12, 3.13                           |
| Rust    | MSRV (`stable - 6`) + `stable` + `beta`          |
| Node    | 20 (LTS atual), 22 (LTS), 24 (current)           |
| PHP     | 8.1, 8.2, 8.3, 8.4                               |
| C       | gcc-12, gcc-14, clang-16, clang-18 — C11 e C17  |
| C++     | gcc-12, gcc-14, clang-16, clang-18 — C++17 e C++20 (C++23 onde toolchain permite) |
| Go      | 1.22, 1.23 (current)                             |
| Java    | 17 (LTS), 21 (LTS), 23                           |
| Kotlin  | 1.9, 2.0                                         |
| .NET    | 8 (LTS), 9                                       |
| Dart    | 3.4+ (Flutter 3.22+ implica isso)                |
| Delphi  | manual ou opcional (runner Windows)              |

OS na matrix: começar `ubuntu-latest` apenas; adicionar `windows-latest`
e `macos-latest` quando alguém reportar bug específico de OS.

### Workflow `conformance.yml` (gatekeeper)

Roda em **todo commit em `conformance/**`**. Re-executa `build_fixture.py`
e compara saída com `vectors.json` versionado. Falha se houver drift —
protege a referência canônica contra modificação acidental.

## Alternativas consideradas

### Q1 — Provider

**A. Forgejo Actions primária + GitHub Actions espelho** *(escolhida)*
- Prós: alinha com infra pessoal do usuário (Forgejo + Woodpecker
  doc'd no ecossistema); independência de big-tech; espelho GitHub
  facilita PRs externos.
- Contras: precisa manter dois sets de workflow (mecânico).

**B. Só GitHub Actions** — só publicar no GitHub, sem Forgejo.
- Prós: maior comunidade de actions; runners gratuitos generosos para
  open-source.
- Contras: vendor lock-in; usuário já tem investimento Forgejo
  documentado em `~/.claude/memory/forgejo.md` e `woodpecker-ci.md`.

**C. Só Woodpecker CI** (`.woodpecker.yml`).
- Prós: setup já dominado pelo usuário; integra direto com Forgejo.
- Contras: ecossistema menor; menos plugins prontos pra setup de
  toolchain de cada linguagem; sintaxe diferente de Forgejo/GitHub
  (mais difícil portar workflows da comunidade).

**D. Forgejo Actions + Woodpecker em paralelo.**
- Contras: três sistemas pra manter (Forgejo + GitHub + Woodpecker).
  Não vale o custo para projeto utilitário.

### Q2 — Granularidade de workflow

**A. Um workflow por port** *(escolhida)*
- Prós: log isolado por linguagem (debug claro); path filter trivial;
  badges no README por port; falhar um port não cancela outros (com
  `fail-fast: false` global por job); fácil desabilitar
  temporariamente um port quebrado.
- Contras: N arquivos `.yml`. Mas cada um é pequeno (50-80 linhas).

**B. Workflow único com matrix global** (uma matrix com
`{lang} × {version}`):
- Prós: um arquivo.
- Contras: setup heterogêneo (precisa de `setup-python` se python,
  `setup-rust` se rust...) vira ladeira de `if: matrix.lang == 'python'`
  — código YAML feio e frágil; falha de um setup polui o log de todos;
  path filter perde precisão.

**C. Um workflow por categoria** (`compiled.yml` = C/C++/Rust/Go,
`managed.yml` = Java/Kotlin/.NET, `script.yml` = Python/PHP/Node/Dart):
- Prós: menos arquivos que A.
- Contras: setup ainda heterogêneo dentro de cada categoria;
  organização sem benefício real.

### Q3 — Path filtering

**A. Path filter por port** *(escolhida)*
- Prós: commit em `langs/php/` não dispara CI de Rust, Java, etc —
  economiza minutos de runner; feedback rápido.
- Contras: nenhuma — Forgejo/GitHub suportam nativamente.

**B. Rodar todos os ports em todo commit.**
- Prós: simples.
- Contras: desperdiça runner; PRs que tocam só docs disparam 12 jobs
  de toolchain pesado.

### Q4 — Matrix de versão da linguagem

**A. Cobrir LTS + current** *(escolhida)*
- Prós: realista; cobre maioria dos usuários.
- Contras: usuário em versão velha (Python 3.8, Java 11) sem cobertura
  — declarar MSRV no README.

**B. Cobrir tudo, de versão mínima viável até cutting-edge.**
- Prós: máxima compatibilidade declarada.
- Contras: explode runner time; instala toolchain antiga propensa a
  vulnerabilidades.

**C. Só uma versão (a current).**
- Prós: rápido.
- Contras: usuário em LTS descobre incompatibilidade em produção.
  Inaceitável para lib reutilizável.

## Consequências

**Positivas:**

- Cada port tem CI independente, falha de um não bloqueia outros.
- Path filter mantém runner barato e feedback rápido.
- Matrix LTS+current cobre 95% dos usuários reais.
- Conformance gatekeeper protege a referência canônica.
- Dois providers (Forgejo + GitHub) cobrem usuários de ambos ecossistemas
  via mirror.

**Negativas / aceitas como custo:**

- Workflows duplicados em `.forgejo/` e `.github/` — manter sincronizados
  via script (`tools/sync_workflows.sh`).
- Adicionar port novo = adicionar 1 workflow (template + ajuste de setup
  da linguagem).
- Tempo total de CI cresce com número de ports (mas só quando muda
  `conformance/` — caso raro).

**Riscos / pontos de atenção:**

- **Delphi não tem runner Forgejo/GitHub pronto.** Opções: runner Windows
  self-hosted, OU Wine + freepascal/lazarus como proxy parcial, OU
  testar manualmente e marcar `lang-delphi.yml` como `workflow_dispatch`
  apenas. Decidir quando port Delphi for criado.
- **WASM** — se for build separado, exige `wasm-pack` ou `emscripten`;
  pode ser pesado. Decidir quando port WASM for criado.
- **Sync de workflows Forgejo↔GitHub manual** — se desincronizar, um dos
  dois para de funcionar silenciosamente. Mitigação: workflow `verify.yml`
  meta-CI que faz diff entre os dois e alerta.

## Reversibilidade

- **Provider:** two-way door barato — workflows são portáveis com
  substituição de strings (`uses:` paths).
- **Granularidade:** two-way door — refatorar workflows é só YAML.
- **Matrix de versões:** two-way door — adicionar/remover versão é uma
  linha; documentar no README qual é a versão "garantida".
