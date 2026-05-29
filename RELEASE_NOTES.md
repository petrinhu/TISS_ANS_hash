# TISS_ANS_hash v0.2.1

Patch sobre a v0.2.0: o **jar prebuilt do Kotlin volta a ser anexado** ao release (build do Kotlin no CI corrigido), e adiciona o **`AGENTS.md`** (guia para IA/agente que usa a lib). 13 ports, sem mudança no algoritmo. Detalhe no [`CHANGELOG.md`](CHANGELOG.md).

Expansão para **13 ports**. A biblioteca calcula o **hash MD5 do epílogo (`<ans:hash>`) de documentos XML do Padrão TISS/ANS** (o valor que a ANS aceita para garantir que um lote não foi adulterado). Segredo: os bytes alimentados ao MD5 são **UTF-8**, não ISO-8859-1.

Novo por aqui? Comece em [`docs/CONCEITOS.md`](docs/CONCEITOS.md), depois [`docs/TUTORIAL.md`](docs/TUTORIAL.md) ou [`docs/USAGE.md`](docs/USAGE.md).

## Novidades da v0.2.1

- **Jar do Kotlin de volta ao release** dos dois hosts (build do Kotlin corrigido na CI): o prebuilt `tiss-hash-kotlin-0.1.0.jar` está anexado tanto no GitHub quanto no Codeberg.
- **`AGENTS.md`** na raiz: guia para uma IA/agente de código que usa a lib (não reimplementar, contrato de rejeição, como validar, regras de privacidade/LGPD).
- 13 ports, sem mudança no algoritmo (20/20 vetores + 3/3 goldens reais).

## Expansão para 13 ports (vinda da v0.2.0)

4 linguagens novas, todas com resultado **idêntico byte a byte** às outras (20 vetores + 3 goldens reais, 13/13 ports x 3/3 PASS):

- **Kotlin** (`langs/kotlin/`): JVM, Android/multiplatform.
- **Object Pascal / Free Pascal** (`langs/delphi/`): legado de faturamento médico BR (Delphi).
- **Dart** (`langs/dart/`): mobile cross-platform (Flutter).
- **WASM** (`langs/wasm/`): hash **client-side no browser** (core Rust via wasm-bindgen). Argumento LGPD: o XML com dados pessoais nunca sai da máquina do usuário. Ver [`docs/adr/0006-wasm-port.md`](docs/adr/0006-wasm-port.md).

## 13 ports (resultado idêntico)

Python, Rust, C, C++, Node.js, PHP, Java, Go, C#, **Kotlin, Delphi/FPC, Dart, WASM**.

## Como obter

- **Python (PyPI)**: `pip install tiss-hash`, publicado em [pypi.org/project/tiss-hash](https://pypi.org/project/tiss-hash/).
- **Node.js (npm)**: `npm install tiss-hash`, publicado em [npmjs.com/package/tiss-hash](https://www.npmjs.com/package/tiss-hash).
- **Rust (crates.io)**: `cargo add tiss-hash`, publicado em [crates.io/crates/tiss-hash](https://crates.io/crates/tiss-hash) (docs em [docs.rs/tiss-hash](https://docs.rs/tiss-hash)).
- **Go**: `go get github.com/petrinhu/TISS_ANS_hash/langs/go@v0.2.1` (resolvido pela tag, via proxy do Go / pkg.go.dev).
- **Código-fonte**: tarball desta release (anexo) ou `git clone` na tag `v0.2.1`. Todos os ports buildam do fonte (README de cada `langs/<lang>/`).
- **Artefatos prontos** (anexos): wheel/sdist (Python), jar (Java, Kotlin), nupkg (C#), crate (Rust), tgz (Node), libs (C), pkg WASM. A partir da v0.2.1, **todos os artefatos prebuilt estão presentes nos releases dos dois hosts** (GitHub e Codeberg), incluindo o jar do Kotlin (`tiss-hash-kotlin-0.1.0.jar`). O port Kotlin também builda do fonte com `./build.sh jar` (ver [`langs/kotlin/`](langs/kotlin/)).
- **Demais registries** (Packagist, Maven Central, NuGet, pub.dev, e npm para o WASM): em preparação; workflows prontos, ver [`docs/RELEASING.md`](docs/RELEASING.md). Por enquanto, instalar esses ports a partir do checkout (ver [`docs/USAGE.md`](docs/USAGE.md)).

## Verificação de integridade

`SHA256SUMS` + SBOM (CycloneDX) anexos.

## Licença

MIT. Atribuições de terceiros em [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md). Changelog: [`CHANGELOG.md`](CHANGELOG.md).
