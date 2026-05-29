# tiss-hash-wasm (WebAssembly)

Calcula a "impressão digital" do trecho final de um documento TISS/ANS,
**dentro do navegador**, sem enviar nada para servidor nenhum. Antes do código,
os termos essenciais:

- **XML**: formato de arquivo de texto que organiza dados em etiquetas (tags)
  aninhadas, como caixas dentro de caixas. O Padrão TISS é o XML que operadoras
  de saúde e consultórios usam no Brasil para trocar dados de atendimento
  (regulamentado pela Agência Nacional de Saúde Suplementar, a ANS).
- **Hash**: sequência curta e fixa de caracteres calculada a partir de um
  texto, como uma impressão digital. Mude uma letra, o hash muda inteiro.
- **MD5**: a receita (algoritmo) que gera o hash; sempre 32 caracteres
  hexadecimais (`0-9` e `a-f`).
- **Epílogo**: a parte final do documento TISS, a etiqueta `<ans:hash>`, onde o
  hash precisa ser gravado.
- **WASM (WebAssembly)**: formato binário que roda código compilado (aqui,
  Rust) dentro do navegador ou do Node, com performance próxima de nativo.

Em uma frase: você passa os bytes de um XML TISS e recebe os 32 caracteres do
hash, com tudo acontecendo na máquina do usuário. Este é o port **WASM** da
biblioteca [`lib_hash_ans`](https://github.com/petrinhu/TISS_ANS_hash). Os
outros ports (Python, Rust, Node, C, C++, PHP, Java, Go, C#) seguem o mesmo
contrato e os mesmos vetores de conformidade.

- **Status:** alpha. 20/20 vetores sintéticos PASS (18 positivos + 2 negativos)
  em `conformance/vectors.json`, mais os 3 goldens reais privados (fora do repo).
- **Licença:** MIT.
- **Runtimes:** navegadores modernos (Chrome, Firefox, Safari, Edge) e Node.js
  `>=20` (testado em Node 22).

## Por que existe: hash client-side e LGPD

O XML TISS carrega dados pessoais de paciente (nome, carteirinha,
procedimentos), ou seja, **PII** sob a LGPD. Os outros ports são ótimos para
backend, scripts e desktop, mas se você quer oferecer o cálculo em uma página
web, a abordagem ingênua (mandar o XML para um servidor hashear) cria um ponto
de vazamento: o arquivo com PII trafega e pode ficar em log, cache ou disco.

O port WASM elimina esse risco **por construção**: o `.wasm` roda dentro da aba
do navegador. O usuário seleciona o arquivo, o hash é calculado localmente e
**nada trafega**: nem o XML, nem o hash, nem metadado. Não há upload, não há
endpoint. É o argumento de privacidade mais forte do projeto, e só o WASM o
entrega. Detalhes da decisão em
[`docs/adr/0006-wasm-port.md`](../../docs/adr/0006-wasm-port.md).

## Como é feito: reuso do core Rust (sem reimplementação)

Este port **não reimplementa** o algoritmo. Ele reusa o port Rust nativo
(`langs/rust/`), que já passa os 20 vetores + 3 goldens e foi mutation-tested,
compilando-o para `wasm32-unknown-unknown` e expondo a função ao JavaScript via
[`wasm-bindgen`](https://github.com/rustwasm/wasm-bindgen). A camada nova é uma
casca fina: recebe os bytes do JS, chama o core, e converte o erro tipado do
Rust em exceção JS. As **mesmas rejeições** do core são preservadas.

Consequência prática: o hash produzido aqui é **byte-a-byte idêntico** ao dos
outros 9 ports. Veja a justificativa completa (e por que isso não contradiz o
ADR-0001) em [`docs/adr/0006-wasm-port.md`](../../docs/adr/0006-wasm-port.md).

## Quickstart

### No navegador (ESM)

O navegador exige servir os arquivos por HTTP (não funciona abrindo o `.html`
direto com `file://`, por causa de como o `.wasm` é carregado):

```bash
cd langs/wasm
python3 -m http.server 8000
# abra http://localhost:8000/examples/browser/
```

No seu próprio código:

```html
<script type="module">
  import init, { hashTiss } from './pkg/web/tiss_hash_wasm.js';

  await init(); // carrega o .wasm uma vez (fetch)

  const file = document.querySelector('input[type=file]').files[0];
  const bytes = new Uint8Array(await file.arrayBuffer());
  try {
    const md5 = hashTiss(bytes); // 32 chars hex minúsculo
    console.log(md5);
  } catch (err) {
    console.error('XML rejeitado:', err.message);
  }
</script>
```

Há um exemplo completo e comentado em
[`examples/browser/index.html`](examples/browser/index.html).

### No Node.js

O binding `target=nodejs` é CommonJS e carrega o `.wasm` de forma síncrona ao
ser importado (não precisa de `init()`):

```js
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
const require = createRequire(import.meta.url);
const { hashTiss } = require('./pkg/node/tiss_hash_wasm.js');

const md5 = hashTiss(new Uint8Array(readFileSync('lote.xml')));
console.log(md5);
```

Exemplo executável: [`examples/node/run.mjs`](examples/node/run.mjs):

```bash
node examples/node/run.mjs caminho/para/lote.xml
```

### Tratamento de erro

`hashTiss` **lança** (throw) um `Error` quando o XML é rejeitado. A mensagem vem
do core Rust (diagnóstico do parser) e **não contém PII**:

```js
try {
  hashTiss(bytes);
} catch (err) {
  // err.message ex.: "XML inválido para hash TISS: ..."
  console.error(err.message);
}
```

## API

O módulo expõe (tanto no `pkg/web` quanto no `pkg/node`):

| Símbolo | Tipo | Descrição |
| --- | --- | --- |
| `hashTiss(bytes)` | `(Uint8Array) => string` | Hash MD5 (hex, 32 chars minúsculo) a partir dos bytes do XML. Lança `Error` se rejeitado. |
| `tissNamespace()` | `() => string` | URI do namespace TISS: `http://www.ans.gov.br/padroes/tiss/schemas`. |
| `default` (só no `pkg/web`) | `(input?) => Promise<...>` | `init`: inicializa o módulo WASM (carrega o `.wasm`). Chamar uma vez antes de `hashTiss` no browser. |

Os tipos TypeScript (`.d.ts`) são gerados automaticamente pelo `wasm-bindgen` e
acompanham os bindings em `pkg/`.

## Algoritmo (resumo)

Igual a todos os ports (a lógica vive no core Rust):

1. Decodifica os bytes respeitando a declaração `encoding="..."` (ISO-8859-1 ou
   UTF-8; strippa BOM UTF-8).
2. Parseia o XML.
3. Localiza o `<ans:hash>` pelo **namespace URI** (não pelo prefixo) e marca-o
   para ser zerado. Sem `<ans:hash>` é válido; múltiplos são **rejeitados**.
4. Concatena o `.text` de cada **nó-folha** (elemento ou comentário sem filhos
   elemento/comentário/PI) em ordem de documento. O `<ans:hash>` contribui `""`.
5. Calcula `MD5` sobre os bytes **UTF-8** da string concatenada.
6. Devolve o hex minúsculo (32 caracteres).

### Atenção: encoding do MD5 é UTF-8, não ISO-8859-1

O manual TISS diz "o encoding a ser utilizado será sempre o ISO-8859-1". Essa
frase é ambígua e foi historicamente mal interpretada: refere-se ao encoding do
arquivo XML, **não** dos bytes que alimentam o MD5. Na prática (validada contra
goldens reais privados, fora do repo), os valores extraídos são re-encodados em
**UTF-8** antes do MD5. Spec completa:
[`docs/SPEC.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md).

## Build (gerar o `pkg/` a partir do fonte)

Pré-requisitos:

- **cargo + rustc** com o target `wasm32-unknown-unknown`:

  ```bash
  rustc --print target-list | grep wasm32-unknown-unknown
  ```

  No Fedora (cargo do sistema, sem rustup) o target já vem instalado.

- **wasm-bindgen-cli** na versão que **casa** com a dependência `wasm-bindgen`
  fixada no `Cargo.toml` (atualmente `0.2.122`). Versões diferentes entre a CLI
  e a lib quebram o glue gerado:

  ```bash
  cargo install wasm-bindgen-cli --version 0.2.122
  # binário em ~/.cargo/bin; garanta que está no PATH
  ```

Então:

```bash
cd langs/wasm
bash build.sh      # compila + roda wasm-bindgen (gera pkg/web e pkg/node)
```

O `build.sh` também roda `wasm-opt -Oz` se o
[binaryen](https://github.com/WebAssembly/binaryen) estiver instalado
(opcional; reduz mais o tamanho do `.wasm`).

> Por que não `wasm-pack`? Com o Rust do sistema (sem rustup), o `wasm-pack`
> reclama por não conseguir gerenciar a toolchain. O caminho
> `cargo build --target wasm32-unknown-unknown` + `wasm-bindgen-cli` é o mais
> robusto nesse ambiente e é o que `build.sh` usa.

## Conformidade

Esta lib passa os **20 vetores sintéticos** (18 positivos + 2 negativos) em
[`conformance/vectors.json`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/vectors.json),
mais os **3 goldens reais privados** (não versionados, LGPD).

Rodar os testes (precisa do `pkg/` já gerado pelo `build.sh`):

```bash
cd langs/wasm
npm test            # ou: node test/conformance.mjs
```

O harness ([`test/conformance.mjs`](test/conformance.mjs)) carrega o WASM,
roda os vetores e, se os goldens privados estiverem disponíveis (via env
`TISS_PRIVATE_XMLS` ou no path default ao lado do repo), valida-os imprimindo
**apenas PASS/FAIL**, nunca o hash nem o conteúdo do XML (privacidade).

Saída esperada: 24 PASS (1 sanidade de API + 20 vetores + 3 goldens), 0 FAIL.

## Limitações conhecidas

- **Múltiplos `<ans:hash>`:** rejeitado (lança `Error`). Cenário patológico não
  previsto pelo padrão; falhar é mais seguro que adivinhar qual zerar.
- **Encodings suportados:** ISO-8859-1 e UTF-8. UTF-16/UTF-32 são rejeitados
  (fora de escopo).
- **Tamanho do `.wasm`:** o parser embutido (`roxmltree`) e o `md-5` geram um
  binário de ~80 KB (pode cair mais com `wasm-opt`). Para hashear um XML na aba
  do browser é irrelevante.

## Dependências e licenças

Toda a lógica vem do core Rust (`langs/rust/`), cujas deps são `roxmltree` (MIT)
e `md-5` (MIT/Apache-2.0). A camada WASM adiciona `wasm-bindgen` (MIT/Apache-2.0).
Atribuição consolidada em
[`THIRD_PARTY_LICENSES.md`](../../THIRD_PARTY_LICENSES.md) na raiz do repo.

## Licença

[MIT](LICENSE) Copyright (c) 2026 Petrus Silva Costa

## Ver também

- [`docs/adr/0006-wasm-port.md`](../../docs/adr/0006-wasm-port.md): decisão de
  reusar o core Rust via wasm-bindgen.
- [`langs/rust/`](../rust/): o core nativo reusado por este port.
- [`docs/SPEC.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md):
  especificação canônica do algoritmo.
- [`conformance/reference.py`](../../conformance/reference.py): implementação de
  referência (o "oráculo" que define a resposta certa).
