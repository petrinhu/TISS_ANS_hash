# TISS_ANS_hash v0.2.1

Patch sobre a v0.2.0: o **jar prebuilt do Kotlin volta a ser anexado** ao release (build do Kotlin no CI corrigido), e adiciona o **`AGENTS.md`** (guia para IA/agente que usa a lib). 13 ports, sem mudança no algoritmo. Detalhe no [`CHANGELOG.md`](CHANGELOG.md).

Expansão para **13 ports**. A biblioteca calcula o **hash MD5 do epílogo (`<ans:hash>`) de documentos XML do Padrão TISS/ANS** (o valor que a ANS aceita para garantir que um lote não foi adulterado). Segredo: os bytes alimentados ao MD5 são **UTF-8**, não ISO-8859-1.

Novo por aqui? Comece em [`docs/CONCEITOS.md`](docs/CONCEITOS.md), depois [`docs/TUTORIAL.md`](docs/TUTORIAL.md) ou [`docs/USAGE.md`](docs/USAGE.md).

## Novidades da v0.2.0

4 linguagens novas, todas com resultado **idêntico byte a byte** às outras (20 vetores + 3 goldens reais, 13/13 ports x 3/3 PASS):

- **Kotlin** (`langs/kotlin/`): JVM, Android/multiplatform.
- **Object Pascal / Free Pascal** (`langs/delphi/`): legado de faturamento médico BR (Delphi).
- **Dart** (`langs/dart/`): mobile cross-platform (Flutter).
- **WASM** (`langs/wasm/`): hash **client-side no browser** (core Rust via wasm-bindgen). Argumento LGPD: o XML com dados pessoais nunca sai da máquina do usuário. Ver [`docs/adr/0006-wasm-port.md`](docs/adr/0006-wasm-port.md).

## 13 ports (resultado idêntico)

Python, Rust, C, C++, Node.js, PHP, Java, Go, C#, **Kotlin, Delphi/FPC, Dart, WASM**.

## Como obter

- **Código-fonte**: tarball desta release (anexo) ou `git clone` na tag `v0.2.0`. Todos os ports buildam do fonte (README de cada `langs/<lang>/`).
- **Go**: `go get github.com/petrinhu/TISS_ANS_hash/langs/go@v0.2.0`
- **Artefatos prontos** (anexos): wheel/sdist (Python), jar (Java, Kotlin), nupkg (C#), crate (Rust), tgz (Node), libs (C), pkg WASM.

  > **Jar do Kotlin:** o jar prebuilt do Kotlin **não** está anexado ao release do **GitHub** v0.2.0 (falha do build Kotlin na primeira execução da CI, já corrigida para os próximos releases); ele está no release do **Codeberg** v0.2.0. Em qualquer caso, o port Kotlin builda do fonte com `./build.sh jar` (ver [`langs/kotlin/`](langs/kotlin/)).
- **Registries** (PyPI, npm, crates.io, Packagist, Maven Central, NuGet): em preparação; workflows prontos, ver [`docs/RELEASING.md`](docs/RELEASING.md). Por enquanto, instalar a partir do checkout (ver [`docs/USAGE.md`](docs/USAGE.md)).

## Verificação de integridade

`SHA256SUMS` + SBOM (CycloneDX) anexos.

## Licença

MIT. Atribuições de terceiros em [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md). Changelog: [`CHANGELOG.md`](CHANGELOG.md).
