# tiss-hash (Java)

Port Java da biblioteca multi-linguagem **TISS_ANS_hash**. Calcula o hash MD5
canônico do epílogo `<ans:hash>` em XMLs do Padrão TISS/ANS (Padrão TISS
4.01.00, Troca de Informações em Saúde Suplementar, regulamentado pela
Agência Nacional de Saúde Suplementar).

- **Repo principal:** <https://github.com/petrinhu/TISS_ANS_hash>
- **Spec canônica:** [`docs/SPEC.md`](../../docs/SPEC.md)
- **Referência:** [`conformance/reference.py`](../../conformance/reference.py)
- **Licença:** MIT
- **Status:** alpha, 15/15 vetores de conformidade passando
- **Compat:** JDK 17+ (testado em OpenJDK 25)

## Coordenadas Maven

> Placeholder até publicação em Maven Central.

```xml
<dependency>
  <groupId>dev.petrus</groupId>
  <artifactId>tiss-hash</artifactId>
  <version>0.1.0</version>
</dependency>
```

## Uso

```java
import dev.petrus.tisshash.TissHash;

import java.nio.file.Files;
import java.nio.file.Paths;

// A partir de bytes
byte[] xml = Files.readAllBytes(Paths.get("lote.xml"));
String md5 = TissHash.hashTiss(xml);
// resultado ilustrativo: "3aa0c578c95cdb861a125f480a8a4de5" (32 chars hex lowercase)

// Atalho de arquivo
String md5b = TissHash.hashTissFile(Paths.get("lote.xml"));
```

## Decisões de stack

| Item | Escolha | Por quê |
|---|---|---|
| Parser XML | `javax.xml.parsers.DocumentBuilder` (DOM W3C) | Stdlib, zero dep runtime, namespace-aware, suporta preservar comentários (ambiguidade #2) |
| MD5 | `java.security.MessageDigest` | Stdlib, sem dep |
| Build | Maven (`pom.xml`) | De facto em libs publicadas em Maven Central; Gradle descartado por verbosidade |
| Testes | JUnit Jupiter 5 + `org.json` (test scope) | Runner padrão; carga de `vectors.json` sem dep runtime |
| JDK mínimo | 17 LTS | `var`, text blocks, `HexFormat`, switch expressions; cobertura ampla em enterprise BR |

Alternativas descartadas:

- **StAX (`XMLStreamReader`)**: streaming exige reconstrução manual da árvore e da noção de folha; sem ganho real em XMLs TISS (< 10 MB).
- **JAXB**: overkill; foi removido do JDK 11+, exige dep externa.
- **DOM4J / JDOM**: 3rd party, sem ganho sobre o DOM padrão para este caso.

## Segurança XML

A factory desabilita: DOCTYPE (`disallow-doctype-decl`), entidades
externas (general + parameter), carga externa de DTD, XInclude. Entity
resolver retorna stream vazio (bloqueia I/O por SystemId). Entidades XML
**predefinidas** (`&amp; &lt; &gt; &quot; &apos;`) continuam sendo
decodificadas, exigência do algoritmo (ver
[`AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md) #4).

## Algoritmo (resumo)

1. Strip de BOM UTF-8 se presente.
2. Parse com `DocumentBuilder` seguro, namespace-aware, comentários preservados.
3. Zera o conteúdo do primeiro `<ans:hash>` (qualquer prefixo, namespace TISS).
4. Concatena o texto de cada **nó-folha** (Element ou Comment cujos filhos NÃO contêm Element/Comment/PI), em ordem de documento.
5. MD5 dos bytes **UTF-8** da string concatenada, não ISO-8859-1, apesar do manual.
6. Hex lowercase, 32 caracteres.

Detalhes e ambiguidades fixadas: [`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md).

## Build & test

### Maven (caminho padrão)

```bash
cd langs/java
mvn -q test     # roda os 15 vetores + testes auxiliares
mvn -q package  # gera target/tiss-hash-0.1.0.jar
```

### Fallback sem Maven (apenas javac+java)

Útil em ambientes que não têm Maven instalado. Requer baixar 2 jars:

```bash
cd langs/java
mkdir -p .libs
curl -fLo .libs/junit-platform-console-standalone.jar \
  https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/1.10.2/junit-platform-console-standalone-1.10.2.jar
curl -fLo .libs/json.jar \
  https://repo1.maven.org/maven2/org/json/json/20240303/json-20240303.jar

mkdir -p target/classes target/test-classes
javac -d target/classes \
  $(find src/main/java -name '*.java')
javac -d target/test-classes \
  -cp target/classes:.libs/junit-platform-console-standalone.jar:.libs/json.jar \
  $(find src/test/java -name '*.java')

java -jar .libs/junit-platform-console-standalone.jar \
  --class-path target/classes:target/test-classes:.libs/json.jar \
  --scan-class-path
```

## Conformidade

Roda os 15 vetores sintéticos em `conformance/vectors.json`. Bate
byte-a-byte com a referência Python e com os demais ports (C, C++, Rust,
Node, PHP, Python).

```
ConformanceTest > conformance(syn_minimal.xml)             OK
ConformanceTest > conformance(syn_acento.xml)              OK
ConformanceTest > conformance(syn_empty.xml)               OK
ConformanceTest > conformance(syn_crlf_value.xml)          OK
ConformanceTest > conformance(syn_multi_guia.xml)          OK
ConformanceTest > conformance(syn_entidades_xml.xml)       OK
ConformanceTest > conformance(syn_cdata.xml)               OK
ConformanceTest > conformance(syn_comentario.xml)          OK
ConformanceTest > conformance(syn_atributo_folha.xml)      OK
ConformanceTest > conformance(syn_namespace_xsi.xml)       OK
ConformanceTest > conformance(syn_whitespace_puro.xml)     OK
ConformanceTest > conformance(syn_leading_zero.xml)        OK
ConformanceTest > conformance(syn_iso8859_simbolos.xml)    OK
ConformanceTest > conformance(syn_perf_grande.xml)         OK
ConformanceTest > conformance(syn_bom_utf8.xml)            OK
```

## Licença

MIT, veja `LICENSE` no diretório do port e na raiz do repositório.
