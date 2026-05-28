---
name: New port proposal
about: Propor a implementação da lib em uma linguagem ainda não suportada
title: "[port] "
labels:
  - port
  - triage
ref: main
---

## Linguagem-alvo

(ex.: Go, Java, Kotlin, C#, Delphi, Dart, etc.)

## Motivação

(por que essa linguagem? qual público se beneficia? cite ecossistema concreto: ERP hospitalar X usa Java, mobile via Flutter precisa de Dart, etc.)

## Stack proposto

- **Parser XML:** (ex.: `encoding/xml` stdlib Go, `jakarta.xml.bind`, `System.Xml.Linq`, `xml.etree`, etc.)
- **MD5:** (stdlib da linguagem; quase sempre disponível)
- **Build / packaging:** (ex.: Go modules, Maven/Gradle, NuGet, Pub.dev, etc.)
- **Versão mínima de runtime/compilador:** (ex.: Go 1.22+, Java 17+)

## Layout proposto da pasta

```
langs/<linguagem>/
├── README.md
├── (arquivos típicos da linguagem: go.mod / pom.xml / Cargo.toml / package.json)
├── src/
│   └── ...
├── tests/
│   └── ...
└── ...
```

## Manutenção planejada

- **Quem mantém?** (você sozinho / time / open source community)
- **CI proposto:** (Woodpecker no Codeberg / GitHub Actions / matriz)
- **Frequência de release:** (sob demanda / quando a SPEC muda)

## Cobertura de conformidade

A implementação **precisa** passar nos 15 vetores de [`conformance/vectors.json`](../../conformance/vectors.json) byte-a-byte. Confirmação de que você entende isso:

- [ ] Li [`docs/SPEC.md`](../../docs/SPEC.md).
- [ ] Li [`docs/PORTING_GUIDE.md`](../../docs/PORTING_GUIDE.md).
- [ ] Li [`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md).
- [ ] Confirmo que a linguagem-alvo tem parser XML capaz de fornecer iteração em ordem documental com acesso ao texto de cada elemento e detecção de "é folha" (`len(filhos) == 0`).

## Notas adicionais

(quaisquer particularidades da linguagem, limitações conhecidas, alternativas, etc.)
