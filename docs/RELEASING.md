# Releasing — TISS_ANS_hash

Runbook do processo de release multi-linguagem.

O release é **dirigido por tag**: nada publica até uma tag `v*` ser empurrada.
Toda a automação é inerte antes disso.

> **Estado HOJE (2026-05): nenhum registry está habilitado.** Todos os jobs de
> publish em registry são **gated** por uma *variável de repo* (`vars.*_ENABLED`)
> que ainda **não foi setada**. Sem ela, cada job de publish é **SKIPPED**
> (verde, não falha). Portanto uma tag `v*` empurrada hoje:
> - **cria os Releases nos repositórios** (GitHub + Codeberg) com os assets, e
> - **não publica em registry nenhum nem falha** por falta de token.
>
> O release dos **repos** (GitHub/Codeberg) é **independente** dos gates de
> registry: liga-se cada registry depois, quando o líder tiver a conta/token.

```text
git tag v0.1.0  ─push─► GitHub:   release-python.yml ─► GitHub Release  + [PyPI]   (gate PYPI_ENABLED)
                     ├► GitHub:   release-node.yml   ─► [npm]                      (gate NPM_ENABLED)
                     ├► GitHub:   release-rust.yml   ─► dry-run sempre + [crates.io](gate CRATES_ENABLED)
                     ├► GitHub:   release-csharp.yml ─► pack sempre + [NuGet]      (gate NUGET_ENABLED)
                     ├► GitHub:   release-java.yml   ─► [Maven Central]            (gate MAVEN_ENABLED)
                     └► Codeberg: release.yml        ─► Codeberg Release (mirror)
```

`[...]` = passo **gated**: só roda com a variável de repo correspondente em
`true`. Hoje nenhuma está setada, então só os **Releases dos repos** acontecem.

## Visão geral dos workflows

| Arquivo | Plataforma | Dispara em | O que faz | Gate |
|---|---|---|---|---|
| `.github/workflows/release-python.yml` | GitHub (origin) | tag `v*` / dispatch | build sdist+wheel → cria **GitHub Release** (sdist, wheel, `SHA256SUMS`, `sbom.cdx.json`) e — **se** gated ligado — publica no **PyPI via Trusted Publishing (OIDC)** | `vars.PYPI_ENABLED` (só o job PyPI; o GitHub Release sai sempre) |
| `.github/workflows/release-node.yml` | GitHub | tag `v*` / dispatch | `npm ci` + test → `npm publish --access public --provenance` de `langs/node` | `vars.NPM_ENABLED` |
| `.github/workflows/release-rust.yml` | GitHub | tag `v*` / dispatch | `cargo test` + `cargo publish --dry-run` (**sempre**) → `cargo publish` de `langs/rust` | `vars.CRATES_ENABLED` (só o publish real) |
| `.github/workflows/release-csharp.yml` | GitHub | tag `v*` / dispatch | `dotnet test` + `dotnet pack` (**sempre**) → `dotnet nuget push` de `langs/csharp` | `vars.NUGET_ENABLED` (só o push) |
| `.github/workflows/release-java.yml` | GitHub | tag `v*` / dispatch | `mvn -P release deploy` p/ **Maven Central** (Sonatype). **Job inteiro gated** | `vars.MAVEN_ENABLED` (pré-requisitos pesados — ver abaixo) |
| `.forgejo/workflows/release.yml` | Codeberg (mirror) | tag `v*` / dispatch | build sdist+wheel → cria **Codeberg Release** via API Forgejo com os mesmos assets. **Não** publica em registry | — |

`workflow_dispatch` faz um **dry-run de build** (e, no GitHub, valida metadados
com `twine check`); os jobs de publish em registry têm guarda `if: push de tag`
**e** o gate `vars.*_ENABLED`, então **não** disparam por dispatch nem sem o gate.

## Habilitar cada registry (variável + secret)

Para **ligar** um registry: criar a **Variável de repo** (`Settings → Secrets
and variables → Actions → Variables`) com valor `true`, **e** o **Secret**
correspondente. Para **desligar**: remover a variável (ou setar `false`).

| Registry | Linguagem / port | Como habilitar (Var + Secret) | Pré-requisitos de conta |
|---|---|---|---|
| **PyPI** | Python (`langs/python`, `tiss-hash`) | Var `PYPI_ENABLED=true`. **Sem secret** — usa Trusted Publishing (OIDC). | Pending publisher no PyPI + environment `pypi` no GitHub (ver seção dedicada abaixo). |
| **npm** | Node (`langs/node`, `tiss-hash`) | Var `NPM_ENABLED=true` + Secret `NPM_TOKEN`. | Conta npmjs; gerar **Automation token** (Access Tokens → Generate → Automation). Nome `tiss-hash` disponível. |
| **crates.io** | Rust (`langs/rust`, `tiss-hash`) | Var `CRATES_ENABLED=true` + Secret `CARGO_REGISTRY_TOKEN`. | Login crates.io via GitHub; **API token** (Account Settings → API Tokens) com escopo `publish-new`+`publish-update`. Nome `tiss-hash` disponível. |
| **NuGet** | C# (`langs/csharp`, `TissHash`) | Var `NUGET_ENABLED=true` + Secret `NUGET_API_KEY`. | Conta nuget.org; **API key** (escopo Push, glob `TissHash` ou `*`). Nome `TissHash` disponível. |
| **Maven Central** | Java (`langs/java`, `dev.petrus:tiss-hash`) | Var `MAVEN_ENABLED=true` + Secrets `OSSRH_USERNAME`, `OSSRH_TOKEN`, `MAVEN_GPG_PRIVATE_KEY`, `MAVEN_GPG_PASSPHRASE`. | **PESADO** (ver abaixo): namespace verificado + conta Sonatype + chave GPG + plugins de release no `pom.xml`. |
| **Packagist** | PHP (`langs/php`) | **Sem workflow.** Webhook do git (ver abaixo). | Submeter o repo 1× em packagist.org; depois atualiza sozinho via webhook. |
| **Go modules** | Go (`langs/go`) | **Sem workflow.** Automático pela tag. | Nenhum — `go get …/langs/go@v0.1.0` resolve direto pelo proxy assim que a tag existe. |

### Resumo do que setar para ligar cada um

```text
PyPI       → Var PYPI_ENABLED=true                         (sem secret; OIDC)
npm        → Var NPM_ENABLED=true     + Secret NPM_TOKEN
crates.io  → Var CRATES_ENABLED=true  + Secret CARGO_REGISTRY_TOKEN
NuGet      → Var NUGET_ENABLED=true   + Secret NUGET_API_KEY
Maven      → Var MAVEN_ENABLED=true   + Secrets OSSRH_USERNAME, OSSRH_TOKEN,
                                                MAVEN_GPG_PRIVATE_KEY,
                                                MAVEN_GPG_PASSPHRASE
Packagist  → (nenhuma var; webhook manual 1×)
Go         → (nenhuma var; automático via tag)
```

### Maven Central — pré-requisitos pesados (antes de `MAVEN_ENABLED=true`)

O `release-java.yml` está **estruturalmente pronto e totalmente gated**, mas o
`mvn deploy` para o Central exige, ANTES de ligar:

1. **Namespace verificado** no Sonatype Central. `groupId` atual = `dev.petrus`
   (exige verificar o domínio `petrus.dev` via TXT DNS). Alternativa sem domínio
   próprio: migrar para `io.github.petrinhu` (verificável pela conta GitHub).
2. **Conta + user token** Sonatype Central → Secrets `OSSRH_USERNAME` / `OSSRH_TOKEN`.
3. **Chave GPG** (Central exige `.asc` em jar/sources/javadoc/pom): privada
   armored no Secret `MAVEN_GPG_PRIVATE_KEY`, passphrase em `MAVEN_GPG_PASSPHRASE`,
   pública num keyserver.
4. **Plugins de release no `pom.xml`** — hoje ausentes: `maven-source-plugin`,
   `maven-javadoc-plugin`, `maven-gpg-plugin` e `central-publishing-maven-plugin`
   (+ `<distributionManagement>` e um `<profile>release</profile>`).

O cabeçalho do `release-java.yml` repete este checklist. Só depois disso o gate
`MAVEN_ENABLED=true` faz sentido.

### Packagist (PHP) — sem workflow

Packagist puxa do git por **webhook**, não por push de pacote. Setup único:
1. Em <https://packagist.org/packages/submit>, submeter `https://github.com/petrinhu/TISS_ANS_hash`.
2. Packagist detecta o `langs/php/composer.json` e cria o pacote; a cada tag
   nova, o webhook (auto-configurado no GitHub na submissão, ou manual em
   `Settings → Webhooks`) atualiza a versão. Nada a fazer no CI.

> Nota: Composer mapeia 1 pacote por `composer.json`. Como o `composer.json`
> está em `langs/php/`, conferir que o nome do pacote (campo `name`) e o subpath
> ficam corretos na submissão; se necessário, usar um repositório dedicado ou
> `path`/`vcs` repo. Verificar no primeiro submit.

### Go modules — sem workflow

`go get github.com/petrinhu/TISS_ANS_hash/langs/go@v0.1.0` funciona assim que a
tag `v0.1.0` existe: o módulo (`go.mod` em `langs/go`) é indexado pelo proxy
público (`proxy.golang.org`) na primeira requisição. Nenhuma conta, token ou
publish manual. Para aparecer no índice/pkg.go.dev mais rápido, basta um
`go get` ou visitar a página do módulo uma vez.

Por que o publish no PyPI fica só no GitHub (não no Codeberg): o PyPI Trusted
Publishing aceita identidade OIDC do GitHub Actions; o Codeberg não é provedor
OIDC aceito pelo PyPI. O Codeberg apenas espelha o Release (notas + assets
verificáveis).

## Pré-requisitos de configuração do PyPI (quando ligar `PYPI_ENABLED`)

> Estes passos são do **mantenedor** (petrus) e só são necessários **quando o
> líder for ligar o PyPI** (Var `PYPI_ENABLED=true`). Enquanto a var não estiver
> setada, o job `pypi-publish` é **SKIPPED** (verde) — não falha por falta deles.
> Quando ligar, sem estes passos o job falharia na autenticação OIDC.

### 1. PyPI — pending publisher (Trusted Publishing, sem token)

Em <https://pypi.org/manage/account/publishing/>, adicionar um **pending
publisher** (o projeto `tiss-hash` ainda não existe no PyPI no primeiro release):

| Campo | Valor EXATO |
|---|---|
| PyPI Project Name | `tiss-hash` |
| Owner | `petrinhu` |
| Repository name | `TISS_ANS_hash` |
| Workflow name | `release-python.yml` |
| Environment name | `pypi` |

O **workflow name** e o **environment** precisam bater byte-a-byte com o
workflow (`name:` do arquivo é `release-python`, mas o campo do PyPI espera o
**nome do arquivo**: `release-python.yml`). Se renomear o arquivo, atualizar
aqui também.

### 2. GitHub — environment `pypi`

Em `Settings → Environments → New environment`, criar `pypi`. Opcional, mas
recomendado: exigir **required reviewers** (gate manual antes de publicar) e
restringir a deployment branches/tags `v*`. O job `pypi-publish` referencia
`environment: { name: pypi }` — o nome tem que casar com o pending publisher.

### 3. Codeberg — nada a configurar

O `release.yml` autentica com o token automático do runner Forgejo
(`secrets.GITHUB_TOKEN`, alias de `FORGEJO_TOKEN`), que já tem escopo do repo.
Não há secret manual nem OIDC.

## Procedimento de release (a cada versão)

1. **Pré-flight (na main, limpa):**
   - `CHANGELOG.md` com a seção da versão movida de `[Unreleased]` para `[x.y.z]`.
   - `langs/python/pyproject.toml` com `version = "x.y.z"` correto.
   - (opcional) `RELEASE_NOTES.md` na raiz — se existir, vira o corpo dos dois
     releases; senão o GitHub auto-gera das notas e o Codeberg usa um stub.
   - CI verde nos dois hosts.
2. **Build local de sanidade** (espelha o CI):
   ```bash
   cd langs/python
   python -m venv /tmp/rel && . /tmp/rel/bin/activate
   pip install build twine
   python -m build && python -m twine check dist/*
   ```
   Esperado: `tiss_hash-x.y.z.tar.gz` + `tiss_hash-x.y.z-py3-none-any.whl`
   (note o **underscore** — normalização PEP 625 do hatchling), ambos PASSED no
   twine check. Limpar o `dist/` depois.
3. **Tag e push** (o dual push manda pros dois remotes):
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z      # vai pra GitHub E Codeberg (origin tem 2 push URLs)
   ```
4. **Acompanhar:**
   - GitHub Actions → `release-python` → job `build` verde → `github-release`
     verde (sai **sempre**). O job `pypi-publish` só roda se `PYPI_ENABLED=true`;
     caso contrário aparece **SKIPPED** (esperado enquanto o PyPI estiver
     desligado). Se ligado e com gate de environment, aprovar o deploy.
   - Os demais `release-<lang>` (node/rust/csharp/java) só executam o passo de
     publish se a `vars.*_ENABLED` correspondente estiver `true`; senão o job/step
     fica **SKIPPED** (verde). O `release-rust` ainda roda `cargo publish --dry-run`
     e o `release-csharp` ainda roda `dotnet pack` mesmo desligados (validação).
   - Codeberg → Actions → `release` verde → conferir o Release criado.
5. **Verificar:**
   - Registries ligados: ver a página do pacote (ex.: PyPI
     <https://pypi.org/project/tiss-hash/>) e instalar numa máquina limpa.
   - GitHub/Codeberg Release têm os 4 assets; conferir checksums:
     ```bash
     sha256sum -c SHA256SUMS
     ```

## Rollback

- **PyPI:** uma versão publicada **não pode ser sobrescrita**. Se houver erro,
  publicar `X.Y.(Z+1)` (ou `X.Y.Z.postN`) corrigido. `yank` esconde a versão
  ruim de novos installs sem quebrar quem já pinou. Não dá pra "desfazer".
- **GitHub/Codeberg Release:** deletável pela UI/API; a tag pode ser removida
  (`git push origin :refs/tags/vX.Y.Z`) — fazer **antes** de qualquer consumo.
- Por isso: o gate de environment `pypi` (required reviewer) é a salvaguarda
  real — é o último ponto reversível antes do publish irreversível no PyPI.

## Supply chain / segurança

- **Gate por variável, não por presença de secret.** Cada job de publish em
  registry só roda com `vars.*_ENABLED == 'true'`. Sem a var, o job/step é
  **SKIPPED** (verde) — uma tag não falha nem vaza nada por engano. Para
  desligar de novo, basta remover a variável.
- **Sem tokens de PyPI no repo.** Trusted Publishing (OIDC) emite credencial
  efêmera por execução. `id-token: write` é o único privilégio do job PyPI.
- **Tokens dos demais registries em Secrets**, expostos só no step de publish
  (npm via `NODE_AUTH_TOKEN`; crates via `CARGO_REGISTRY_TOKEN`; NuGet via env
  `$NUGET_API_KEY`; Maven via settings.xml). Nunca interpolados inline em `run:`.
- **Proveniência:** npm publica com `--provenance` (attestation sigstore ligada
  ao workflow). PyPI já tem SBOM/checksums; Maven assina com GPG.
- **Actions de terceiros pinadas por SHA** em todos os `release-*.yml` do GitHub
  (não por tag móvel). Ao bumpar via Dependabot, conferir o SHA contra a release
  oficial.
- **`SHA256SUMS`** e **`sbom.cdx.json`** (CycloneDX, via syft) acompanham cada
  Release para verificação e inventário de dependências.
- **Assinatura GPG dos artefatos do Release** (A-REL1, nice-to-have): ainda não
  implementada para o Release Python. Quando for, assinar `SHA256SUMS` e anexar
  o `.asc`. (Maven Central já exige GPG por conta própria — ver acima.)

## SHAs das actions pinadas (referência)

| Action | Versão | SHA | Usada em |
|---|---|---|---|
| `actions/checkout` | v4.2.2 | `11bd71901bbe5b1630ceea73d27597364c9af683` | todos |
| `actions/setup-python` | v5.3.0 | `0b93645e9fea7318ecaed2b359559ac225c90a2b` | python |
| `actions/setup-node` | v4.1.0 | `39370e3970a6d050c480ffad4ff0ed4d3fdee5af` | node |
| `dtolnay/rust-toolchain` | stable @ 2026-03-27 | `29eef336d9b2848a0b548edc03f92a220660cdb8` | rust |
| `actions/setup-dotnet` | v4.1.0 | `3e891b0cb619bf60e2c25674b222b8940e2c1c25` | csharp |
| `actions/setup-java` | v4.6.0 | `7a6d8a8234af8eb26422e24e3006232cccaa061b` | java |
| `actions/upload-artifact` | v4.4.3 | `b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882` | python |
| `actions/download-artifact` | v4.1.8 | `fa0a91b85d4f404e444e00e005971372dc801d16` | python |
| `pypa/gh-action-pypi-publish` | v1.14.0 | `cef221092ed1bacb1cc03d23a2d87d1d172e277b` | python |
| `softprops/action-gh-release` | v3.0.0 | `b4309332981a82ec1c5618f44dd2e27cc8bfbfda` | python |
| `anchore/sbom-action` | v0.24.0 | `e22c389904149dbc22b58101806040fa8d37a610` | python |

No `.forgejo/workflows/release.yml`, `actions/checkout`/`setup-python` ficam por
tag móvel (`@v4`/`@v5`), seguindo a convenção dos demais workflows Forgejo do
repo; só `anchore/sbom-action` é pinada por SHA (consistência com o GitHub).
