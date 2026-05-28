# ADR-0001: Port nativo por linguagem (sem FFI / sem core compartilhado)

**Status:** Accepted
**Data:** 2026-05-27
**Decisores:** Petrus (autor/dono do projeto)

## Contexto

O projeto `lib_hash_ans` empacota o algoritmo de hash MD5 do epílogo TISS/ANS
(ver `conformance/reference.py` para a referência canônica). O algoritmo, por
si, é trivial em qualquer linguagem moderna:

1. Parsear XML.
2. Zerar o conteúdo de `<ans:hash>`.
3. Concatenar `.text` de cada elemento-folha em ordem de documento.
4. `MD5(utf-8(concat))`.
5. Retornar 32 chars hex minúsculos.

As três primitivas (parser XML, concat de string, MD5) **existem nativamente
ou via biblioteca-padrão** em todas as linguagens-alvo (C, C++, Rust, Python,
PHP, Node.js, e a Tier 2: Java/Kotlin, C#/.NET, Delphi, Go, Dart/Flutter,
WASM). Nenhuma exige código exótico, SIMD, criptografia avançada nem
matemática numérica delicada.

Volume de código por port estimado: 30-80 linhas (incluindo testes contra
`vectors.json`). Não há compartilhamento de estado, IO bloqueante, nem
fronteira mutável — é uma função pura `bytes -> string`.

Restrição forte do ecossistema-alvo (saúde suplementar BR): muitas casas
rodam stacks legadas (Delphi, .NET Framework antigo, PHP em hospedagem
compartilhada) onde **carregar um `.so` / `.dll` externo é fricção real**
(permissão de hospedagem, antivírus corporativo, compliance, ausência de
toolchain C, deploy em Windows Server sem direitos de admin).

## Decisão

Cada linguagem-alvo recebe **implementação nativa independente**, escrita
idiomaticamente, sem qualquer dependência cruzada de código. O contrato
único compartilhado é o conjunto `conformance/vectors.json` + os XMLs em
`conformance/inputs/`. Todo port deve passar 8/8 vetores byte-a-byte
(hex minúsculo, 32 chars).

A implementação de referência (`conformance/reference.py`) é a definição
executável do algoritmo; em caso de ambiguidade entre prosa e código, **o
código vence**.

## Alternativas consideradas

### Opção A — Core em C + bindings FFI por linguagem

Um único `libhashtiss.so/.dll/.dylib` implementando o algoritmo. Cada
linguagem expõe wrapper FFI (ctypes/cffi em Python, N-API em Node, FFI em
PHP, JNI em Java, P/Invoke em .NET, etc.).

**Prós:**
- Uma única implementação canônica do algoritmo.
- Bugfix se propaga via rebuild de binários.
- Performance previsível (mesmo código em todas as linguagens).

**Contras:**
- **Distribuição multiplica por matriz `OS × arch`**: precisa publicar
  binários para Linux x86_64, Linux arm64, macOS x86_64, macOS arm64,
  Windows x64, Windows x86, FreeBSD (Delphi/Pascal users)... vira projeto
  de release engineering, não de algoritmo.
- **Parsing de XML em C é doloroso** (precisa linkar libxml2 ou escrever
  parser próprio). libxml2 já é dependência transitiva pesada.
- **FFI vaza ABI**: mudança de signature obriga rebuild de TODOS os
  wrappers. Versionar binário + N wrappers é dor real.
- **Hospedagem compartilhada PHP raramente permite carregar `.so`
  customizado** — mata o caso de uso TISS legado.
- **.NET Framework em desktop de clínica** + DLL nativa = inferno de
  deployment (manifest, SxS, antivirus quarantine).
- Complexidade total do projeto cresce desproporcionalmente para um
  algoritmo de 30 linhas.

### Opção B — Port nativo independente por linguagem (escolhida)

Cada port é projeto isolado em `langs/<lang>/`, publicado no registry
nativo da linguagem (PyPI, crates.io, npm, Packagist, Maven Central,
NuGet, pub.dev, Conan/vcpkg). Sem código compartilhado.

**Prós:**
- Cada port é instalável com o gerenciador de pacote da linguagem, sem
  dependência binária externa.
- Usa o parser XML idiomático de cada linguagem (lxml em Python, DOMDocument
  em PHP, xml2js/fast-xml-parser em Node, quick-xml em Rust, libxml2 ou
  pugixml em C++, System.Xml em .NET, MSXML/Omni XML em Delphi).
- Roda em qualquer ambiente onde a linguagem roda (incluindo hospedagem
  compartilhada, sandboxes WASM, runtimes restritos).
- Bugs/melhorias podem ser feitos por port sem coordenação global —
  contanto que `vectors.json` continue passando.
- Distribuição puramente source/managed (sem binários nativos pré-compilados,
  exceto onde a linguagem é compilada AOT — Rust, Go, C/C++, Delphi).

**Contras:**
- N implementações = N pontos de bug independente. Mitigação: contrato
  `vectors.json` cobre o algoritmo end-to-end byte-a-byte.
- Bugfix tem que ser portado N vezes manualmente. Mitigação: para 30 linhas
  de código a carga é baixa; CI matrix força o port a continuar passando.
- Não há otimização cross-language. Aceitável: 8 vetores rodam em ms,
  perf não é gargalo.

### Opção C — Híbrido: core Rust com C-ABI + WASM + crate nativa

Core em Rust exportado como `cdylib` (C ABI) + `wasm32-unknown-unknown` +
crate nativa Rust. Cada linguagem-alvo escolhe: bindar o C ABI, ou
chamar o WASM, ou reimplementar.

**Prós:**
- Rust resolve memory safety + perf + tooling moderno.
- WASM permite hash client-side no browser (argumento LGPD).
- Uma única "fonte da verdade" implementacional (o crate Rust).

**Contras:**
- Não elimina o problema de distribuição de binários — só troca C por Rust
  como linguagem do core. WASM ajuda no browser mas é estranho em
  desktop/server.
- Adiciona **três modos de consumo** ao projeto (FFI C, WASM, Rust nativo)
  — triplica a superfície de teste e a documentação.
- Linguagens com péssimo suporte a WASM runtime (Delphi, PHP em hospedagem
  compartilhada) ficam de fora — voltamos ao problema da Opção A.
- Equivale a Opção B (port nativo Rust) **somado** a Opção A (binário
  FFI distribuído) **somado** a port WASM. Pior de todos os mundos em
  manutenção.

## Consequências

**Positivas:**

- Cada port pode evoluir, publicar e versionar independente — sem release
  coordenado de N pacotes.
- Onboarding por linguagem é mínimo: ler `reference.py` (~30 linhas) +
  rodar suíte contra `vectors.json`.
- Zero dependência de toolchain externo; usuário PHP instala via
  `composer require`, usuário Python via `pip install`, etc.
- Roda em qualquer alvo da linguagem (incluindo WASM via port JS/TS ou
  via crate Rust → wasm-pack, se/quando desejado).
- O algoritmo é simples o suficiente para que "N implementações" não
  seja custo dominante.

**Negativas / aceitas como custo:**

- Bug encontrado em um port precisa ser conferido/portado nos outros —
  manualmente. O contrato `vectors.json` detecta divergência mas não corrige.
- Não há "uma única implementação canônica" binária — a referência é
  `reference.py` (executável) + `vectors.json` (resultado esperado).
- Diferenças sutis de parser XML por linguagem (entity expansion, BOM,
  normalização de whitespace) podem causar bugs específicos por port —
  mitigado por vetores sintéticos cobrindo CR/LF, vazios, multi-guia,
  acento.

**Riscos / pontos de atenção:**

- **Vetores precisam ser exaustivos.** Hoje são 8 (3 reais + 5 sintéticos).
  Se um caso de borda não coberto causar divergência em produção, o port
  pode passar a CI e ainda assim estar errado. Mitigação contínua: adicionar
  vetor sempre que aparecer um XML real que quebre.
- **Tentação de extrair core compartilhado depois.** Resistir até ter
  evidência (3+ bugs idênticos em ports diferentes em <6 meses) — só então
  reconsiderar Opção C.
- **Port "esquecido"**: se algum port não tiver mantenedor ativo, pode
  ficar para trás. Mitigação: política em `CONTRIBUTING.md` marcando ports
  sem commit em 18 meses como "unmaintained" no README.

## Reversibilidade

**Two-way door com custo médio.** Migrar para core C/Rust + FFI depois é
possível (o `vectors.json` continua sendo a régua), mas exige reescrever
distribuição de cada port (binário + wrapper). Custo estimado: 1 sprint
por linguagem que se queira migrar. Não há lock-in de dado — todos os
ports produzem o mesmo hash hex. A decisão pode ser revisitada quando/se
aparecer pressão concreta (perf insuficiente, bugs cross-port frequentes,
demanda de SIMD).
