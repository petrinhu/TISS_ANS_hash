# ADR-0002: Layout monorepo `langs/<lang>/` + `conformance/` compartilhado

**Status:** Accepted
**Data:** 2026-05-27
**Decisores:** Petrus (autor/dono do projeto)

## Contexto

Decidido em [ADR-0001](0001-port-nativo-por-linguagem.md) que cada linguagem
ganha port nativo independente. Falta decidir **como organizar fisicamente**
esses ports e o material compartilhado (vetores de conformidade, docs, ADRs,
ferramentas de build, changelog).

Restrições / objetivos:

- Suíte de conformidade (`conformance/vectors.json` + `inputs/*.xml`) é
  **autoridade única** e deve ser referenciada por todos os ports — não
  pode haver cópia divergente.
- Cada port precisa ser publicável **isoladamente** no registry da linguagem
  (PyPI, crates.io, npm, Packagist, Maven Central, NuGet, pub.dev,
  Conan/vcpkg). O publish não pode arrastar arquivos do outro port.
- CI deve poder rodar **apenas o que mudou** (path filters) para evitar
  rodar toolchain Rust/JVM/Delphi a cada commit em PHP.
- Onboarding: contributor novo deve enxergar a estrutura inteira sem ter
  que clonar N repos.

## Decisão

Monorepo único com layout:

```
lib_hash_ans/
├── README.md                  # hub: visão + links pros ports + status CI
├── ARCHITECTURE.md            # visão consolidada (referencia ADRs)
├── CHANGELOG.md               # changelog AGREGADO (entradas marcadas por port)
├── CONTRIBUTING.md            # como adicionar port novo, política de PRs
├── LICENSE
├── CONTRACT.md                # regras RFC 2119 (MUST/SHOULD/MAY) por port
├── TODO.md                    # tabela única de pendências (skill tab_pendencias)
│
├── conformance/               # AUTORIDADE — não duplicar
│   ├── reference.py           # implementação canônica (intocável)
│   ├── vectors.json           # contrato (intocável)
│   ├── build_fixture.py       # gerador (intocável)
│   └── inputs/*.xml           # XMLs de teste
│
├── docs/
│   ├── adr/                   # 0001-*, 0002-*, ...
│   └── ARCHITECTURE.md        # (alias ou destino canônico)
│
├── langs/
│   ├── python/                # pacote PyPI auto-suficiente
│   │   ├── pyproject.toml
│   │   ├── src/tiss_hash/
│   │   ├── tests/
│   │   └── README.md
│   ├── rust/                  # crate auto-suficiente (Cargo.toml na raiz)
│   ├── node/                  # package.json + TS
│   ├── php/                   # composer.json
│   ├── c/                     # CMakeLists.txt + headers/sources
│   ├── cpp/                   # CMakeLists.txt + namespace tiss_hash::
│   ├── go/                    # go.mod
│   ├── java/                  # gradle ou maven; pom.xml/build.gradle.kts
│   ├── kotlin/                # idem java (separado se idiomas divergem)
│   ├── dotnet/                # csproj (.NET 8+)
│   ├── delphi/                # .dpr/.dpk + tests via DUnitX
│   ├── dart/                  # pubspec.yaml (cobre Flutter)
│   └── wasm/                  # se for build dedicado (do contrário, port JS/TS empacota wasm)
│
├── tools/
│   ├── run_conformance.sh     # roda um port específico contra vectors.json
│   ├── update_changelog.py    # helper (opcional)
│   └── verify_all.sh          # roda todos os ports localmente (best-effort)
│
└── .forgejo/workflows/        # CI primária (Forgejo Actions)
    └── *.yml
    .github/workflows/         # CI espelho/fallback (GitHub Actions)
    └── *.yml
```

### Como cada port enxerga `conformance/`

Os ports referenciam **caminho relativo `../../conformance/`** durante
desenvolvimento e CI. **Os arquivos NÃO são copiados para dentro do pacote
publicado** — exceto se houver razão técnica forte (ex.: testes
integrados no source distribution Python via `MANIFEST.in`). Para os
registries que rodam apenas o conteúdo do pacote publicado, a suíte de
conformidade é **dev-only**; o usuário final do pacote nunca executa
`vectors.json`.

Regra: `conformance/` é **truth source**, jamais é editado por código de
um port; só por `build_fixture.py`. Cópias dentro de `langs/<lang>/`
(quando inevitável, como Delphi resources) devem ser geradas por script
no CI e marcadas como `// generated, do not edit`.

## Alternativas consideradas

### Opção A — Poly-repo (um repo por linguagem)

`lib-hash-ans-python`, `lib-hash-ans-rust`, `lib-hash-ans-node`...
`conformance/` num repo separado, ports referenciam via submódulo git ou
via download de release tag.

**Prós:**
- Cada repo é completamente isolado — visibilidade limpa no GitHub/Forgejo.
- Publish triggers só no repo certo (sem path filters).
- Contributor focado em uma linguagem não vê ruído das outras.
- Releases independentes são naturais (tag por repo).

**Contras:**
- **N+1 repos para um algoritmo de 30 linhas.** Setup de CI, README,
  LICENSE, CONTRIBUTING multiplicado por linguagem. Sobrecarga
  organizacional enorme.
- **Submódulo git para conformance é fricção real**: contributor esquece
  `git submodule update`, CI esquece, surge divergência silenciosa.
- **Bugfix coordenado fica caro**: bug no algoritmo (descoberto via novo
  vetor) precisa abrir PR em N repos, com N reviews.
- Onboarding pior: candidato a contributor não vê o panorama inteiro,
  não percebe que ports irmãos existem.
- Para projeto de manutenção esporádica (lib utilitária, não produto),
  custo organizacional > benefício.

### Opção B — Monorepo com diretório por linguagem (escolhida)

Vide layout acima.

**Prós:**
- Um único clone dá panorama completo + permite ver como port X resolveu
  algo difícil ao implementar port Y.
- `conformance/` é referenciado por caminho relativo — sem submódulo, sem
  download externo, zero possibilidade de divergir.
- Bugfix global (ex.: vetor novo) é 1 PR que toca `conformance/` + CIs
  de cada port re-rodam automaticamente.
- CI pode usar `paths:` filter pra rodar só o port afetado.
- Changelog único + tabela de pendências única (`TODO.md`) — alinha com
  preferência do usuário (skill `tab_pendencias`).

**Contras:**
- Releases independentes exigem disciplina de tag (`python-v1.2.0`,
  `rust-v0.3.1` em vez de `v1.0.0`) — mitigado em ADR-0003.
- Repo cresce em arquivos (mas não em volume — cada port tem ~30 linhas
  de algoritmo).
- Contributor casual pode achar opressivo ver 10 linguagens. Mitigado por
  README hub com links diretos para o port que interessa.

### Opção C — Monorepo achatado (sem `langs/`)

Tudo na raiz: `python_src/`, `rust_src/`, `node_src/`, ou pior: tudo
junto na raiz com sufixos.

**Prós:**
- Caminhos mais curtos.

**Contras:**
- Raiz fica poluída. Ferramentas de linguagem (cargo, npm, composer)
  esperam estar na raiz do seu próprio diretório — colocar `Cargo.toml`
  na raiz colide com `package.json`, `pyproject.toml` etc.
- Inviável.

## Consequências

**Positivas:**

- **Uma única referência de verdade** para o algoritmo (`conformance/`).
- Adicionar port novo = criar `langs/<lang>/` + workflow CI + README.
  Zero coordenação com outros ports.
- Bugfix no algoritmo (vetor novo) propaga automaticamente como falha de
  CI em todos os ports — força correção.
- Alinhado com preferências universais do usuário: hub `README.md`
  único + `CHANGELOG.md` único + `TODO.md` único.

**Negativas / aceitas como custo:**

- Tag de release precisa ser **prefixada por port** (`python-v1.0.0`).
  Convencional e documentado em ADR-0003.
- Workflows CI por port — pode chegar a 10+ arquivos `.yml`. Aceitável:
  cada workflow é pequeno (matrix de versões da linguagem + run conformance).
- Contributor que só usa um port vê os outros — possível ruído visual.
  Compensado pelo benefício de comparar implementações.

**Riscos / pontos de atenção:**

- **Mover/renomear `conformance/`** quebra todos os ports. Tratá-lo como
  API pública interna: mudança = ADR + deprecation aviso no `CHANGELOG.md`.
- **Tamanho do repo** se inputs de vetor crescerem muito (ex.: lote real
  de 100MB). Manter `inputs/` pequeno (XMLs de exemplo, não dumps de prod).
  Vetores grandes podem ir para release asset ou submódulo opt-in se
  necessário.

## Reversibilidade

**Two-way door com custo baixo.** Mudar para poly-repo (Opção A) depois é
mecânico: `git filter-repo` por subdiretório → N repos. `conformance/`
vira repo próprio referenciado por submódulo. Reversível em ~1 dia de
trabalho. Não há lock-in técnico.
