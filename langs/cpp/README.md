# tiss-hash (port C++)

Hash MD5 do epilogo `<ans:hash>` em XMLs do **Padrao TISS/ANS**. Implementacao em C++20 com `pugixml` (parser) + `OpenSSL EVP` (MD5).

- Spec canonica: [`docs/SPEC.md`](../../docs/SPEC.md) (raiz do repo).
- Referencia executavel: [`conformance/reference.py`](../../conformance/reference.py).
- 15 ambiguidades canonicas: [`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md).
- Bate **byte-a-byte** com a referencia nos 20 vetores (18 positivos + 2 negativos) em [`conformance/vectors.json`](../../conformance/vectors.json).

## Status

Alpha. **20/20 vetores PASS** (18 positivos + 2 negativos: multi-hash e UTF-16 sao rejeitados). API publica estavel; ABI nao garantido ainda.

## Dependencias de sistema

| Distro | Pacotes |
|---|---|
| Fedora / RHEL | `pugixml-devel openssl-devel cmake gcc-c++ python3` |
| Debian / Ubuntu | `libpugixml-dev libssl-dev cmake g++ python3` |
| Arch | `pugixml openssl cmake gcc python3` |
| macOS (brew) | `pugixml openssl cmake python3` |

Se `pugixml` nao estiver disponivel via `find_package`, o `CMakeLists.txt` cai automaticamente em `FetchContent` baixando `v1.14` do GitHub.

Versoes usadas no desenvolvimento:
- pugixml 1.15
- OpenSSL 3.5.5
- g++ 16.1 (C++20)
- CMake 4.3

## Build & test

```bash
cd langs/cpp
cmake -B build -S .
cmake --build build -j
ctest --test-dir build --output-on-failure
```

Resultado esperado: `20/20 PASS` no test case de conformidade.

### Sanitizers (recomendado em dev)

```bash
cmake -B build_san -S . \
    -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -O1 -g"
cmake --build build_san -j
ctest --test-dir build_san --output-on-failure
```

### Valgrind

```bash
cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j
valgrind --leak-check=full --error-exitcode=1 \
    ./build/test_conformance --inputs ../../conformance/inputs
```

## Uso (C++ API)

```cpp
#include <tiss_hash/tiss_hash.hpp>
#include <iostream>

int main() {
    try {
        const std::string h = tiss_hash::HashTissFile("lote.xml");
        std::cout << h << '\n';  // 32 hex lowercase
    } catch (const tiss_hash::InvalidTissXml& e) {
        std::cerr << "XML invalido: " << e.what() << '\n';
        return 1;
    }
}
```

A partir de bytes em memoria:

```cpp
#include <tiss_hash/tiss_hash.hpp>

std::string_view xml = "<...>";
const std::string h = tiss_hash::HashTiss(xml);
```

### Compilando seu programa contra a lib

Via CMake (apos `cmake --install build`):

```cmake
find_package(tiss_hash_cpp REQUIRED)
target_link_libraries(seu_prog PRIVATE tiss_hash::cpp)
```

Via pkg-config:

```bash
g++ -std=c++20 seu_prog.cpp $(pkg-config --cflags --libs tiss-hash-cpp) -o seu_prog
```

## API publica

```cpp
namespace tiss_hash {

inline constexpr std::string_view kNamespace =
    "http://www.ans.gov.br/padroes/tiss/schemas";
inline constexpr std::string_view kVersion = "0.1.0";
inline constexpr std::size_t kHashHexLen = 32;

class InvalidTissXml : public std::runtime_error { ... };

[[nodiscard]] std::string HashTiss(std::span<const std::byte> xml);
[[nodiscard]] std::string HashTiss(std::string_view xml);
[[nodiscard]] std::string HashTissFile(const std::filesystem::path& path);

}  // namespace tiss_hash
```

## Thread-safety

As funcoes nao mantem estado mutavel global. Podem ser chamadas concorrentemente em threads diferentes. `pugixml` aloca seu proprio `xml_document` por chamada; OpenSSL EVP usa `EVP_MD_CTX` local. RAII garante cleanup automatico.

## Seguranca / hardening

- pugixml por **default NAO** resolve DTD externa nem entidades externas; XXE com URL externa nao e exploravel.
- Entidades XML predefinidas (`&amp;`, `&lt;`, etc.) sao decodificadas, necessario pra conformance #4.
- Limite pratico de 2 GiB no input (rejeita acima com `InvalidTissXml`).
- BOM UTF-8 explicitamente strippado antes do parse (defensivo; pugixml ja aceita).
- Sem `system()`, `popen()`, `eval` ou similares.

## Decisoes de implementacao

| Topico | Escolha | Justificativa |
|---|---|---|
| Parser XML | pugixml | header + 1 cpp, pacote nativo nas distros, comentarios opcionais via parse_comments, cross-parser vs port C (libxml2): valida algoritmo em duas engines diferentes |
| Resolucao de namespace | manual via xmlns:* nos ancestrais | pugixml nao tem namespace-awareness W3C nativo; impl em ~20 LOC |
| MD5 | OpenSSL EVP | API moderna (low-level MD5_* foi deprecada em OpenSSL 3.0); disponivel em qualquer Linux |
| Build primario | CMake (sem Makefile alternativo) | usuarios C++ usam CMake; manter mais simples que port C |
| Testes | doctest | header-only single-file, sintaxe BDD-ish, zero deps de build |
| C++ standard | C++20 | std::span + std::filesystem nativos; sem deps de C++23 ainda raro |

Alternativas avaliadas e descartadas: ver comentarios em `src/tiss_hash.cpp`.

## Layout

```
langs/cpp/
├── CMakeLists.txt
├── README.md
├── LICENSE                              # MIT
├── tiss-hash-cpp.pc.in                  # pkg-config template
├── cmake/
│   └── tiss_hash_cppConfig.cmake.in
├── include/
│   └── tiss_hash/
│       └── tiss_hash.hpp                # API publica
├── src/
│   └── tiss_hash.cpp
├── tests/
│   ├── test_conformance.cpp             # 20 vetores
│   └── test_vectors.hpp                 # GERADO via tools/gen_test_vectors.py
├── third_party/
│   └── doctest.h                        # MIT, v2.4.11
└── tools/
    └── gen_test_vectors.py
```

## Comparacao com port C

Mesmo algoritmo (mesmo manifesto de vetores, mesma referencia Python). Diferencas:

- Port C usa `libxml2` (namespace W3C nativo, mais pesado); port C++ usa `pugixml` (mais leve, namespace manual).
- Port C expoe API estilo C (`tiss_hash_status_t`, `out_hex[33]`); port C++ expoe API idiomatica (`std::string` retornado, exception em erro).
- Port C tem Makefile alternativo; port C++ so CMake.
- Ambos compartilham OpenSSL EVP pra MD5.

Os dois ports rodam o mesmo conjunto de 20 vetores e devem produzir hashes identicos (e rejeitar os mesmos 2 vetores negativos): cross-validation entre duas engines de parser independentes.

## Licenca

MIT, ver [`LICENSE`](LICENSE). doctest distribuido sob MIT (ver [`third_party/doctest.h`](third_party/doctest.h)).
