# TISS_ANS_hash · lib hash TISS / ANS

> **Biblioteca multi-linguagem (Python, Rust, C, C++, Node.js, PHP) para gerar o hash MD5 do epílogo XML do Padrão TISS/ANS 4.01.00 (saúde suplementar Brasil).**
> Multi-language library (Python, Rust, C, C++, Node.js, PHP) to generate the MD5 hash of the epilogue tag in TISS/ANS XML messages (Brazilian healthcare data exchange standard, 4.01.00).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Codeberg CI](https://ci.codeberg.org/api/badges/petrinhu/TISS_ANS_hash/status.svg)](https://ci.codeberg.org/petrinhu/TISS_ANS_hash)
[![GitHub Actions](https://github.com/petrinhu/TISS_ANS_hash/actions/workflows/python.yml/badge.svg)](https://github.com/petrinhu/TISS_ANS_hash/actions)
[![PyPI version](https://img.shields.io/pypi/v/tiss-hash.svg)](https://pypi.org/project/tiss-hash/)
[![Spec](https://img.shields.io/badge/spec-v1.0.0-blue)](docs/SPEC.md)
[![Conformance Vectors](https://img.shields.io/badge/conformance-15%20vectors-success)](conformance/vectors.json)
[![TISS Standard](https://img.shields.io/badge/TISS-4.01.00-blue)](docs/SPEC.md)
[![Codeberg](https://img.shields.io/badge/mirror-Codeberg-2185D0)](https://codeberg.org/petrinhu/TISS_ANS_hash)
[![GitHub](https://img.shields.io/badge/mirror-GitHub-181717)](https://github.com/petrinhu/TISS_ANS_hash)

## O que é

`lib_hash_ans` é uma coleção de bibliotecas independentes, uma por linguagem-alvo, que calculam o hash MD5 do epílogo de mensagens TISS/ANS (padrão da Agência Nacional de Saúde Suplementar para troca de dados entre operadoras de saúde e prestadores no Brasil).

Todas as implementações reproduzem **byte a byte** o mesmo algoritmo, validado contra goldens reais (privados, em poder do mantenedor) e contra 15 vetores sintéticos públicos. Definição canônica em [`docs/SPEC.md`](docs/SPEC.md). Suíte de conformidade pública em [`conformance/`](conformance/).

## O que NÃO faz

- Não persiste nada.
- Não transmite nada para a ANS nem para operadora.
- Não valida o XML contra XSD oficial.
- Não assina digitalmente.
- Não monta a mensagem TISS por você.

Você passa bytes de XML, recebe 32 caracteres hex. Fim.

## Por que existe

O algoritmo do hash foi reverse-engineered porque:

- O manual oficial TISS é ambíguo sobre o encoding usado no MD5 (diz "ISO-8859-1", mas o que funciona é UTF-8; ver [SPEC §4](docs/SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1)).
- Implementações existentes erram silenciosamente, produzindo hashes que a ANS rejeita.
- XMLs reais com hashes confirmados pela ANS serviram de ground truth durante a engenharia reversa.

Este projeto **substitui** o TISSGama (arquivado), editor desktop para a operadora Gama Saúde (extinta). Apenas o algoritmo de hash foi preservado e empacotado como biblioteca multi-linguagem para uso por qualquer fornecedor TISS.

## Linguagens-alvo

### Tier 1: declarado pelo usuário

| Linguagem | Status         | Pasta                | Notas                                |
|-----------|----------------|----------------------|--------------------------------------|
| Python    | pronto         | `langs/python/`      | 19 testes passando, lib `tiss-hash`  |
| C         | planejado      | `langs/c/`           | base p/ FFI, possível core comum     |
| C++       | planejado      | `langs/cpp/`         | header-only desejável                |
| Rust      | planejado      | `langs/rust/`        | crate + WASM target                  |
| PHP       | planejado      | `langs/php/`         | composer package                     |
| Node.js   | planejado      | `langs/nodejs/`      | package npm, TypeScript types        |

### Tier 2: relevantes no ecossistema BR

| Linguagem              | Status     | Justificativa                                |
|------------------------|------------|----------------------------------------------|
| Java                   | planejado  | ERP/hospitalar enterprise                    |
| Kotlin                 | planejado  | Android + multiplatform                      |
| C# / .NET              | planejado  | desktop de clínica                           |
| Delphi / Object Pascal | planejado  | legado massivo de faturamento médico BR      |
| Go                     | planejado  | backend, microsserviços                      |
| Dart / Flutter         | planejado  | mobile cross-platform                        |
| WASM                   | planejado  | hash client-side no browser, argumento LGPD  |

Legenda: `planejado` (não iniciado), `em progresso` (código existe, vetores parciais), `pronto` (15/15 vetores PASS + docs + release).

## Quickstart

### Usando o port Python (pronto)

```bash
pip install tiss-hash
```

```python
from tiss_hash import hash_tiss_file

digest = hash_tiss_file("envio.xml")
print(digest)  # 32 chars hex minúsculos
```

Mais exemplos, receitas e FAQ em [`docs/USAGE.md`](docs/USAGE.md).

### Validando a implementação de referência

```bash
cd conformance
python3 build_fixture.py
```

Saída esperada:

```
OK: 15 vetores sinteticos
  3aa0c578c95cdb861a125f480a8a4de5  syn_minimal.xml         [derived]
  a20afc9a89aadaa2179d03d225337662  syn_acento.xml          [derived]
  ...
```

Calcular hash de um arquivo via referência:

```bash
cd conformance
python3 reference.py inputs/syn_minimal.xml
# 3aa0c578c95cdb861a125f480a8a4de5  inputs/syn_minimal.xml
```

Pré-requisitos: Python 3.10+, `lxml` (para a referência).

## Documentação

- [`docs/USAGE.md`](docs/USAGE.md): Guia de uso, receitas e FAQ (how-to).
- [`docs/SPEC.md`](docs/SPEC.md): Especificação canônica do algoritmo (reference).
- [`docs/PORTING_GUIDE.md`](docs/PORTING_GUIDE.md): Como portar para uma nova linguagem (how-to).
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): Visão arquitetural do monorepo (explanation).
- [`docs/adr/`](docs/adr/): Architecture Decision Records.
- [`docs/legal/LGPD-NOTE.md`](docs/legal/LGPD-NOTE.md): Aviso LGPD para integradores.
- [`docs/legal/DISCLAIMER.md`](docs/legal/DISCLAIMER.md): Disclaimer técnico/legal.
- [`docs/legal/TISS-COMPLIANCE.md`](docs/legal/TISS-COMPLIANCE.md): Escopo de conformidade com o padrão TISS.
- [`CHANGELOG.md`](CHANGELOG.md): Histórico de versões (Keep a Changelog + SemVer).
- [`CONTRIBUTING.md`](CONTRIBUTING.md): Como contribuir, dual push GitHub + Codeberg.
- [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md): Contributor Covenant 2.1.
- [`SECURITY.md`](SECURITY.md): Política de divulgação responsável.

## Privacidade dos vetores

O repositório público contém **somente 15 vetores sintéticos** que cobrem todos os casos de borda relevantes (acentuação, CR/LF, comentário, CDATA, BOM, namespace, atributo em folha, performance, etc.; ver [`conformance/TEST_PLAN.md`](conformance/TEST_PLAN.md)).

XMLs reais usados durante a engenharia reversa (com hashes confirmados pela ANS) **foram removidos** do repositório por conterem PII de pacientes (LGPD, Lei 13.709/2018, art. 5º, II). Eles vivem em diretório privado fora do repo, em poder do mantenedor, e servem como validação adicional pré-release. O conjunto sintético público é suficiente para garantir conformidade byte-a-byte de qualquer port.

## Aviso LGPD

Mensagens TISS contêm **dados pessoais sensíveis de saúde** (Lei 13.709/2018, art. 5º, II). Esta lib **apenas calcula um hash em memória** e não transmite, persiste ou registra o conteúdo. Mesmo assim, o integrador que processa XMLs TISS é controlador/operador dos dados e responde pelo tratamento conforme LGPD.

Recomendações mínimas:

- Não logar conteúdo de XML processado.
- Limpar buffers após uso.
- Restringir acesso ao processo que executa a lib.
- Considerar execução client-side (WASM) quando o caso de uso permitir, para evitar trânsito do dado.

Detalhamento em [`docs/legal/LGPD-NOTE.md`](docs/legal/LGPD-NOTE.md).

## Estrutura do repositório

```
lib_hash_ans/
├── README.md                  # este arquivo
├── CHANGELOG.md               # Keep a Changelog
├── CONTRIBUTING.md            # como contribuir, dual push
├── CODE_OF_CONDUCT.md         # Contributor Covenant 2.1
├── SECURITY.md                # política de segurança
├── LICENSE                    # MIT (a criar inline)
├── docs/
│   ├── USAGE.md               # guia de uso (how-to)
│   ├── SPEC.md                # algoritmo canônico (reference)
│   ├── PORTING_GUIDE.md       # como implementar em nova linguagem (how-to)
│   ├── ARCHITECTURE.md        # visão arquitetural (explanation)
│   ├── adr/                   # Architecture Decision Records
│   └── legal/                 # LGPD, disclaimer, TISS compliance
├── conformance/
│   ├── reference.py           # impl. de referência Python (autoridade executável)
│   ├── build_fixture.py       # regera vectors.json
│   ├── vectors.json           # manifesto: 15 vetores sintéticos
│   ├── inputs/                # XMLs sintéticos públicos (sem PII)
│   ├── TEST_PLAN.md           # plano de teste e cobertura
│   └── AMBIGUITY_NOTES.md     # decisões fixadas pela referência
├── langs/
│   └── python/                # port Python pronto (tiss-hash)
├── .github/                   # templates de issue/PR (GitHub)
└── .forgejo/                  # templates de issue/PR (Codeberg/Forgejo)
```

## Histórico

- 2026-05-27: projeto criado. Algoritmo extraído do TISSGama. 15 vetores sintéticos travados. Port Python liberado (19 testes passando). XMLs reais retirados do repo (LGPD). Repos públicos novos: GitHub `petrinhu/TISS_ANS_hash` + Codeberg `petrinhu/TISS_ANS_hash`. Predecessor TISSGama arquivado.

## Termos relacionados (busca / SEO)

Se você procurou por algum dos termos abaixo e chegou aqui, é exatamente este o projeto:

- hash TISS, hash ANS, hash TISS ANS, hash MD5 TISS, hash MD5 ANS
- lib hash ANS, lib hash TISS, biblioteca hash TISS, biblioteca hash ANS
- cálculo hash Padrão TISS, cálculo hash epílogo TISS, MD5 epílogo TISS
- Padrão TISS 4.01.00, TISS 401, padrao TISS hash, epilogo TISS hash
- hash XML ANS, XML TISS hash, ans:hash, &lt;ans:hash&gt;
- saúde suplementar Brasil hash, operadora hash TISS, prestador hash TISS
- tiss-hash Python, tiss-hash Rust, tiss-hash Node, tiss-hash PHP, tiss-hash C, tiss-hash C++
- ans hash xml utf-8, tiss hash não bate, hash tiss errado, hash tiss rejeitado, hash tiss divergente
- ANS XML hash library, TISS supplementary health hash, Brazilian healthcare XML MD5

Especificação completa do algoritmo (incluindo a divergência UTF-8 vs ISO-8859-1 do manual oficial): [`docs/SPEC.md`](docs/SPEC.md).

## Licença

[MIT](LICENSE). Uso livre, comercial e não-comercial, com manutenção do aviso de copyright.

## Contribuindo

Para portar uma nova linguagem, ver [`docs/PORTING_GUIDE.md`](docs/PORTING_GUIDE.md). Para o fluxo de contribuição (dual push GitHub + Codeberg, Conventional Commits, checklist de PR), ver [`CONTRIBUTING.md`](CONTRIBUTING.md). PR deve ter os 15 vetores de conformidade passando.

Para reportar imprecisão na spec ou nos vetores, abrir issue com label `spec` ou `conformance` no [GitHub](https://github.com/petrinhu/TISS_ANS_hash/issues) ou no [Codeberg](https://codeberg.org/petrinhu/TISS_ANS_hash/issues).
