# Changelog

Todas as mudanças notáveis a este projeto serão documentadas neste arquivo.

O formato segue [Keep a Changelog 1.1.0](https://keepachangelog.com/pt-BR/1.1.0/), e o projeto adere a [Versionamento Semântico (SemVer)](https://semver.org/lang/pt-BR/).

A versão da **especificação canônica** do algoritmo é versionada separadamente em [`docs/SPEC.md`](docs/SPEC.md) (frontmatter `version:`). Mudanças no algoritmo que afetem o hash produzido para um mesmo XML quebram a major version de TODOS os ports.

A versão de **cada port** é independente, declarada em seu próprio pacote (ex.: `langs/python/pyproject.toml`). Este changelog agrega os marcos relevantes do monorepo.

## [Unreleased]

### Added

- (vazio; próximas mudanças aqui)

### Changed

- (vazio)

### Fixed

- (vazio)

### Deprecated

- (vazio)

### Removed

- (vazio)

### Security

- (vazio)

## [0.1.0] - 2026-05-27

Primeiro release público. Algoritmo extraído, especificado, validado e empacotado em Python.

### Added

- **Algoritmo de referência** em Python (`conformance/reference.py`), validado byte-a-byte contra 3 XMLs reais com hashes confirmados pela ANS (validação privada, fora do repo).
- **Fixture de conformidade pública** com 15 vetores sintéticos cobrindo todos os casos de borda relevantes:
  - `syn_minimal.xml`: cabeçalho + epílogo mínimo.
  - `syn_acento.xml`: discriminador de encoding UTF-8 vs ISO-8859-1.
  - `syn_empty.xml`: campos vazios (`<x></x>` e self-closing `<y/>`).
  - `syn_crlf_value.xml`: CR/LF preservado dentro de valor.
  - `syn_multi_guia.xml`: múltiplas guias, ordem documental.
  - `syn_entidades_xml.xml`: entidades XML predefinidas decodificadas pelo parser.
  - `syn_cdata.xml`: seção CDATA tratada como texto literal.
  - `syn_comentario.xml`: comentários XML entram no concat (ambiguidade fixada).
  - `syn_atributo_folha.xml`: atributos não entram no concat.
  - `syn_namespace_xsi.xml`: prefixo de namespace em atributo ignorado.
  - `syn_whitespace_puro.xml`: espaços puros preservados literalmente.
  - `syn_leading_zero.xml`: zeros à esquerda preservados.
  - `syn_iso8859_simbolos.xml`: símbolos ISO-8859-1 puros.
  - `syn_perf_grande.xml`: ~600KB, ~1500 guias (performance).
  - `syn_bom_utf8.xml`: BOM UTF-8 (TISS proíbe, mas a referência aceita).
- **Especificação canônica** em [`docs/SPEC.md`](docs/SPEC.md), incluindo pseudo-código, diagrama de fluxo, caveat de encoding UTF-8.
- **Guia de port** em [`docs/PORTING_GUIDE.md`](docs/PORTING_GUIDE.md) para implementar em novas linguagens.
- **Visão arquitetural** em [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
- **Architecture Decision Records** 0001-0004 em [`docs/adr/`](docs/adr/):
  - ADR-0001: port nativo por linguagem (vs core C + FFI).
  - ADR-0002: layout do monorepo.
  - ADR-0003: estratégia de packaging e versionamento.
  - ADR-0004: matriz de CI.
- **Port Python** (`langs/python/`, pacote `tiss-hash`) com 19 testes passando: 15 vetores de conformidade + 4 testes de API auxiliares.
  - API pública: `hash_tiss(bytes) -> str`, `hash_tiss_file(path) -> str`, `InvalidTissXml`.
  - Parser endurecido com `defusedxml` (proteção contra XXE e billion-laughs).
  - Type hints completos; suporte a Python 3.10+.
- **Documentação de uso** em [`docs/USAGE.md`](docs/USAGE.md): instalação, quickstart, receitas (FastAPI, Flask, batch), pegadinhas, FAQ.
- **Documentação legal**:
  - [`docs/legal/LGPD-NOTE.md`](docs/legal/LGPD-NOTE.md): obrigações do integrador.
  - [`docs/legal/DISCLAIMER.md`](docs/legal/DISCLAIMER.md): limites de responsabilidade.
  - [`docs/legal/TISS-COMPLIANCE.md`](docs/legal/TISS-COMPLIANCE.md): escopo TISS.
- **Política de contribuição**: [`CONTRIBUTING.md`](CONTRIBUTING.md), [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) (Contributor Covenant 2.1), [`SECURITY.md`](SECURITY.md).
- **Templates de issue e PR** para GitHub (`.github/`) e Codeberg/Forgejo (`.forgejo/`).
- **Repositórios públicos**: GitHub [`petrinhu/TISS_ANS_hash`](https://github.com/petrinhu/TISS_ANS_hash) e Codeberg [`petrinhu/TISS_ANS_hash`](https://codeberg.org/petrinhu/TISS_ANS_hash) (mirror sincronizado via dual push).
- **Licença MIT** ([`LICENSE`](LICENSE)).

### Notes

- **Predecessor arquivado**: o projeto `TISSGama` (editor desktop específico para a operadora Gama Saúde) foi arquivado nos dois mirrors em 2026-05-27, dado que a operadora deixou de existir. O algoritmo de hash MD5 foi extraído e migrou para este projeto. Repositórios originais permanecem privados e arquivados (read-only).
- **XMLs reais removidos** do repositório: durante a engenharia reversa do algoritmo, 3 XMLs reais com hashes confirmados pela ANS serviram como ground truth. Esses arquivos contêm PII de pacientes e **não estão no repositório público** (LGPD, Lei 13.709/2018, art. 5º, II). Permanecem em diretório privado do mantenedor e são usados apenas como validação pré-release adicional. A suíte pública de 15 vetores sintéticos é suficiente para garantir conformidade byte-a-byte.
- **Versão do padrão TISS** coberta: 4.01.00.
- **Cobertura de port**: apenas Python neste release. C, C++, Rust, PHP, Node.js e demais linguagens estão planejados (ver [`README.md`](README.md#linguagens-alvo)).

---

[Unreleased]: https://github.com/petrinhu/TISS_ANS_hash/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/petrinhu/TISS_ANS_hash/releases/tag/v0.1.0
