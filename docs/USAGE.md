---
title: Guia de uso do lib_hash_ans
type: how-to
audience: iniciante a intermediário (estudante de computação, dev backend, fornecedor TISS, ERP hospitalar)
version: 0.2.1
last-reviewed: 2026-05-29
owner: petrinhu@yahoo.com.br
status: estável (13 ports prontos: Python, Rust, C, C++, Node.js, PHP, Java, Go, C#, Kotlin, Delphi/Object Pascal, Dart, WASM)
---

# Guia de uso

Este documento mostra **como usar** as bibliotecas `lib_hash_ans` no dia a dia: como instalar a linguagem, como obter a lib, um exemplo mínimo que funciona, a saída esperada e como tratar erro. Tem uma seção dedicada para cada uma das 13 linguagens, sempre na mesma ordem.

> **Não sabe o que é isto? Comece aqui.** Se as palavras "hash", "XML", "TISS" ou "epílogo" ainda não fazem sentido, leia primeiro o [`CONCEITOS.md`](CONCEITOS.md) (explicação sem código, em linguagem de iniciante). Para botar a mão na massa e ver um hash aparecer na tela passo a passo, siga o [`TUTORIAL.md`](TUTORIAL.md). Este guia aqui assume que você já sabe o que quer fazer e só precisa do "como".

## Antes de tudo: o vocabulário mínimo

Esta seção define os termos técnicos uma única vez. Se você já é da área, pule para a [seção 1](#1-visão-geral-por-linguagem).

- **Byte:** a menor unidade de informação que um computador guarda. Um número de 0 a 255. Um arquivo de texto nada mais é do que uma sequência de bytes.
- **XML:** um formato de arquivo de texto que organiza dados em "etiquetas" aninhadas, parecido com HTML de página web. Exemplo: `<nome>Maria</nome>`. A etiqueta `<nome>` abre, o valor `Maria` fica dentro, e `</nome>` fecha.
- **TISS:** o "Padrão TISS" (Troca de Informações na Saúde Suplementar) é o conjunto de regras, definido pela ANS (a agência reguladora dos planos de saúde no Brasil), que diz como hospitais e clínicas devem mandar contas e guias para os planos. Esses dados viajam em arquivos XML.
- **Epílogo:** a parte final de um arquivo XML TISS. Ela contém um campo chamado `<ans:hash>`, que serve de "selo de integridade" do arquivo.
- **Hash:** uma espécie de "impressão digital" de um arquivo. É um número (mostrado como texto) calculado a partir de todo o conteúdo. Se um único caractere mudar, o hash muda completamente. Serve para detectar adulteração ou corrupção.
- **MD5:** uma das fórmulas (algoritmos) que produzem hash. Sempre devolve 32 caracteres hexadecimais (os dígitos de 0 a 9 mais as letras de `a` a `f`), por exemplo `3aa0c578c95cdb861a125f480a8a4de5`. O padrão TISS exige MD5.
- **Encoding:** a regra que diz como transformar texto (letras, acentos) em bytes. "UTF-8" e "ISO-8859-1" são dois encodings diferentes. A mesma letra "ç" vira bytes diferentes em cada um. Por isso o encoding importa para o hash.
- **Parser:** o programa (dentro da lib) que lê o XML e o transforma em uma estrutura que o computador entende. "Parsear" = ler e interpretar.
- **Namespace:** um prefixo que evita confusão entre etiquetas de XML de origens diferentes. No TISS, as etiquetas usam o prefixo `ans:` (como em `<ans:hash>`). O namespace é a URL completa por trás desse prefixo.
- **Conformidade (ou conformance):** provar que a lib segue a regra exata. Os "vetores de conformidade" são casos de teste prontos que confirmam isso.
- **CLI:** "Command-Line Interface", a tela preta onde você digita comandos (o terminal). Quando este guia mostra uma linha começando com `$` ou um comando como `pip install`, é para digitar no terminal.
- **Dependência:** outra biblioteca que a lib precisa para funcionar. Ao instalar a lib, as dependências dela também são instaladas.
- **Toolchain:** o conjunto de programas necessários para compilar e rodar código de uma linguagem (por exemplo, o interpretador Python, ou o compilador C). "Instalar a toolchain" = instalar a linguagem na sua máquina.

## 1. Visão geral por linguagem

Cada uma das 13 linguagens tem uma seção própria, sempre com os mesmos 5 passos, nesta ordem:

1. **Instalar a toolchain** (a linguagem em si), com link oficial e comando para conferir a versão.
2. **Obter a lib**. Os ports **Python** (PyPI), **Node.js** (npm), **Rust** (crates.io), **PHP** (Packagist) e **Go** (proxy do Go) já estão publicados: instalam direto da internet (`pip install tiss-hash`, `npm install tiss-hash`, `cargo add tiss-hash`, `composer require petrinhu/tiss-hash`, `go get ...`). Para os demais, o registry de cada linguagem ainda está em preparação, então a obtenção é a partir do **checkout** do repositório (a cópia local que você baixa com `git clone`); o placeholder "quando publicado" mostra como vai ser o comando assim que o pacote for ao ar.
3. **Snippet mínimo** (pedaço de código) que você pode copiar e colar.
4. **Saída esperada** (um hash sintético, só para ilustrar).
5. **Como tratar erro** (o tipo de erro que a lib usa naquela linguagem).

| Linguagem              | Pacote / módulo            | Diretório do port | Seção                       |
|------------------------|----------------------------|-------------------|-----------------------------|
| Python                 | `tiss-hash`                | `langs/python/`   | [2](#2-python)              |
| Rust                   | crate `tiss-hash`          | `langs/rust/`     | [3](#3-rust)                |
| C                      | `tiss_hash` (lib + header) | `langs/c/`        | [4](#4-c)                   |
| C++                    | `tiss_hash` (header-only)  | `langs/cpp/`      | [5](#5-c-1)                 |
| Node.js                | `tiss-hash`                | `langs/node/`     | [6](#6-nodejs)              |
| PHP                    | `petrinhu/tiss-hash`       | `langs/php/`      | [7](#7-php)                 |
| Java                   | `tiss-hash` (jar)          | `langs/java/`     | [8](#8-java)                |
| Go                     | módulo `tisshash`          | `langs/go/`       | [9](#9-go)                  |
| C#                     | `TissHash` (.NET)          | `langs/csharp/`   | [10](#10-c-net)             |
| Kotlin                 | `tiss-hash-kotlin` (jar)   | `langs/kotlin/`   | [11](#11-kotlin)            |
| Delphi / Object Pascal | unit `TissHash` (FPC)      | `langs/delphi/`   | [12](#12-delphi--object-pascal-free-pascal) |
| Dart                   | pacote `tiss_hash`         | `langs/dart/`     | [13](#13-dart)              |
| WASM                   | `tiss-hash-wasm` (pkg)     | `langs/wasm/`     | [14](#14-wasm-webassembly)  |

> **Importante (vale para as 13 linguagens):** todas produzem **o mesmo hash, byte a byte**, para o mesmo XML de entrada. São validadas contra os mesmos 20 vetores de conformidade (18 positivos, que devem dar certo, e 2 negativos, que devem dar erro de propósito). Não existe diferença de resultado entre as linguagens. Cada port é autossuficiente e tem o seu próprio README com a referência de API completa.

> **Sobre instalar pela internet:** o port **Python** já está no PyPI (`pip install tiss-hash`), o port **Node.js** está no npm (`npm install tiss-hash`), o port **Rust** está no crates.io (`cargo add tiss-hash`), o port **PHP** está no Packagist (`composer require petrinhu/tiss-hash`), e o port **Go** é resolvido pelo `go get` na tag de versão (proxy do Go / pkg.go.dev). Os demais registries seguem **em preparação** (Maven Central para Java/Kotlin, NuGet para C#, pub.dev para Dart, e npm para o WASM); até subirem, instale a partir do **checkout** (a cópia local do repositório que você baixa com `git clone`). Cada seção mostra como, e também o comando que **vai** funcionar quando o pacote for publicado, marcado com "quando publicado".

**Para todas as linguagens cujo registry ainda está em preparação, o primeiro passo é baixar o repositório:**

```bash
git clone https://github.com/petrinhu/TISS_ANS_hash.git
cd TISS_ANS_hash
```

Isso cria uma pasta `TISS_ANS_hash` com todos os ports dentro de `langs/`.

## 2. Python

### a. Instalar a toolchain

Python 3.10 ou mais novo. Site oficial: <https://www.python.org/downloads/>. No Linux ele costuma já vir instalado; no macOS e Windows, baixe do site.

Conferir a versão (deve mostrar 3.10 ou maior):

```bash
python3 --version
```

### b. Obter a lib

O port Python está publicado no PyPI ([pypi.org/project/tiss-hash](https://pypi.org/project/tiss-hash/)). Via primária, instale direto da internet:

```bash
pip install tiss-hash
```

(`pip` é o instalador de pacotes do Python; ele baixa o pacote do PyPI, o repositório oficial de pacotes Python.)

A única dependência é `defusedxml`, uma biblioteca que protege contra ataques via XML malicioso. O `pip install` cuida dela sozinho.

> **Alternativa: instalar do fonte (a partir do checkout).** Se você clonou o repositório e quer usar o código local (por exemplo, para mexer na lib), instale em "modo editável" a partir da raiz do checkout:
>
> ```bash
> cd langs/python
> pip install -e .
> ```
>
> O `-e .` instala a pasta atual em modo editável (aponta para os arquivos locais em vez de copiá-los).

### c. Snippet mínimo

Salve como `exemplo.py` (a partir da raiz do repositório, para o caminho do arquivo de exemplo bater):

```python
from tiss_hash import hash_tiss

# Lê o XML como bytes (modo "rb" = read binary, ler em binário).
# Use sempre bytes, nunca texto decodificado: a lib precisa controlar o encoding.
with open("conformance/inputs/syn_minimal.xml", "rb") as arquivo:
    xml_bytes = arquivo.read()

digest = hash_tiss(xml_bytes)
print(digest)   # 32 caracteres hexadecimais minúsculos
```

Rode com:

```bash
python3 exemplo.py
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
```

Esse valor é o hash **ilustrativo** do vetor sintético `syn_minimal.xml` (um XML inventado, sem dados de paciente). Para XMLs de verdade o hash será outro.

### e. Como tratar erro

XML malformado dispara a exceção `InvalidTissXml` (uma subclasse de `ValueError`):

```python
from tiss_hash import InvalidTissXml, hash_tiss

try:
    hash_tiss(b"<isto-nao-fecha>")
except InvalidTissXml as exc:
    print(f"XML rejeitado: {exc}")

# Passar texto (str) em vez de bytes dispara TypeError, não InvalidTissXml:
try:
    hash_tiss("isto eh str, nao bytes")   # type: ignore
except TypeError as exc:
    print(f"tipo errado: {exc}")
```

README completo do port: [`../langs/python/README.md`](../langs/python/README.md).

## 3. Rust

### a. Instalar a toolchain

Rust, via instalador oficial `rustup`: <https://www.rust-lang.org/tools/install>. Ele instala o compilador e o `cargo` (a ferramenta que compila e baixa dependências). Versão mínima: rustc 1.75.

Conferir a versão:

```bash
rustc --version
cargo --version
```

### b. Obter a lib

O port Rust está publicado no crates.io ([crates.io/crates/tiss-hash](https://crates.io/crates/tiss-hash); docs em [docs.rs/tiss-hash](https://docs.rs/tiss-hash)). Via primária, dentro do seu projeto Rust (uma pasta com `Cargo.toml`), adicione a crate como dependência:

```bash
cargo add tiss-hash
```

(`cargo` é a ferramenta de build e de pacotes do Rust; `cargo add` baixa a crate do crates.io e a grava em `[dependencies]` do seu `Cargo.toml`.) Em alternativa, escreva à mão no `Cargo.toml`:

```toml
[dependencies]
tiss-hash = "0.1"
```

> **Alternativa: compilar do fonte (a partir do checkout).** Se você clonou o repositório e quer usar o código local (por exemplo, para mexer na lib), compile o port direto da pasta:
>
> ```bash
> cd langs/rust
> cargo build
> ```

### c. Snippet mínimo

Substitua o conteúdo de `langs/rust/src/main.rs` (ou crie um projeto novo que dependa da crate) por:

```rust
use tiss_hash::{hash_tiss, hash_tiss_file, TissHashError};

fn main() -> Result<(), TissHashError> {
    // A partir de bytes
    let raw = std::fs::read("../../conformance/inputs/syn_minimal.xml")?;
    println!("{}", hash_tiss(&raw)?);   // 32 caracteres hex minúsculos

    // Atalho que lê o arquivo direto
    println!("{}", hash_tiss_file("../../conformance/inputs/syn_minimal.xml")?);
    Ok(())
}
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`. As duas linhas são iguais porque os dois caminhos calculam o mesmo arquivo.)

### e. Como tratar erro

O erro é o enum `TissHashError`, com duas variantes: `InvalidXml(String)` (XML inválido) e `Io(std::io::Error)` (falha ao ler o arquivo):

```rust
use tiss_hash::{hash_tiss, TissHashError};

match hash_tiss(b"<isto-nao-fecha>") {
    Ok(h) => println!("{h}"),
    Err(TissHashError::InvalidXml(msg)) => eprintln!("XML inválido: {msg}"),
    Err(TissHashError::Io(e)) => eprintln!("erro de leitura: {e}"),
}
```

README completo do port: [`../langs/rust/README.md`](../langs/rust/README.md).

## 4. C

### a. Instalar a toolchain

O port C precisa de um compilador C (gcc ou clang), do CMake (ferramenta de build) e de duas bibliotecas de sistema: `libxml2` (parser) e OpenSSL (para o MD5). Páginas oficiais: gcc <https://gcc.gnu.org/>, CMake <https://cmake.org/download/>.

Pacotes por distribuição:

| Distro          | Comando de instalação                                              |
|-----------------|--------------------------------------------------------------------|
| Fedora / RHEL   | `sudo dnf install libxml2-devel openssl-devel cmake gcc`           |
| Debian / Ubuntu | `sudo apt install libxml2-dev libssl-dev cmake gcc`                |
| Alpine          | `sudo apk add libxml2-dev openssl-dev cmake build-base`            |
| macOS (brew)    | `brew install libxml2 openssl cmake`                               |

Conferir as versões:

```bash
gcc --version
cmake --version
```

### b. Obter a lib

A partir do checkout, compile com CMake (não há registry para C: a "obtenção" é compilar a partir do código-fonte):

```bash
cd langs/c
cmake -B build -S .
cmake --build build -j
```

> **Quando publicado:** não se aplica. C não tem um gerenciador de pacotes central. Após `cmake --install build`, outros projetos a localizam via `pkg-config --cflags --libs tiss-hash` ou `find_package(tiss_hash)` no CMake.

### c. Snippet mínimo

Salve como `exemplo.c`:

```c
#include "tiss_hash.h"
#include <stdio.h>

int main(void) {
    char out[TISS_HASH_HEX_LEN];   /* 33: 32 caracteres + o terminador de string */
    tiss_hash_status_t rc = tiss_hash_file("conformance/inputs/syn_minimal.xml", out);
    if (rc != TISS_HASH_OK) {
        fprintf(stderr, "erro: %s\n", tiss_hash_strerror(rc));
        return 1;
    }
    printf("%s\n", out);   /* 32 caracteres hex minúsculos */
    return 0;
}
```

Compile e rode (após `cmake --install build`, usando o pkg-config):

```bash
gcc exemplo.c $(pkg-config --cflags --libs tiss-hash) -o exemplo
./exemplo
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`.)

### e. Como tratar erro

C não tem exceções. O retorno é o enum `tiss_hash_status_t`. `TISS_HASH_OK` (valor 0) é sucesso; qualquer outro valor é erro. Sempre verifique o retorno:

```c
char out[TISS_HASH_HEX_LEN];
tiss_hash_status_t rc = tiss_hash_file("nao_existe.xml", out);
switch (rc) {
    case TISS_HASH_OK:               printf("%s\n", out); break;
    case TISS_HASH_ERR_INVALID_XML:  fprintf(stderr, "XML inválido\n"); break;
    case TISS_HASH_ERR_IO:           fprintf(stderr, "erro de leitura\n"); break;
    default:                         fprintf(stderr, "%s\n", tiss_hash_strerror(rc));
}
```

A função `tiss_hash_strerror(rc)` devolve uma mensagem de texto para qualquer código. Para bytes na memória, use `tiss_hash_bytes(xml, len, out)`.

README completo do port: [`../langs/c/README.md`](../langs/c/README.md).

## 5. C++

### a. Instalar a toolchain

O port C++ precisa de um compilador C++20 (g++ ou clang++), CMake e duas bibliotecas: `pugixml` (parser) e OpenSSL (MD5). Se o `pugixml` não estiver instalado, o CMake baixa automaticamente. Páginas oficiais: <https://gcc.gnu.org/>, <https://cmake.org/download/>.

Pacotes por distribuição:

| Distro          | Comando de instalação                                                |
|-----------------|----------------------------------------------------------------------|
| Fedora / RHEL   | `sudo dnf install pugixml-devel openssl-devel cmake gcc-c++`          |
| Debian / Ubuntu | `sudo apt install libpugixml-dev libssl-dev cmake g++`               |
| Arch            | `sudo pacman -S pugixml openssl cmake gcc`                            |
| macOS (brew)    | `brew install pugixml openssl cmake`                                 |

Conferir as versões:

```bash
g++ --version
cmake --version
```

### b. Obter a lib

A partir do checkout (o port é header-only, ou seja, basta incluir o cabeçalho; o build serve para os testes e para a instalação de sistema):

```bash
cd langs/cpp
cmake -B build -S .
cmake --build build -j
```

> **Quando publicado:** não se aplica. C++ não tem registry central padrão. Após `cmake --install build`, projetos a localizam via `find_package(tiss_hash_cpp)`.

### c. Snippet mínimo

Salve como `exemplo.cpp`:

```cpp
#include <tiss_hash/tiss_hash.hpp>
#include <iostream>

int main() {
    try {
        const std::string h = tiss_hash::HashTissFile("conformance/inputs/syn_minimal.xml");
        std::cout << h << '\n';   // 32 caracteres hex minúsculos
    } catch (const tiss_hash::InvalidTissXml& e) {
        std::cerr << "XML inválido: " << e.what() << '\n';
        return 1;
    }
}
```

Compile e rode (após `cmake --install build`, usando o pkg-config):

```bash
g++ -std=c++20 exemplo.cpp $(pkg-config --cflags --libs tiss-hash-cpp) -o exemplo
./exemplo
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`.)

### e. Como tratar erro

C++ usa exceções. A exceção é `tiss_hash::InvalidTissXml` (subclasse de `std::runtime_error`). Capture com `try`/`catch`, como no snippet acima. Para bytes na memória, use `tiss_hash::HashTiss(std::string_view)`.

README completo do port: [`../langs/cpp/README.md`](../langs/cpp/README.md).

## 6. Node.js

### a. Instalar a toolchain

Node.js 20 ou mais novo (versões LTS recomendadas: 20 ou 22). Site oficial: <https://nodejs.org/>. O instalador já traz o `npm` (gerenciador de pacotes do Node).

Conferir as versões:

```bash
node --version
npm --version
```

### b. Obter a lib

O port Node.js está publicado no npm ([npmjs.com/package/tiss-hash](https://www.npmjs.com/package/tiss-hash)). Via primária, instale direto da internet, dentro do seu projeto:

```bash
npm install tiss-hash
```

(`npm` é o gerenciador de pacotes do Node; ele baixa o pacote do npm registry, o repositório oficial de pacotes Node.js.)

A única dependência é `@xmldom/xmldom` (parser em JavaScript puro). O `npm install` cuida dela.

> **Alternativa: instalar do fonte (a partir do checkout).** Se você clonou o repositório e quer usar o código local (por exemplo, para mexer na lib), instale as dependências dentro da pasta do port:
>
> ```bash
> cd langs/node
> npm install
> ```
>
> Para usar esse checkout em outro projeto seu, aponte o `npm install` para a pasta do port:
>
> ```bash
> npm install /caminho/para/TISS_ANS_hash/langs/node
> ```

### c. Snippet mínimo

Salve como `exemplo.mjs` dentro de `langs/node` (a extensão `.mjs` ativa o modo de módulos ESM):

```js
import { hashTiss, hashTissFile } from 'tiss-hash';
import { readFileSync } from 'node:fs';

// A partir de bytes (síncrono)
const md5 = hashTiss(readFileSync('../../conformance/inputs/syn_minimal.xml'));
console.log(md5);   // 32 caracteres hex minúsculos

// A partir do caminho do arquivo (assíncrono: precisa de await)
const md5File = await hashTissFile('../../conformance/inputs/syn_minimal.xml');
console.log(md5File);
```

Rode com:

```bash
node exemplo.mjs
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`.)

### e. Como tratar erro

O erro é a classe `InvalidTissXmlError` (subclasse de `Error`). Capture com `try`/`catch`:

```js
import { hashTiss, InvalidTissXmlError } from 'tiss-hash';

try {
  hashTiss(Buffer.from('<isto-nao-fecha'));
} catch (err) {
  if (err instanceof InvalidTissXmlError) {
    console.error('XML rejeitado:', err.message);
  } else {
    throw err;   // outro erro inesperado: repassa
  }
}
```

README completo do port: [`../langs/node/README.md`](../langs/node/README.md).

## 7. PHP

### a. Instalar a toolchain

PHP 8.1 ou mais novo, mais o Composer (gerenciador de dependências do PHP). Sites oficiais: PHP <https://www.php.net/downloads>, Composer <https://getcomposer.org/download/>. Precisa também das extensões `dom`, `libxml` e `mbstring` (vêm ativadas na maioria das instalações).

Conferir as versões:

```bash
php --version
composer --version
```

### b. Obter a lib

O port PHP está publicado no Packagist ([packagist.org/packages/petrinhu/tiss-hash](https://packagist.org/packages/petrinhu/tiss-hash)). Via primária, dentro do seu projeto, instale direto da internet:

```bash
composer require petrinhu/tiss-hash
```

(`composer` é o gerenciador de dependências do PHP; ele baixa o pacote do Packagist, o repositório oficial de pacotes PHP.) Para você é transparente que o Packagist serve o pacote a partir de um repositório dedicado (`github.com/petrinhu/tiss-hash-php`, um espelho somente-leitura de `langs/php` deste monorepo): o comando acima é tudo o que você precisa.

> **Alternativa: instalar do fonte (a partir do checkout).** Se você clonou o repositório e quer usar o código local (por exemplo, para mexer na lib), aponte o Composer para a pasta do port:
>
> ```bash
> composer config repositories.tiss-hash path /caminho/para/TISS_ANS_hash/langs/php
> composer require petrinhu/tiss-hash:@dev
> ```
>
> As extensões `dom`, `libxml` e `mbstring` são necessárias e vêm ativadas na maioria das instalações; o `composer require` cuida do resto.

### c. Snippet mínimo

Salve como `exemplo.php` dentro de `langs/php`:

```php
<?php
require 'vendor/autoload.php';   // carregador automático que o Composer gera

use TissHash\TissHash;

// A partir de bytes do arquivo
$hash = TissHash::hashTiss(file_get_contents('../../conformance/inputs/syn_minimal.xml'));
echo $hash . "\n";   // 32 caracteres hex minúsculos

// Ou direto pelo caminho
echo TissHash::hashTissFile('../../conformance/inputs/syn_minimal.xml') . "\n";
```

Rode com:

```bash
php exemplo.php
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`.)

### e. Como tratar erro

O erro é a exceção `TissHash\InvalidTissXmlException` (subclasse de `\RuntimeException`). Capture com `try`/`catch`:

```php
use TissHash\InvalidTissXmlException;
use TissHash\TissHash;

try {
    $hash = TissHash::hashTiss('<isto-nao-eh-xml-valido');
} catch (InvalidTissXmlException $e) {
    error_log('XML rejeitado: ' . $e->getMessage());
}
```

A mensagem de erro nunca contém o XML original (só o erro técnico do parser), para não vazar dados de paciente nos logs.

README completo do port: [`../langs/php/README.md`](../langs/php/README.md).

## 8. Java

### a. Instalar a toolchain

JDK (Java Development Kit) 17 ou mais novo, mais o Maven (ferramenta de build). Sites oficiais: JDK <https://adoptium.net/> (build aberto Temurin), Maven <https://maven.apache.org/download.cgi>.

Conferir as versões:

```bash
java -version
mvn -version
```

### b. Obter a lib

A partir do checkout, gere o jar (o arquivo empacotado da biblioteca Java):

```bash
cd langs/java
mvn -q package
```

> **Quando publicado (Maven Central):** adicione ao `pom.xml` do seu projeto:
>
> ```xml
> <dependency>
>   <groupId>dev.petrus</groupId>
>   <artifactId>tiss-hash</artifactId>
>   <version>0.1.0</version>
> </dependency>
> ```

### c. Snippet mínimo

Salve como `Exemplo.java`:

```java
import dev.petrus.tisshash.TissHash;
import java.nio.file.Files;
import java.nio.file.Path;

public class Exemplo {
    public static void main(String[] args) throws Exception {
        // A partir de bytes
        byte[] xml = Files.readAllBytes(Path.of("conformance/inputs/syn_minimal.xml"));
        System.out.println(TissHash.hashTiss(xml));   // 32 caracteres hex minúsculos

        // Atalho de arquivo (recebe um Path)
        System.out.println(TissHash.hashTissFile(Path.of("conformance/inputs/syn_minimal.xml")));
    }
}
```

Compile e rode apontando para o jar gerado em `langs/java/target/`:

```bash
javac -cp langs/java/target/tiss-hash-0.1.0.jar Exemplo.java
java  -cp .:langs/java/target/tiss-hash-0.1.0.jar Exemplo
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`.)

### e. Como tratar erro

O erro é a exceção `dev.petrus.tisshash.InvalidTissXmlException`. Capture com `try`/`catch`:

```java
import dev.petrus.tisshash.InvalidTissXmlException;
import dev.petrus.tisshash.TissHash;

try {
    String hash = TissHash.hashTiss("<isto-nao-fecha".getBytes());
} catch (InvalidTissXmlException e) {
    System.err.println("XML rejeitado: " + e.getMessage());
}
```

README completo do port: [`../langs/java/README.md`](../langs/java/README.md).

## 9. Go

### a. Instalar a toolchain

Go 1.22 ou mais novo. Site oficial: <https://go.dev/dl/>. O instalador já traz tudo (compilador e gerenciador de módulos).

Conferir a versão:

```bash
go version
```

### b. Obter a lib

O módulo Go é resolvido direto pela tag de versão (via proxy do Go / pkg.go.dev). No seu projeto, dentro de um módulo Go já iniciado (`go mod init ...`), adicione a dependência:

```bash
go get github.com/petrinhu/TISS_ANS_hash/langs/go@v0.2.1
```

A única dependência externa é `golang.org/x/text` (para decodificar ISO-8859-1); o `go get` cuida dela.

> **Alternativa: a partir do checkout.** Se você clonou o repositório e quer trabalhar com o código local, resolva as dependências dentro da pasta do port:
>
> ```bash
> cd langs/go
> go mod tidy
> ```

### c. Snippet mínimo

Salve como `exemplo.go` dentro de `langs/go`:

```go
package main

import (
    "fmt"
    "os"

    tisshash "github.com/petrinhu/TISS_ANS_hash/langs/go"
)

func main() {
    // A partir de bytes
    data, err := os.ReadFile("../../conformance/inputs/syn_minimal.xml")
    if err != nil {
        panic(err)
    }
    hash, err := tisshash.HashTiss(data)
    if err != nil {
        panic(err)
    }
    fmt.Println(hash)   // 32 caracteres hex minúsculos

    // Ou direto do arquivo
    hashFile, err := tisshash.HashTissFile("../../conformance/inputs/syn_minimal.xml")
    if err != nil {
        panic(err)
    }
    fmt.Println(hashFile)
}
```

Rode com:

```bash
go run exemplo.go
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`.)

### e. Como tratar erro

Go não usa exceções: funções devolvem um valor de erro (`error`) junto com o resultado. Quando o `error` não é nulo, deu problema. Para distinguir XML inválido de outros erros, use `errors.As` com o tipo `*tisshash.InvalidTissXMLError`:

```go
import (
    "errors"
    "log"
)

hash, err := tisshash.HashTiss([]byte("<isto-nao-fecha"))
if err != nil {
    var invErr *tisshash.InvalidTissXMLError
    if errors.As(err, &invErr) {
        log.Printf("XML inválido: %v", invErr.Unwrap())
    } else {
        log.Printf("outro erro: %v", err)
    }
    return
}
```

README completo do port: [`../langs/go/README.md`](../langs/go/README.md).

## 10. C# / .NET

### a. Instalar a toolchain

.NET SDK 8.0 ou mais novo (versão LTS). Site oficial: <https://dotnet.microsoft.com/download>. O SDK traz o comando `dotnet`, que compila e roda.

Conferir a versão:

```bash
dotnet --version
```

### b. Obter a lib

A partir do checkout, adicione o projeto como referência ao seu projeto (não há registry usado ainda):

```bash
dotnet add reference /caminho/para/TISS_ANS_hash/langs/csharp/src/TissHash/TissHash.csproj
```

> **Quando publicado (NuGet):** `dotnet add package TissHash --version 0.1.0`

### c. Snippet mínimo

Em um projeto de console (`dotnet new console`), use no `Program.cs`:

```csharp
using TissHashLib = TissHash.TissHash;   // alias evita confusão entre o namespace e a classe (têm o mesmo nome)

// A partir de bytes
byte[] xml = File.ReadAllBytes("conformance/inputs/syn_minimal.xml");
Console.WriteLine(TissHashLib.HashTiss(xml));   // 32 caracteres hex minúsculos

// Atalho a partir do caminho
Console.WriteLine(TissHashLib.HashTissFile("conformance/inputs/syn_minimal.xml"));
```

Rode com:

```bash
dotnet run
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`.)

### e. Como tratar erro

O erro é a exceção `TissHash.InvalidTissXmlException`. A causa técnica original fica em `InnerException`. Capture com `try`/`catch`:

```csharp
using TissHashLib = TissHash.TissHash;

try {
    string hash = TissHashLib.HashTiss(System.Text.Encoding.UTF8.GetBytes("<isto-nao-fecha"));
} catch (TissHash.InvalidTissXmlException e) {
    Console.Error.WriteLine($"XML rejeitado: {e.Message}");
}
```

Entrada nula dispara `ArgumentNullException`.

README completo do port: [`../langs/csharp/README.md`](../langs/csharp/README.md).

## 11. Kotlin

### a. Instalar a toolchain

O Kotlin roda na JVM, então você precisa de duas coisas:

- **JDK** (Java Development Kit) 17 ou mais novo. Site oficial: <https://adoptium.net/> (build aberto Temurin).
- **Compilador Kotlin** (`kotlinc`): baixe o release oficial em <https://github.com/JetBrains/kotlin/releases> e extraia (o binário fica em `kotlinc/bin/`), ou instale via [SDKMAN!](https://sdkman.io/) com `sdk install kotlin`.

Conferir as versões:

```bash
java --version
kotlinc -version
```

> **Nota sobre JDK 25.** O `kotlinc` 2.1.0 falha ao rodar **sob** JDK 25. O `build.sh` deste port contorna isso sozinho. Se você usa Gradle ou Maven, prefira um JDK 17 ou 21 LTS como toolchain de build.

### b. Obter a lib

A partir do checkout, compile e rode a conformidade com o script self-contained do port:

```bash
cd langs/kotlin
./build.sh         # compila a lib + roda os 20 vetores e os goldens
./build.sh jar     # idem + gera build/tiss-hash-kotlin-0.1.0.jar
```

> **Quando publicado (Maven Central):** adicione ao `build.gradle.kts` do seu projeto:
>
> ```kotlin
> dependencies {
>     implementation("dev.petrus:tiss-hash-kotlin:0.1.0")
> }
> ```

> **Jar prebuilt:** o jar do Kotlin (`tiss-hash-kotlin-0.1.0.jar`) está anexado aos releases v0.2.1 dos **dois hosts** (GitHub e Codeberg). Você também pode buildá-lo do fonte com `./build.sh jar` (comando acima).

A lib tem **zero dependência de runtime** além do `kotlin-stdlib`: o parser XML e o MD5 vêm da própria JDK.

### c. Snippet mínimo

Salve como `Exemplo.kt`:

```kotlin
import dev.petrus.tisshash.hashTiss
import dev.petrus.tisshash.hashTissFile
import java.nio.file.Files
import java.nio.file.Path

fun main() {
    // A partir de bytes
    val xml: ByteArray = Files.readAllBytes(Path.of("conformance/inputs/syn_minimal.xml"))
    println(hashTiss(xml))   // 32 caracteres hex minúsculos

    // Atalho de arquivo (recebe um Path)
    println(hashTissFile(Path.of("conformance/inputs/syn_minimal.xml")))
}
```

Compile e rode apontando para o jar gerado em `langs/kotlin/build/`:

```bash
kotlinc Exemplo.kt -cp langs/kotlin/build/tiss-hash-kotlin-0.1.0.jar -include-runtime -d exemplo.jar
java -cp exemplo.jar:langs/kotlin/build/tiss-hash-kotlin-0.1.0.jar ExemploKt
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`.)

### e. Como tratar erro

O erro é a exceção `InvalidTissXmlException` (subclasse de `RuntimeException`, ou seja, não checada). É lançada para XML malformado, múltiplos `<ans:hash>` ou encoding UTF-16/UTF-32. Capture com `try`/`catch`:

```kotlin
import dev.petrus.tisshash.hashTiss
import dev.petrus.tisshash.InvalidTissXmlException

try {
    hashTiss("<isto-nao-fecha".toByteArray())
} catch (e: InvalidTissXmlException) {
    System.err.println("XML rejeitado: ${e.message}")
}
```

Chamando a partir de **Java** (interop): as funções top-level viram métodos estáticos da classe `dev.petrus.tisshash.TissHash` (`TissHash.hashTiss(xmlBytes)`).

README completo do port: [`../langs/kotlin/README.md`](../langs/kotlin/README.md).

## 12. Delphi / Object Pascal (Free Pascal)

### a. Instalar a toolchain

O port é escrito em `{$mode delphi}` e compila tanto no **Free Pascal (FPC)** quanto no **Delphi**. O build e os testes desta máquina rodam em FPC. Instale o Free Pascal:

| Distro / sistema      | Comando / link                                                  |
|-----------------------|-----------------------------------------------------------------|
| Fedora / RHEL         | `sudo dnf install fpc`                                           |
| Debian / Ubuntu       | `sudo apt install fpc`                                           |
| Windows / macOS       | site oficial <https://www.freepascal.org/download.html> ou Lazarus (traz o FPC) <https://www.lazarus-ide.org/> |

Conferir a versão (3.2 ou mais novo recomendado):

```bash
fpc -iV
```

As unidades usadas (`fcl-xml` para o DOM, `md5` para o hash, `fcl-json` para os testes) já vêm na instalação padrão do FPC: nenhuma biblioteca extra precisa ser baixada.

### b. Obter a lib

Não há registry para Object Pascal: a "obtenção" é compilar a partir do código-fonte. A partir do checkout:

```bash
cd langs/delphi
make            # compila a lib + CLI + testes em build/
make test       # roda os 20 vetores de conformidade
```

> **Quando publicado:** não se aplica. Object Pascal não tem um gerenciador de pacotes central padrão. Para usar em outro projeto, adicione `langs/delphi/src/` ao search path de units do seu compilador e dê `uses TissHash;`.

Para reusar no seu código, basta colocar a unit `TissHash` (`src/TissHash.pas`) no caminho de units do seu projeto.

### c. Snippet mínimo

Salve como `exemplo.pas` (a unit `TissHash` precisa estar no search path; rode a partir da raiz do repositório para o caminho do arquivo bater):

```pascal
program exemplo;

{$mode delphi}{$H+}

uses
  SysUtils, TissHash;

begin
  // A partir de um arquivo (caminho do disco):
  Writeln(HashTissFile('conformance/inputs/syn_minimal.xml'));  // 32 chars hex minúsculos
end.
```

Compile e rode (apontando o search path de units para `langs/delphi/src`):

```bash
fpc -O2 -Mdelphi -Fulangs/delphi/src exemplo.pas
./exemplo
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`.)

### e. Como tratar erro

Object Pascal usa exceções. Entrada fora do contrato (XML malformado, encoding fora de escopo, múltiplos `<ans:hash>`, entrada vazia) lança `EInvalidTissXml` (subclasse de `Exception`). Capture com `try`/`except`:

```pascal
uses SysUtils, TissHash;

try
  HashHex := HashTiss(Bytes);
except
  on E: EInvalidTissXml do
    Writeln(ErrOutput, 'XML inválido: ', E.Message);
end;
```

`HashTissFile` ainda pode propagar `EFOpenError` / `EReadError` (falha de I/O) da RTL: capture-as separadamente se precisar distinguir I/O de XML inválido. Para usar a partir de bytes já em memória, use `HashTiss(const Bytes: TBytes)`.

README completo do port (inclui a nota de compatibilidade Delphi): [`../langs/delphi/README.md`](../langs/delphi/README.md).

## 13. Dart

### a. Instalar a toolchain

Dart 3.4 ou mais novo. Site oficial: <https://dart.dev/get-dart>. O SDK do Flutter também já inclui o Dart. O comando `dart` traz o `pub` (gerenciador de pacotes) junto.

Conferir a versão:

```bash
dart --version
```

### b. Obter a lib

A partir do checkout, baixe as dependências do port:

```bash
cd langs/dart
dart pub get
```

> **Quando publicado (pub.dev):** `dart pub add tiss_hash`

Para usar em outro projeto seu enquanto não há publicação, aponte para o checkout no seu `pubspec.yaml`:

```yaml
dependencies:
  tiss_hash:
    path: /caminho/para/TISS_ANS_hash/langs/dart
```

As dependências são `xml` (parser, pure-Dart) e `crypto` (MD5). O `dart pub get` cuida das duas.

### c. Snippet mínimo

Salve como `exemplo.dart` dentro de `langs/dart`:

```dart
import 'dart:io';
import 'package:tiss_hash/tiss_hash.dart';

Future<void> main() async {
  // A partir de bytes (síncrono)
  final md5 = hashTiss(File('../../conformance/inputs/syn_minimal.xml').readAsBytesSync());
  print(md5);   // 32 caracteres hex minúsculos

  // A partir do caminho do arquivo (assíncrono: precisa de await)
  final md5File = await hashTissFile('../../conformance/inputs/syn_minimal.xml');
  print(md5File);
}
```

Rode com:

```bash
dart run exemplo.dart
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`.)

### e. Como tratar erro

O erro é a classe `InvalidTissXmlException` (implementa `Exception`). É lançada quando o XML é malformado, tem encoding fora de escopo, ou tem mais de um `<ans:hash>`. Capture com `try`/`on`:

```dart
import 'dart:convert';
import 'package:tiss_hash/tiss_hash.dart';

void main() {
  try {
    hashTiss(utf8.encode('<isto-nao-eh-xml'));
  } on InvalidTissXmlException catch (e) {
    print('XML rejeitado: ${e.message}');
  }
}
```

README completo do port: [`../langs/dart/README.md`](../langs/dart/README.md).

## 14. WASM (WebAssembly)

O port WASM calcula o hash **dentro do navegador do usuário** (ou no Node), sem enviar nada para servidor nenhum. Esse é o ponto: o XML TISS carrega dados pessoais de paciente (PII sob a LGPD), e mandar o arquivo para um servidor hashear criaria um ponto de vazamento. No WASM, o arquivo é selecionado, o hash é calculado localmente e **nada trafega** (nem o XML, nem o hash, nem metadado). É o argumento de privacidade mais forte do projeto, e só o WASM o entrega. Decisão em [`../docs/adr/0006-wasm-port.md`](adr/0006-wasm-port.md).

O port não reimplementa o algoritmo: ele reusa o core Rust (`langs/rust/`), compilado para `wasm32-unknown-unknown` e exposto ao JavaScript via `wasm-bindgen`. O hash sai **byte a byte idêntico** ao dos outros 12 ports.

### a. Instalar a toolchain

Para **gerar** o módulo (a pasta `pkg/`) a partir do fonte, você precisa de:

- **cargo + rustc** com o target `wasm32-unknown-unknown` (no Fedora, o target do cargo do sistema já vem instalado). Instalador Rust: <https://www.rust-lang.org/tools/install>.
- **wasm-bindgen-cli** na versão que **casa** com a `wasm-bindgen` fixada no `Cargo.toml` (atualmente `0.2.122`). Versões diferentes quebram o glue gerado:

  ```bash
  cargo install wasm-bindgen-cli --version 0.2.122
  ```

Para apenas **consumir** o módulo já gerado, você precisa só de um navegador moderno ou do Node.js 20+ (testado em Node 22): o `pkg/` distribuído traz `.wasm` + `.js` prontos, sem toolchain Rust.

### b. Obter a lib

A partir do checkout, gere o `pkg/`:

```bash
cd langs/wasm
bash build.sh      # compila + roda wasm-bindgen (gera pkg/web e pkg/node)
```

> **Quando publicado (npm):** `npm install tiss-hash-wasm`

O `build.sh` gera dois bindings: `pkg/web/` (ESM, para o navegador) e `pkg/node/` (CommonJS, para o Node).

### c. Snippet mínimo

**No navegador (ESM).** O navegador exige servir os arquivos por HTTP (não funciona abrindo o `.html` direto com `file://`):

```bash
cd langs/wasm
python3 -m http.server 8000
# abra http://localhost:8000/examples/browser/
```

No seu código:

```html
<script type="module">
  import init, { hashTiss } from './pkg/web/tiss_hash_wasm.js';

  await init();   // carrega o .wasm uma vez (fetch)

  const file = document.querySelector('input[type=file]').files[0];
  const bytes = new Uint8Array(await file.arrayBuffer());
  const md5 = hashTiss(bytes);   // 32 caracteres hex minúsculos
  console.log(md5);
</script>
```

**No Node.js.** O binding `pkg/node` é CommonJS e carrega o `.wasm` de forma síncrona ao ser importado (não precisa de `init()`). Salve como `exemplo.mjs` dentro de `langs/wasm`:

```js
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
const require = createRequire(import.meta.url);
const { hashTiss } = require('./pkg/node/tiss_hash_wasm.js');

const md5 = hashTiss(new Uint8Array(readFileSync('../../conformance/inputs/syn_minimal.xml')));
console.log(md5);   // 32 caracteres hex minúsculos
```

Rode com:

```bash
node exemplo.mjs
```

### d. Saída esperada

```
3aa0c578c95cdb861a125f480a8a4de5
```

(Hash ilustrativo do vetor sintético `syn_minimal.xml`. No navegador, o valor aparece no console do desenvolvedor.)

### e. Como tratar erro

`hashTiss` **lança** (throw) um `Error` quando o XML é rejeitado (malformado, múltiplos `<ans:hash>`, ou encoding UTF-16/UTF-32). A mensagem vem do core Rust (diagnóstico do parser) e **não contém PII**. Capture com `try`/`catch`:

```js
try {
  hashTiss(bytes);
} catch (err) {
  // err.message ex.: "XML inválido para hash TISS: ..."
  console.error('XML rejeitado:', err.message);
}
```

Os tipos TypeScript (`.d.ts`) são gerados automaticamente pelo `wasm-bindgen` e acompanham os bindings em `pkg/`.

README completo do port: [`../langs/wasm/README.md`](../langs/wasm/README.md).

## 15. Receitas comuns (Python, como exemplo)

As receitas abaixo usam Python porque é o port mais maduro, mas a ideia vale para qualquer linguagem (a lib só **calcula** o hash; montar o XML, assinar e enviar é com você).

### Receita 1: preencher o `<ans:hash>` antes de enviar

Fluxo de quem gera uma mensagem TISS para mandar à operadora:

```python
from tiss_hash import hash_tiss
from lxml import etree   # biblioteca para montar/editar XML

def preparar_envio(raw_xml: bytes) -> bytes:
    """Calcula o hash, grava em <ans:hash> e devolve o XML pronto para assinar."""
    digest = hash_tiss(raw_xml)

    root = etree.fromstring(raw_xml)
    ns = {"ans": "http://www.ans.gov.br/padroes/tiss/schemas"}
    hash_el = root.find(".//ans:hash", ns)
    hash_el.text = digest

    return etree.tostring(root, xml_declaration=True, encoding="ISO-8859-1")

# Passos em produção:
# 1. monte o XML TISS (a lib calcula o hash do passo 1).
# 2. grave o hash em <ans:hash> (a lib zera o campo internamente para o cálculo,
#    mas quem grava o valor final no arquivo é você).
# 3. assine com XAdES (biblioteca externa, fora do escopo deste projeto).
# 4. envie via SOAP (também fora do escopo).
```

### Receita 2: processar uma pasta inteira de lotes

```python
from pathlib import Path
from tiss_hash import InvalidTissXml, hash_tiss_file

def hashear_pasta(pasta: str) -> dict[str, str]:
    """Devolve {nome_do_arquivo: hash_ou_mensagem_de_erro}."""
    resultados: dict[str, str] = {}
    for xml in Path(pasta).glob("*.xml"):
        try:
            resultados[xml.name] = hash_tiss_file(xml)
        except InvalidTissXml as exc:
            resultados[xml.name] = f"ERRO: {exc}"
    return resultados

for arquivo, valor in hashear_pasta("envios_pendentes").items():
    print(f"{valor}  {arquivo}")
```

A função é **pura** (sem estado guardado entre chamadas), então pode rodar em paralelo sem cuidado extra.

### Receita 3: endpoint HTTP (FastAPI)

```python
from fastapi import FastAPI, HTTPException, Request
from tiss_hash import InvalidTissXml, hash_tiss

app = FastAPI()

@app.post("/v1/tiss/hash")
async def calcular_hash(request: Request) -> dict[str, str]:
    raw = await request.body()
    try:
        return {"hash": hash_tiss(raw)}
    except InvalidTissXml as exc:
        raise HTTPException(status_code=422, detail=str(exc))
```

Atenção: o XML contém dados pessoais de pacientes. Esse endpoint **não deve registrar (logar) o corpo da requisição** e idealmente roda só em rede interna. Ver [`legal/LGPD-NOTE.md`](legal/LGPD-NOTE.md).

## 12. Pegadinhas (valem para os 13 ports)

### 12.1 O encoding dos bytes do MD5 é UTF-8, não ISO-8859-1

O manual TISS diz que tudo deve ser ISO-8859-1. **Isso não vale para o cálculo do hash.** Os bytes que alimentam o MD5 são sempre **UTF-8**, mesmo que o arquivo XML esteja declarado como ISO-8859-1.

A lib trata isso sozinha: você passa os bytes brutos (no encoding que o XML declarar) e a lib reconverte para UTF-8 internamente antes do MD5. **Não decodifique manualmente antes de chamar:**

```python
# ERRADO: vai dar hash diferente
texto = open("envio.xml", encoding="iso-8859-1").read()
hash_tiss(texto.encode("iso-8859-1"))

# CERTO: leia em binário e passe os bytes crus
raw = open("envio.xml", "rb").read()
hash_tiss(raw)
```

Por que isso acontece? Veja a entrada no [FAQ](#por-que-utf-8-e-não-iso-8859-1) e [`SPEC.md §4`](SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1).

### 12.2 Não "arrume" o XML antes de hashear

Não rode `xmllint --format`, `xmllint --c14n`, nem qualquer "embelezador" de XML antes de passar para a lib. O algoritmo já ignora a indentação entre etiquetas, mas é **sensível** a:

- Espaços dentro de um valor: `<numeroGuia>00123 </numeroGuia>` é diferente de `<numeroGuia>00123</numeroGuia>`.
- Quebras de linha (CR/LF) dentro de um valor.
- Comentários adicionados ou removidos (eles entram no cálculo; ver [`conformance/AMBIGUITY_NOTES.md`](../conformance/AMBIGUITY_NOTES.md)).

Passe exatamente os bytes que serão enviados à ANS. Nada mais.

### 12.3 As funções são puras (seguras para usar em paralelo)

As funções não guardam estado entre chamadas. Você pode chamá-las de várias threads ou processos ao mesmo tempo, sem proteção extra.

### 12.4 Não confie no hash já gravado no arquivo

XMLs antigos costumam trazer um valor **errado** dentro de `<ans:hash>` (calculado com ISO-8859-1, que a ANS rejeita). Sempre recalcule com esta lib antes de enviar.

## 13. Validar a lib na sua máquina

Cada port traz a suíte de 20 vetores de conformidade. Rodá-la confirma que a instalação ficou correta. Resultado esperado: **20/20 PASS** (os 2 vetores negativos "passam" porque a lib os rejeita, que é o comportamento esperado).

| Linguagem | Comando (dentro de `langs/<lang>/`)          |
|-----------|----------------------------------------------|
| Python    | `pip install -e ".[dev]" && pytest -v`       |
| Rust      | `cargo test`                                 |
| C         | `cmake -B build -S . && cmake --build build && ctest --test-dir build --output-on-failure` |
| C++       | `cmake -B build -S . && cmake --build build && ctest --test-dir build --output-on-failure` |
| Node.js   | `npm install && npm test`                    |
| PHP       | `composer install && composer test`          |
| Java      | `mvn -q test`                                |
| Go        | `go test -v ./...`                           |
| C#        | `dotnet test`                                |
| Kotlin    | `./build.sh`                                 |
| Delphi/FPC| `make test`                                  |
| Dart      | `dart pub get && dart test`                  |
| WASM      | `bash build.sh && npm test`                  |

> O port Python tem 24 testes no total: os 20 vetores de conformidade mais 4 testes auxiliares de API.

## 14. FAQ

### Qual linguagem escolher?

Escolha a linguagem que o **resto do seu sistema** já usa. As 13 produzem o mesmo hash, então não há vantagem técnica de hash em uma sobre as outras: a melhor é a que se encaixa no seu projeto sem você ter que aprender uma stack nova.

- Já tem um backend **Python / Node.js / PHP / Java / C# / Go**? Use o port da mesma linguagem.
- Precisa de **desempenho máximo** ou rodar em ambiente sem runtime (firmware, binário pequeno)? **Rust** ou **C/C++**.
- Vai embutir em outra aplicação **C/C++** existente? Os ports C (API estilo C) e C++ (API com exceções) existem justamente para isso.

Na dúvida, comece pelo **Python**: é o port mais maduro e o de referência.

### Os resultados são iguais entre linguagens?

**Sim, byte a byte.** Para o mesmo XML de entrada, as 13 linguagens devolvem exatamente o mesmo hash de 32 caracteres. Todas são testadas contra os **mesmos 20 vetores de conformidade** (18 positivos, que devem dar certo, e 2 negativos, que devem ser rejeitados). Você pode calcular o hash em Python e conferir em Go, por exemplo, e o valor será idêntico. Foi assim de propósito: o algoritmo é único; o que muda é só a linguagem que o implementa.

### Por que UTF-8 e não ISO-8859-1?

Porque o algoritmo de verdade (conferido contra hashes que a ANS já aprovou) usa UTF-8 nos bytes do MD5, apesar de o manual TISS dizer "ISO-8859-1". É uma falha de redação do padrão. Detalhes em [`SPEC.md §4`](SPEC.md#4-caveat-crítica-encoding-do-md5-é-utf-8-não-iso-8859-1) e [`conformance/AMBIGUITY_NOTES.md`](../conformance/AMBIGUITY_NOTES.md).

### Posso usar em produção?

Os 13 ports estão prontos e passam os 20 vetores byte a byte. Os parsers são endurecidos contra ataques via XML (XXE, "billion-laughs"). **Recomendação:** antes de pôr em produção, valide você mesmo contra alguns lotes seus que a operadora já aceitou. A licença [MIT](../LICENSE) é explícita: sem garantias.

### E se a ANS mudar o algoritmo?

A especificação em [`SPEC.md`](SPEC.md) é versionada. O algoritmo de hash tem sido estável entre as edições anuais do Padrão TISS, então a lib é agnóstica à edição vigente. Se a ANS introduzir uma mudança incompatível, sai uma nova versão maior (2.0.0) com guia de migração.

### Por que MD5, se ele é fraco em criptografia?

Porque é o que o padrão TISS exige. Aqui o MD5 não serve de proteção de segurança: é só um "selo de integridade" do conteúdo do lote (detectar adulteração/corrupção). Autenticidade e não-repúdio ficam com a assinatura digital XAdES (fora do escopo desta lib). Mais em [`legal/DISCLAIMER.md`](legal/DISCLAIMER.md).

### Posso processar XML grande?

Sim. A lib carrega o XML inteiro na memória. O vetor `syn_perf_grande.xml` (cerca de 600 KB, em torno de 1500 guias) processa em poucos milissegundos. Para arquivos de centenas de MB, o gargalo é o parser; nesse caso, processe vários arquivos em paralelo em vez de tentar otimizar um só.

### Por que não posso passar texto (string) em vez de bytes (em Python)?

Porque a lib precisa controlar o encoding. O algoritmo decodifica o XML conforme a declaração `<?xml encoding="..."?>`, e isso só é confiável a partir dos bytes crus. Passar `str` dispara `TypeError`. Nas outras linguagens, a regra equivalente é: passe sempre os bytes lidos em modo binário.

### Tem versão para rodar no navegador (WASM)?

Sim. O port **WASM** (`langs/wasm/`) calcula o hash no navegador do usuário (ou no Node), sem enviar nada para servidor. A motivação é de privacidade (LGPD): rodar o hash localmente evita que o XML com dados de paciente trafegue até o servidor. Veja a [seção 14](#14-wasm-webassembly) deste guia e a [`adr/0006-wasm-port.md`](adr/0006-wasm-port.md).

## 15. Ver também

- [`CONCEITOS.md`](CONCEITOS.md): o que é tudo isto, sem código (explicação para iniciantes).
- [`TUTORIAL.md`](TUTORIAL.md): primeiro hash na tela, passo a passo.
- [`SPEC.md`](SPEC.md): especificação canônica do algoritmo (o quê e por quê).
- [`PORTING_GUIDE.md`](PORTING_GUIDE.md): como portar para uma nova linguagem.
- [`../conformance/TEST_PLAN.md`](../conformance/TEST_PLAN.md): cobertura dos vetores.
- [`../conformance/AMBIGUITY_NOTES.md`](../conformance/AMBIGUITY_NOTES.md): decisões fixadas.
- [`legal/LGPD-NOTE.md`](legal/LGPD-NOTE.md): obrigações de quem integra.
- [`legal/DISCLAIMER.md`](legal/DISCLAIMER.md): limites de responsabilidade.
