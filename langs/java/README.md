# tiss-hash (Java)

Calcula a "impressão digital" do trecho final de um documento TISS/ANS. Antes
do código, os termos essenciais:

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
- **Byte**: a menor unidade de dado do computador; um arquivo de texto é uma
  fila de bytes.

Em uma frase: você passa os bytes de um XML TISS e recebe os 32 caracteres do
hash. Este é o port Java ("port" = a mesma lib reescrita em outra linguagem) da
biblioteca multi-linguagem **TISS_ANS_hash**. Para entender o problema que a lib
resolve, veja [`docs/USAGE.md`](../../docs/USAGE.md) (guia de uso) e
[`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) (conceitos e visão geral).

- **Repo principal:** <https://github.com/petrinhu/TISS_ANS_hash>
- **Spec canônica:** [`docs/SPEC.md`](../../docs/SPEC.md)
- **Referência:** [`conformance/reference.py`](../../conformance/reference.py)
- **Licença:** MIT
- **Status:** alpha, 20/20 vetores de conformidade passando (18 positivos + 2 negativos)
- **Compat:** JDK 17+ (testado em OpenJDK 25)

## Antes de começar: instalar o Java (JDK) e o Maven

Para compilar e rodar código Java você precisa do **JDK** (Java Development Kit:
compilador + máquina virtual Java). O **Maven** é a ferramenta que baixa as
dependências e organiza o build.

- Instale o JDK pelo site oficial (escolha a versão 17 ou mais nova):
  <https://adoptium.net/>
- Instale o Maven pelo site oficial: <https://maven.apache.org/install.html>
- Confira a instalação:

```bash
java --version
mvn --version
```

(Existe um caminho sem Maven, só com `javac`+`java`, descrito mais abaixo em
"Fallback sem Maven".)

## Coordenadas Maven

Uma **dependência** é uma biblioteca de terceiros que o seu código usa; o Maven
a baixa por você. As linhas abaixo declaram esta lib como dependência no seu
`pom.xml`.

> Placeholder até publicação em Maven Central (o repositório oficial de pacotes
> Java).

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
3. Zera o conteúdo do `<ans:hash>` (qualquer prefixo, namespace TISS). Documento sem `<ans:hash>` é válido; com múltiplos `<ans:hash>` é **rejeitado**.
4. Concatena o texto de cada **nó-folha** (Element ou Comment cujos filhos NÃO contêm Element/Comment/PI), em ordem de documento.
5. MD5 dos bytes **UTF-8** da string concatenada, não ISO-8859-1, apesar do manual.
6. Hex lowercase, 32 caracteres.

Detalhes e ambiguidades fixadas: [`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md).

## Build & test

### Maven (caminho padrão)

A partir da raiz do repositório (a pasta que você baixou com `git clone`):

```bash
cd langs/java
mvn -q test     # roda os 20 vetores + testes auxiliares
mvn -q package  # gera target/tiss-hash-0.1.0.jar
```

Cada **vetor** é um par "arquivo de entrada -> hash esperado": 18 positivos
(devem produzir um hash) e 2 negativos (devem ser rejeitados).

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

Roda os 20 vetores sintéticos (18 positivos + 2 negativos) em
`conformance/vectors.json`. Bate byte-a-byte com a referência Python e com
os demais ports (C, C++, Rust, Node, PHP, Python, Go, C#). A lista canônica
vive em `conformance/vectors.json`.

```
ConformanceTest > conformance(syn_minimal.xml)             OK
ConformanceTest > conformance(syn_acento.xml)              OK
ConformanceTest > conformance(syn_empty.xml)               OK
ConformanceTest > conformance(syn_crlf_value.xml)          OK
ConformanceTest > conformance(syn_multi_guia.xml)          OK
ConformanceTest > conformance(syn_entidades_xml.xml)       OK
ConformanceTest > conformance(syn_entidade_numerica.xml)   OK
ConformanceTest > conformance(syn_cdata.xml)               OK
ConformanceTest > conformance(syn_comentario.xml)          OK
ConformanceTest > conformance(syn_atributo_folha.xml)      OK
ConformanceTest > conformance(syn_namespace_xsi.xml)       OK
ConformanceTest > conformance(syn_default_ns.xml)          OK
ConformanceTest > conformance(syn_sem_hash.xml)            OK
ConformanceTest > conformance(syn_whitespace_puro.xml)     OK
ConformanceTest > conformance(syn_leading_zero.xml)        OK
ConformanceTest > conformance(syn_iso8859_simbolos.xml)    OK
ConformanceTest > conformance(syn_perf_grande.xml)         OK
ConformanceTest > conformance(syn_bom_utf8.xml)            OK
ConformanceTest > conformance(syn_multi_hash.xml)          OK  (rejeitado: multiplos <ans:hash>)
ConformanceTest > conformance(syn_utf16.xml)               OK  (rejeitado: UTF-16 fora de escopo)
```

## Licença

MIT, veja `LICENSE` no diretório do port e na raiz do repositório.

## Ver também

- [`docs/USAGE.md`](../../docs/USAGE.md): guia de uso, receitas e perguntas
  frequentes (comece por aqui se você quer só usar a lib).
- [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md): conceitos e visão geral.
- [`docs/SPEC.md`](../../docs/SPEC.md): especificação canônica do algoritmo.
- [`docs/PORTING_GUIDE.md`](../../docs/PORTING_GUIDE.md): guia para portar para
  outras linguagens.
- [`conformance/reference.py`](../../conformance/reference.py): implementação de
  referência (o "oráculo" que define a resposta certa).
