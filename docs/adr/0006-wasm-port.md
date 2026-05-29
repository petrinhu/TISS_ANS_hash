# ADR-0006: Port WASM reusa o core Rust via wasm-bindgen

**Status:** Accepted
**Data:** 2026-05-29
**Decisores:** Petrus (autor/dono do projeto)
**Relacionado:** ADR-0001 (port nativo por linguagem), ADR-0002 (layout monorepo)

## Contexto

O projeto já tem 9 ports nativos (Python, Rust, Node, PHP, C, C++, Java, Go,
C#), todos passando os 20 vetores sintéticos + 3 goldens reais privados. Falta
um alvo que o ADR-0001 listou explicitamente entre os destinos: **WASM**, com
um motivo de existir próprio que nenhum outro port atende.

**Motivo de existir (LGPD):** rodar o cálculo do hash **client-side no
browser**. O XML TISS carrega PII de paciente (nome, carteirinha,
procedimentos). No fluxo WASM, o usuário arrasta/seleciona o arquivo, o hash é
calculado dentro da aba do navegador (ou num worker), e **nada trafega**: nem o
XML, nem o hash, nem metadado. Não há upload, não há servidor. Isso elimina por
construção a superfície de vazamento de uma SaaS que receberia o XML para
hashear. É o argumento de privacidade mais forte que o projeto pode oferecer e
só o WASM o entrega.

A pergunta de design é **como** produzir o módulo WASM:

- Reimplementar o algoritmo em uma linguagem que compila pra WASM (Rust
  dedicado, AssemblyScript, C via Emscripten), ou
- **Reusar o core Rust nativo já existente** (`langs/rust/`), compilando-o para
  `wasm32-unknown-unknown` e expondo a API ao JS via `wasm-bindgen`.

## Decisão

O port WASM **reusa o crate Rust nativo `tiss-hash` (`langs/rust/`)** como
dependência por caminho (`path = "../rust"`) e expõe a função ao JavaScript via
`wasm-bindgen`. O crate WASM (`langs/wasm/`) é uma casca fina: declara
`crate-type = ["cdylib"]`, depende de `wasm-bindgen` + do core, e contém apenas
o adaptador `#[wasm_bindgen]` que recebe os bytes do JS, chama
`tiss_hash::hash_tiss`, e converte o `Result<String, TissHashError>` em
`Result<String, JsValue>`.

As **mesmas rejeições** do core são preservadas e propagadas ao JS como
exceção: múltiplos `<ans:hash>`, BOM UTF-16/UTF-32 fora de escopo, XML
mal-formado. O encoding dos bytes do MD5 continua **UTF-8** (a regra canônica do
projeto), porque a lógica não é reimplementada: é literalmente o mesmo código.

### Por que isto NÃO contradiz o ADR-0001

O ADR-0001 escolheu "port nativo por linguagem" (Opção B) e **descartou a Opção
C** (a saber, "core Rust com C-ABI + WASM + crate nativa") oferecido como modo de consumo
para *todas* as linguagens. Os contras da Opção C eram: triplicar a superfície
(FFI C + WASM + Rust) de **todo** port, forçar linguagens com runtime WASM ruim
(Delphi, PHP em hospedagem compartilhada) a depender de um artefato estranho ao
seu ecossistema.

Nada disso se aplica aqui:

- O WASM **é, ele próprio, um port nativo** no sentido do ADR-0001: um alvo de
  primeira classe (`langs/wasm/`), publicável no registry idiomático (npm, como
  pacote `*.wasm` + bindings), instalável sem toolchain externa pelo consumidor
  final (que recebe `.wasm` + `.js` prontos).
- Os outros 9 ports **continuam independentes e nativos**. Nenhum passa a
  depender de WASM ou de FFI. O port PHP segue puro PHP; o C segue puro C.
- "Reusar o core Rust" aqui significa apenas que **o port WASM e o port Rust
  compartilham uma fonte de verdade implementacional**: ambos são Rust, é
  natural que o WASM seja o crate Rust + uma camada de binding, em vez de uma
  10ª reimplementação divergente do mesmo algoritmo na mesma linguagem.

Ou seja: a régua continua sendo `vectors.json`; o port WASM tem seu próprio
harness de conformidade (Node) que o valida contra os 20 vetores + 3 goldens,
exatamente como os demais.

## Alternativas consideradas

### Opção A: Reimplementar em Rust dedicado dentro de `langs/wasm/` (descartada)

Um crate Rust independente em `langs/wasm/` com a lógica do algoritmo copiada,
sem depender de `langs/rust/`.

**Prós:** crate WASM totalmente autocontido, sem acoplamento com o port Rust.

**Contras:** seriam **duas implementações Rust idênticas** do mesmo algoritmo no
mesmo repo. Divergência inevitável quando um bug for corrigido só em um lado. O
ADR-0001 aceita "N implementações = N pontos de bug" entre *linguagens
diferentes*, mas pagar esse custo **duas vezes na mesma linguagem** é puro
desperdício: o core Rust já passa 20 vetores + 3 goldens, copiá-lo só cria
risco. Descartada.

### Opção B: AssemblyScript (descartada)

Reimplementar em AssemblyScript (subset de TypeScript que compila pra WASM).

**Prós:** ecossistema JS, sem toolchain Rust.

**Contras:** AssemblyScript **não tem parser XML maduro**: seria preciso portar
ou escrever um parser, justamente a parte mais delicada do algoritmo (semântica
de nó-folha, comentários, namespaces, CDATA, entidades). Reintroduz toda a
superfície de bug que o core Rust já fechou. É uma 10ª reimplementação, pior:
numa linguagem imatura para o caso. Descartada.

### Opção C: C via Emscripten (descartada)

Compilar o port C (`langs/c/`) para WASM via Emscripten.

**Prós:** reusa um core existente (o port C).

**Contras:** Emscripten é toolchain pesada e separada; o port C depende de
parser XML em C (libxml2/expat) cuja compilação pra WASM é trabalhosa; a API de
borda (passar bytes JS ↔ heap C) é manual e propensa a erro de memória. O
`wasm-bindgen` resolve a borda JS↔WASM de forma segura e ergonômica, e o core
Rust já tem memory safety. Descartada.

### Opção D: Reusar o core Rust via wasm-bindgen (escolhida)

Já descrita em "Decisão".

**Prós:**

- Uma fonte de verdade Rust para os dois alvos nativos Rust (nativo + WASM).
- `wasm-bindgen` gera os bindings JS, tipos TS (`.d.ts`) e o glue de
  marshalling de `Uint8Array`/`string` automaticamente.
- O core já validado (20 vetores + 3 goldens, mutation-tested) é reusado sem
  uma linha de lógica nova, só adaptação de tipo de erro.
- Roda em browser (ESM com `WebAssembly.instantiate`) e em Node 22 (com
  `--experimental-wasm-modules` desnecessário; bindings ESM padrão).

**Contras:**

- Exige `wasm-bindgen-cli` no ambiente de build (instalável em user-space via
  `cargo install`, sem rustup). Mitigação: documentado no README; o artefato
  gerado (`pkg/`) é distribuível sem a toolchain.
- Acopla o port WASM ao port Rust por `path`. Aceitável: ambos são Rust no
  mesmo monorepo; o acoplamento é intencional (é o ponto da decisão).

## Consequências

**Positivas:**

- O hash TISS roda 100% client-side no browser: argumento LGPD máximo (PII
  nunca sai da máquina).
- Zero reimplementação: o WASM herda automaticamente toda correção/garantia do
  core Rust.
- Bindings TS gerados dão DX de primeira no ecossistema JS/edge.

**Negativas / aceitas como custo:**

- Build do port WASM depende de `wasm-bindgen-cli` (não é `cargo build` puro).
  Documentado.
- Versão da `wasm-bindgen` (lib) **deve casar** com a versão da
  `wasm-bindgen-cli` instalada, senão o glue quebra. Fixado no `Cargo.toml` e
  anotado no README.

**Riscos / pontos de atenção:**

- Drift de versão entre `wasm-bindgen` lib e CLI. Mitigação: pin explícito +
  nota no README sobre `cargo install wasm-bindgen-cli --version <X>`.
- Tamanho do `.wasm`: o parser `roxmltree` + `md-5` geram um binário não
  trivial. Mitigação: `opt-level="z"`/`lto` no profile release do crate WASM;
  `wasm-opt` opcional documentado. Para o caso de uso (hashear um XML na aba do
  browser) o tamanho é aceitável.

## Reversibilidade

**Two-way door.** Se o acoplamento por `path` com o port Rust incomodar, dá pra
migrar para Opção A (crate WASM autocontido) copiando o módulo: a régua
`vectors.json` continua valendo. Custo: baixo (copiar ~300 linhas). Não há
lock-in: o `.wasm` produz exatamente o mesmo hash dos outros 9 ports.
