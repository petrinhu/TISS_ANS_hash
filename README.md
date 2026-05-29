# TISS_ANS_hash · lib hash TISS / ANS

> **Biblioteca multi-linguagem (Python, Rust, C, C++, Node.js, PHP, Java, Go, C#) para gerar o hash MD5 do epílogo XML do Padrão TISS/ANS (saúde suplementar Brasil).**
> Multi-language library (Python, Rust, C, C++, Node.js, PHP, Java, Go, C#) to generate the MD5 hash of the epilogue tag in TISS/ANS XML messages (Brazilian healthcare data exchange standard).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions%20%2B%20Forgejo%20Actions-success)](https://github.com/petrinhu/TISS_ANS_hash/actions)
[![PyPI version](https://img.shields.io/pypi/v/tiss-hash.svg)](https://pypi.org/project/tiss-hash/)
[![Spec](https://img.shields.io/badge/spec-v1.0.0-blue)](docs/SPEC.md)
[![Conformance Vectors](https://img.shields.io/badge/conformance-20%20vectors-success)](conformance/vectors.json)
[![TISS Standard](https://img.shields.io/badge/Padr%C3%A3o-TISS-blue)](docs/SPEC.md)
[![Codeberg](https://img.shields.io/badge/mirror-Codeberg-2185D0)](https://codeberg.org/petrinhu/TISS_ANS_hash)
[![GitHub](https://img.shields.io/badge/mirror-GitHub-181717)](https://github.com/petrinhu/TISS_ANS_hash)

> CI: cada um dos 9 ports roda em duas plataformas, **GitHub Actions** (`.github/workflows/<lang>.yml`) e **Forgejo Actions** no Codeberg (`.forgejo/workflows/<lang>.yml`).

## O que é

`lib_hash_ans` é uma coleção de bibliotecas independentes, uma por linguagem-alvo, que calculam o hash MD5 do epílogo de mensagens TISS/ANS (padrão da Agência Nacional de Saúde Suplementar para troca de dados entre operadoras de saúde e prestadores no Brasil).

Todas as implementações reproduzem **byte a byte** o mesmo algoritmo, validado contra goldens reais (privados, em poder do mantenedor) e contra 20 vetores de conformidade públicos (18 positivos + 2 negativos). Definição canônica em [`docs/SPEC.md`](docs/SPEC.md). Suíte de conformidade pública em [`conformance/`](conformance/).

## O que NÃO faz

- Não persiste nada.
- Não transmite nada para a ANS nem para operadora.
- Não valida o XML contra XSD oficial.
- Não assina digitalmente.
- Não monta a mensagem TISS por você.

Você passa bytes de XML, recebe 32 caracteres hex. Fim.

## Por que existe (história)

Se você procurou por "hash TISS não bate", "hash tiss rejeitado pela ANS", "MD5 epílogo divergente", "ans:hash errado" ou similar, este projeto foi feito exatamente pra isso.

**O problema:** o manual oficial do Padrão TISS (Componente Organizacional, ANS) diz textualmente que o encoding usado no cálculo do hash MD5 é **ISO-8859-1**. Implementar literalmente essa instrução produz hashes que a ANS **rejeita**. O encoding correto, na prática, é **UTF-8**. Essa divergência custou anos de retrabalho a vários fornecedores TISS (busque "hash tiss errado" em fóruns de saúde suplementar e veja).

**A engenharia reversa:** o algoritmo correto foi extraído de **três XMLs reais com hashes confirmados pela ANS** (golden vectors). Validação por bisseção: somente a combinação `concat-de-folhas + UTF-8 + MD5` reproduz os três hashes; toda outra falha. Detalhes da reversão e da divergência ISO vs UTF-8 em [`docs/SPEC.md §4 e §9`](docs/SPEC.md).

**A garantia:** 20 vetores de conformidade públicos (18 positivos + 2 negativos) travam todos os casos de borda (acentuação, CR/LF dentro de valor, CDATA, entidades XML, comentários, atributos, namespaces, BOM UTF-8, whitespace puro, leading zeros, símbolos ISO-8859-1, multi-guia, documento grande). Cada port em cada linguagem **tem que** bater byte-a-byte contra os 20 antes de qualquer release.

**Origem:** algoritmo extraído de um editor desktop legado (TISSGama, arquivado) que foi descontinuado junto com o contexto cliente original. O algoritmo sobreviveu porque o Padrão TISS continua sendo usado por toda a saúde suplementar brasileira, e qualquer fornecedor TISS tem o mesmo problema de encoding enquanto a ANS não corrigir o manual.

**O que esta lib oferece de diferente** vs reinventar a roda:

- Algoritmo validado contra hashes aceitos pela ANS (não contra interpretação literal do manual).
- 9 ports independentes (Python, Rust, C, C++, Node.js, PHP, Java, Go, C#), pega errado em um, não pega nos outros (cross-port equivalence é parte da CI).
- Fixture de conformidade portável: mesmo `vectors.json` roda em todos os ports.
- Documentação explícita das pegadinhas (encoding, comentários XML que entram no concat, CDATA tratado como texto, etc).

## Linguagens-alvo

### Ports prontos (9)

Todos passam a suíte de conformidade byte-a-byte (20 vetores) na CI das duas plataformas.

| Linguagem | Status     | Pasta             | Notas                                |
|-----------|------------|-------------------|--------------------------------------|
| Python    | ✅ pronto  | `langs/python/`   | lib `tiss-hash`, 19 testes passando  |
| Rust      | ✅ pronto  | `langs/rust/`     | crate                                |
| C         | ✅ pronto  | `langs/c/`        | base p/ FFI, core comum              |
| C++       | ✅ pronto  | `langs/cpp/`      | header-friendly                      |
| Node.js   | ✅ pronto  | `langs/node/`     | package npm, TypeScript types        |
| PHP       | ✅ pronto  | `langs/php/`      | composer package                     |
| Java      | ✅ pronto  | `langs/java/`     | ERP/hospitalar enterprise            |
| Go        | ✅ pronto  | `langs/go/`       | backend, microsserviços              |
| C# / .NET | ✅ pronto  | `langs/csharp/`   | desktop de clínica                   |

### Candidatos futuros (ecossistema BR)

Avaliados, ainda não iniciados:

| Linguagem              | Justificativa                                |
|------------------------|----------------------------------------------|
| Kotlin                 | Android + multiplatform                      |
| Delphi / Object Pascal | legado massivo de faturamento médico BR      |
| Dart / Flutter         | mobile cross-platform                        |
| WASM                   | hash client-side no browser, argumento LGPD  |

Legenda: `✅ pronto` (20/20 vetores PASS na CI + docs + packaging).

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
OK: 20 vetores de conformidade (18 positivos + 2 negativos)
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

O repositório público contém **somente vetores sintéticos** (20 no total: 18 positivos + 2 negativos) que cobrem todos os casos de borda relevantes (acentuação, CR/LF, comentário, CDATA, BOM, namespace, atributo em folha, performance, etc.; ver [`conformance/TEST_PLAN.md`](conformance/TEST_PLAN.md)).

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
├── LICENSE                    # MIT
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
│   ├── vectors.json           # manifesto: 20 vetores (18 positivos + 2 negativos)
│   ├── inputs/                # XMLs sintéticos públicos (sem PII)
│   ├── TEST_PLAN.md           # plano de teste e cobertura
│   └── AMBIGUITY_NOTES.md     # decisões fixadas pela referência
├── langs/                     # 9 ports independentes, um por linguagem
│   ├── python/                # port Python (tiss-hash)
│   ├── rust/                  # crate Rust
│   ├── c/                     # port C (base p/ FFI)
│   ├── cpp/                   # port C++
│   ├── node/                  # package npm + TypeScript types
│   ├── php/                   # composer package
│   ├── java/                  # port Java
│   ├── go/                    # port Go
│   └── csharp/                # port C# / .NET
├── .github/workflows/         # CI GitHub Actions (1 workflow por port)
└── .forgejo/workflows/        # CI Forgejo Actions no Codeberg (1 por port)
```

## Histórico

- 2026-05-27: projeto criado. Algoritmo extraído de um editor desktop legado descontinuado. 20 vetores de conformidade travados (18 positivos + 2 negativos). 9 ports liberados (Python, Rust, C, C++, Node.js, PHP, Java, Go, C#), todos passando a conformidade byte-a-byte na CI das duas plataformas. XMLs reais retirados do repo (LGPD). Repos públicos: GitHub `petrinhu/TISS_ANS_hash` + Codeberg `petrinhu/TISS_ANS_hash`. Predecessor arquivado.

## Termos relacionados (busca / SEO)

Se você procurou por algum dos termos abaixo e chegou aqui, é exatamente este o projeto:

- hash TISS, hash ANS, hash TISS ANS, hash MD5 TISS, hash MD5 ANS
- lib hash ANS, lib hash TISS, biblioteca hash TISS, biblioteca hash ANS
- cálculo hash Padrão TISS, cálculo hash epílogo TISS, MD5 epílogo TISS
- Padrão TISS, padrao TISS, padrao TISS hash, epilogo TISS hash
- hash XML ANS, XML TISS hash, ans:hash, &lt;ans:hash&gt;
- saúde suplementar Brasil hash, operadora hash TISS, prestador hash TISS
- tiss-hash Python, tiss-hash Rust, tiss-hash Node, tiss-hash PHP, tiss-hash C, tiss-hash C++, tiss-hash Java, tiss-hash Go, tiss-hash C#
- ans hash xml utf-8, tiss hash não bate, hash tiss errado, hash tiss rejeitado, hash tiss divergente
- ANS XML hash library, TISS supplementary health hash, Brazilian healthcare XML MD5

Especificação completa do algoritmo (incluindo a divergência UTF-8 vs ISO-8859-1 do manual oficial): [`docs/SPEC.md`](docs/SPEC.md).

## Licença

[MIT](LICENSE). Uso livre, comercial e não-comercial, com manutenção do aviso de copyright.

## Contribuindo

Para portar uma nova linguagem, ver [`docs/PORTING_GUIDE.md`](docs/PORTING_GUIDE.md). Para o fluxo de contribuição (dual push GitHub + Codeberg, Conventional Commits, checklist de PR), ver [`CONTRIBUTING.md`](CONTRIBUTING.md). PR deve ter os 20 vetores de conformidade passando.

Para reportar imprecisão na spec ou nos vetores, abrir issue com label `spec` ou `conformance` no [GitHub](https://github.com/petrinhu/TISS_ANS_hash/issues) ou no [Codeberg](https://codeberg.org/petrinhu/TISS_ANS_hash/issues).
