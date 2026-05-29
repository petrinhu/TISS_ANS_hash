# TISS_ANS_hash v0.1.0

Primeiro release público. A biblioteca calcula o **hash MD5 do epílogo (`<ans:hash>`) de documentos XML do Padrão TISS/ANS** — o valor que a ANS aceita para garantir que um lote não foi adulterado. O segredo, não óbvio pelo manual: os bytes alimentados ao MD5 são **UTF-8**, não ISO-8859-1.

Novo por aqui? Comece em [`docs/CONCEITOS.md`](docs/CONCEITOS.md) (o que é e para que serve, em linguagem simples), depois [`docs/TUTORIAL.md`](docs/TUTORIAL.md) (mão na massa) ou [`docs/USAGE.md`](docs/USAGE.md) (sua linguagem).

## O que tem neste release

- **9 ports nativos**, todos com resultado **idêntico byte-a-byte**: Python, Rust, C, C++, Node.js, PHP, Java, Go, C#.
- **Suíte de conformidade pública**: 20 vetores 100% sintéticos (18 positivos + 2 negativos de rejeição). Zero dado de paciente no repositório (LGPD).
- **Documentação nível-iniciante**: conceitos, tutorial passo a passo, guia de uso por linguagem, FAQ + glossário.
- **Segurança**: XXE fechado no port C; rejeição explícita de múltiplos `<ans:hash>` e de encoding UTF-16/UTF-32 (em vez de hash silenciosamente errado).
- **CI dual-host** (GitHub Actions + Forgejo/Codeberg): build+test+lint+coverage+CVE scan nos 9 ports.

## Como obter

- **Código-fonte**: baixe o tarball desta release (anexo) ou `git clone` na tag `v0.1.0`. Todos os ports buildam do fonte (ver README de cada `langs/<lang>/`).
- **Go**: já funciona direto da tag, sem registry:
  ```
  go get github.com/petrinhu/TISS_ANS_hash/langs/go@v0.1.0
  ```
- **Python / Node / Rust / PHP / Java / C#**: a publicação nos registries (PyPI, npm, crates.io, Packagist, Maven Central, NuGet) está **em preparação**. Por enquanto, instale a partir do checkout (instruções em [`docs/USAGE.md`](docs/USAGE.md) e no README de cada port). Os workflows de publicação já existem; ver [`docs/RELEASING.md`](docs/RELEASING.md).

## Verificação de integridade

Cada anexo tem seu hash em `SHA256SUMS` (também anexo). Há um SBOM (CycloneDX) listando dependências.

## Licença

MIT. Atribuições de terceiros em [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).

Changelog completo: [`CHANGELOG.md`](CHANGELOG.md).
