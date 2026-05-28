# tiss-hash (port C)

Hash MD5 do epilogo `<ans:hash>` em XMLs do **Padrao TISS/ANS** (Padrao TISS 4.01.00). Implementacao em C11 puro com `libxml2` (parser) + `OpenSSL EVP` (MD5).

- Spec canonica: [`docs/SPEC.md`](../../docs/SPEC.md) (raiz do repo).
- Referencia executavel: [`conformance/reference.py`](../../conformance/reference.py).
- 15 ambiguidades canonicas: [`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md).
- Bate **byte-a-byte** com a referencia nos 15 vetores em [`conformance/vectors.json`](../../conformance/vectors.json).

## Status

Alpha. **15/15 vetores PASS**. Sem vazamentos detectados em valgrind (`make valgrind`).

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

```bash
cd langs/c
cmake -B build -S .
cmake --build build -j
ctest --test-dir build --output-on-failure
```

Resultado esperado: `15/15 PASS`.

## Build & test (Makefile alternativo)

Pra builds rapidos sem CMake (assume `pkg-config` funcional):

```bash
cd langs/c
make            # libtiss_hash.so + .a + test_conformance
make test       # 15/15 PASS
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

## Licenca

MIT, ver [`LICENSE`](LICENSE).
