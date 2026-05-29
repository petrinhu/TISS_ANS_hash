# tiss-hash (port C)

Calcula a "impressao digital" do trecho final de um documento TISS/ANS. Os
termos antes do codigo:

- **XML**: formato de arquivo de texto que organiza dados em etiquetas (tags)
  aninhadas, como caixas dentro de caixas. O Padrao TISS e o XML que operadoras
  de saude e consultorios usam no Brasil para trocar dados de atendimento.
- **Hash**: sequencia curta e fixa de caracteres calculada a partir de um
  texto, como uma impressao digital. Mude uma letra, o hash muda inteiro.
- **MD5**: a receita (algoritmo) que gera o hash; sempre 32 caracteres
  hexadecimais (`0-9` e `a-f`).
- **Epilogo**: a parte final do documento TISS, a etiqueta `<ans:hash>`, onde o
  hash precisa ser gravado.
- **Parser**: o componente que le o texto do XML e monta a arvore de etiquetas
  na memoria. Aqui o parser e a `libxml2`.

Em uma frase: voce passa os bytes de um XML TISS e recebe os 32 caracteres do
hash. (Um **byte** e a menor unidade de dado do computador.) Este e o port C
("port" = a mesma lib reescrita em outra linguagem), em C11 puro com `libxml2`
(parser) + `OpenSSL EVP` (calculo do MD5).

Para entender o problema que a lib resolve, veja
[`docs/USAGE.md`](../../docs/USAGE.md) (guia de uso) e
[`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) (conceitos e visao geral).

- Spec canonica: [`docs/SPEC.md`](../../docs/SPEC.md) (raiz do repo).
- Referencia executavel: [`conformance/reference.py`](../../conformance/reference.py).
- 15 ambiguidades canonicas: [`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md).
- Bate **byte-a-byte** com a referencia nos 20 vetores (18 positivos + 2 negativos) em [`conformance/vectors.json`](../../conformance/vectors.json).

## Status

Alpha. **20/20 vetores PASS** (18 positivos + 2 negativos: multi-hash e UTF-16 sao rejeitados). Sem vazamentos detectados em valgrind (`make valgrind`).

## Antes de comecar: instalar a toolchain C

Para compilar codigo C voce precisa de uma **toolchain**: o compilador mais as
ferramentas de build. Este port usa `gcc` (ou `clang`), `cmake` e duas
bibliotecas de sistema (`libxml2` e `OpenSSL`).

- Em Linux a forma mais simples e instalar pelo gerenciador de pacotes da sua
  distro (veja a tabela "Dependencias de sistema" logo abaixo).
- Documentacao oficial do compilador GCC: <https://gcc.gnu.org/install/>
- Documentacao oficial do CMake (ferramenta de build): <https://cmake.org/download/>

Confira que o compilador e o CMake estao instalados:

```bash
gcc --version
cmake --version
```

Exemplo de instalacao completa no Fedora (uma unica linha):

```bash
sudo dnf install libxml2-devel openssl-devel cmake gcc python3
```

No Debian/Ubuntu:

```bash
sudo apt install libxml2-dev libssl-dev cmake gcc python3
```

(Um pacote terminado em `-devel` ou `-dev` traz os "cabecalhos" da biblioteca,
arquivos `.h` que o compilador precisa para usar aquela biblioteca.)

## Dependencias de sistema

| Distro | Pacotes |
|---|---|
| Fedora / RHEL | `libxml2-devel openssl-devel cmake gcc python3` |
| Debian / Ubuntu | `libxml2-dev libssl-dev cmake gcc python3` |
| Alpine | `libxml2-dev openssl-dev cmake build-base python3` |
| macOS (brew) | `libxml2 openssl cmake python3` (talvez precise `PKG_CONFIG_PATH`) |

Versoes testadas no desenvolvimento:
- libxml2 2.12.10
- OpenSSL 3.5.5
- gcc / clang com C11
- CMake 3.16+

## Build & test (CMake, recomendado)

A partir da raiz do repositorio (a pasta que voce baixou com `git clone`):

```bash
cd langs/c
cmake -B build -S .            # configura o build na pasta build/
cmake --build build -j         # compila a biblioteca e os testes
ctest --test-dir build --output-on-failure   # roda os 20 vetores
```

Resultado esperado: `20/20 PASS`. Cada vetor e um par "arquivo de entrada ->
hash esperado": 18 positivos (devem produzir um hash) e 2 negativos (devem ser
rejeitados).

## Build & test (Makefile alternativo)

Pra builds rapidos sem CMake (assume `pkg-config` funcional):

```bash
cd langs/c
make            # libtiss_hash.so + .a + test_conformance
make test       # 20/20 PASS
make valgrind   # leak-check completo (precisa valgrind instalado)
```

## Uso (C API)

```c
#include "tiss_hash.h"
#include <stdio.h>

int main(void) {
    char out[TISS_HASH_HEX_LEN];
    tiss_hash_status_t rc = tiss_hash_file("lote.xml", out);
    if (rc != TISS_HASH_OK) {
        fprintf(stderr, "erro: %s\n", tiss_hash_strerror(rc));
        return 1;
    }
    printf("%s\n", out);   /* 32 hex lowercase + NUL */
    return 0;
}
```

A partir de bytes em memoria:

```c
const unsigned char *xml = ...;
size_t len = ...;
char out[TISS_HASH_HEX_LEN];
if (tiss_hash_bytes(xml, len, out) == TISS_HASH_OK) {
    /* out tem o hash. */
}
```

### Compilando seu programa contra a lib

Via pkg-config (depois de `make install` ou `cmake --install`):

```bash
gcc seu_prog.c $(pkg-config --cflags --libs tiss-hash) -o seu_prog
```

Via CMake:

```cmake
find_package(tiss_hash REQUIRED)
target_link_libraries(seu_prog PRIVATE tiss_hash::tiss_hash)
```

## API

```c
#define TISS_HASH_NAMESPACE "http://www.ans.gov.br/padroes/tiss/schemas"
#define TISS_HASH_HEX_LEN 33    /* 32 hex + NUL */

typedef enum {
    TISS_HASH_OK              = 0,
    TISS_HASH_ERR_INVALID_XML = 1,
    TISS_HASH_ERR_IO          = 2,
    TISS_HASH_ERR_ALLOC       = 3,
    TISS_HASH_ERR_ARG         = 4
} tiss_hash_status_t;

tiss_hash_status_t tiss_hash_bytes(const unsigned char *xml, size_t len,
                                   char out_hex[TISS_HASH_HEX_LEN]);
tiss_hash_status_t tiss_hash_file (const char *path,
                                   char out_hex[TISS_HASH_HEX_LEN]);
const char *tiss_hash_strerror(tiss_hash_status_t s);
const char *tiss_hash_version(void);
```

## Thread-safety

As funcoes podem ser chamadas concorrentemente em threads diferentes. A inicializacao global do `libxml2` e feita uma unica vez via `pthread_once` na primeira chamada: o caller nao precisa fazer nada.

## Seguranca / hardening

- Parse com `XML_PARSE_NONET | XML_PARSE_NOENT`:
  - `NONET` proibe rede em resolucao de DTD/entidade (mitiga XXE com URL).
  - `NOENT` substitui entidades XML predefinidas (`&amp;` etc.), necessario pra conformance #4. Entidades externas continuam bloqueadas porque `NONET` impede o fetch.
- `xmlReadMemory` aceita ate `INT_MAX` bytes; a API rejeita acima disso com `TISS_HASH_ERR_ARG`.
- Sem `system()`, `popen()`, `eval` ou similares.
- BOM UTF-8 e processado pelo libxml2; nao removemos manualmente (ele aceita).

## Decisoes de implementacao (resumo)

| Topico | Escolha | Justificativa |
|---|---|---|
| Parser XML | libxml2 | de-facto em Linux, mesma engine que lxml (Python) e DOMDocument (PHP), suporta comentarios + namespaces W3C nativamente |
| MD5 | OpenSSL EVP API | API moderna; a low-level `MD5_*` foi deprecada em OpenSSL 3.0 |
| Buffer de concat | proprio (realloc dobrando) | controle direto de OOM, sem dep transitiva |
| Init libxml2 | `pthread_once` | thread-safe por construcao |
| Build primario | CMake | export targets + pkg-config + find_package |
| Build alternativo | Makefile com pkg-config | uso direto sem CMake |

Alternativas avaliadas e descartadas: ver comentarios em `src/tiss_hash.c`.

## Layout

```
langs/c/
├── CMakeLists.txt
├── Makefile                       # alternativo simples
├── README.md
├── LICENSE                        # MIT
├── tiss-hash.pc.in                # template pkg-config
├── cmake/
│   └── tiss_hashConfig.cmake.in   # template find_package
├── include/
│   └── tiss_hash.h                # API publica
├── src/
│   └── tiss_hash.c                # impl
├── tests/
│   ├── test_conformance.c         # runner
│   └── test_vectors.h             # GERADO via tools/gen_test_vectors.py
└── tools/
    └── gen_test_vectors.py        # le vectors.json, emite header
```

## Dependencias e licencas

Dependencias de runtime (linkadas; nao vendoradas):

| Dependencia | Licenca | Uso |
|---|---|---|
| libxml2 | MIT | parser XML |
| OpenSSL / libcrypto | Apache-2.0 | MD5 (EVP) |

A Apache-2.0 (OpenSSL) exige atribuicao ao redistribuir; mantenha o aviso de
licenca correspondente. Atribuicao consolidada de todos os ports em
[`THIRD_PARTY_LICENSES.md`](../../THIRD_PARTY_LICENSES.md) na raiz do repo.

## Licenca

MIT, ver [`LICENSE`](LICENSE).

## Ver também

- [`docs/USAGE.md`](../../docs/USAGE.md): guia de uso, receitas e perguntas
  frequentes (comece por aqui se voce quer so usar a lib).
- [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md): conceitos e visao geral.
- [`docs/SPEC.md`](../../docs/SPEC.md): especificacao canonica do algoritmo.
- [`docs/PORTING_GUIDE.md`](../../docs/PORTING_GUIDE.md): guia para portar para
  outras linguagens.
- [`conformance/reference.py`](../../conformance/reference.py): implementacao de
  referencia (o "oraculo" que define a resposta certa).
