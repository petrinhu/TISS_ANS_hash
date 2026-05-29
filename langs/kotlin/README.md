# tiss-hash (Kotlin)

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
hash. Este é o port Kotlin ("port" = a mesma lib reescrita em outra linguagem)
da biblioteca multi-linguagem **TISS_ANS_hash**. Roda na JVM e tem zero
dependência de runtime além do `kotlin-stdlib` (o parser XML e o MD5 vêm da
própria JDK). Para entender o problema que a lib resolve, veja
[`docs/USAGE.md`](../../docs/USAGE.md) (guia de uso) e
[`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) (conceitos e visão geral).

- **Repo principal:** <https://github.com/petrinhu/TISS_ANS_hash>
- **Spec canônica:** [`docs/SPEC.md`](../../docs/SPEC.md)
- **Referência:** [`conformance/reference.py`](../../conformance/reference.py)
- **Licença:** MIT
- **Status:** alpha, 20/20 vetores de conformidade passando (18 positivos + 2 negativos) + 3/3 goldens reais
- **Compat:** JVM 17+ (testado com kotlinc 2.1.0 sob OpenJDK 25)

## Antes de começar: instalar o Kotlin e um JDK

Para compilar e rodar código Kotlin você precisa de duas coisas:

- **JDK** (Java Development Kit): a máquina virtual Java e ferramentas. Kotlin
  compila para bytecode que roda na JVM. Instale a versão 17 ou mais nova pelo
  site oficial: <https://adoptium.net/>
- **Compilador Kotlin** (`kotlinc`): baixe o release oficial em
  <https://github.com/JetBrains/kotlin/releases> e extraia; o `kotlinc` fica em
  `kotlinc/bin/`. Ou instale via [SDKMAN!](https://sdkman.io/):
  `sdk install kotlin`.

Confira a instalação:

```bash
java --version
kotlinc -version
```

> **Nota sobre JDK 25.** O `kotlinc` 2.1.0 tem um bug ao **rodar sob** JDK 25
> (falha ao parsear a string de versão `25.0.x`). O `build.sh` deste port
> contorna isso automaticamente (compila com `-no-jdk` e injeta as classes do
> JDK no classpath, extraídas via `jimage`). Se você usa Gradle/Maven, prefira
> um JDK 17 ou 21 LTS como toolchain de build (veja "Build com Gradle/Maven").

## Coordenadas (Maven Central, placeholder)

Uma **dependência** é uma biblioteca de terceiros que o seu projeto usa; a
ferramenta de build a baixa por você. Placeholder até a publicação:

Gradle (Kotlin DSL):

```kotlin
dependencies {
    implementation("dev.petrus:tiss-hash-kotlin:0.1.0")
}
```

Maven:

```xml
<dependency>
  <groupId>dev.petrus</groupId>
  <artifactId>tiss-hash-kotlin</artifactId>
  <version>0.1.0</version>
</dependency>
```

## Uso

A API pública é um punhado de funções top-level no pacote
`dev.petrus.tisshash`:

```kotlin
import dev.petrus.tisshash.hashTiss
import dev.petrus.tisshash.hashTissFile
import dev.petrus.tisshash.InvalidTissXmlException
import java.nio.file.Files
import java.nio.file.Path

// A partir de bytes
val xml: ByteArray = Files.readAllBytes(Path.of("lote.xml"))
val md5: String = hashTiss(xml)
// resultado ilustrativo: "3aa0c578c95cdb861a125f480a8a4de5" (32 chars hex lowercase)

// Atalho de arquivo
val md5b: String = hashTissFile(Path.of("lote.xml"))

// Tratando entrada inválida
try {
    val h = hashTiss(bytesSuspeitos)
} catch (e: InvalidTissXmlException) {
    // XML malformado, múltiplos <ans:hash>, ou encoding UTF-16/UTF-32
}
```

Chamando a partir de **Java** (interop): as funções top-level viram métodos
estáticos da classe `dev.petrus.tisshash.TissHash`:

```java
String md5 = dev.petrus.tisshash.TissHash.hashTiss(xmlBytes);
```

## Decisões de stack

| Item | Escolha | Por quê |
|---|---|---|
| Parser XML | `javax.xml.parsers.DocumentBuilder` (DOM W3C) | Stdlib da JDK, zero dep runtime, namespace-aware, suporta preservar comentários (ambiguidade #2) |
| MD5 | `java.security.MessageDigest` | Stdlib, sem dep |
| API | Funções top-level + `@file:JvmName("TissHash")` | Idiomático em Kotlin e bom interop com Java (métodos estáticos) |
| Erro | `InvalidTissXmlException : RuntimeException` | Unchecked: falha rápido em XML inválido, preserva causa raiz |
| Build de referência | `build.sh` (kotlinc + java puros) | Self-contained; contorna o bug do kotlinc 2.1.0 sob JDK 25 |
| Build publicável | `build.gradle.kts` / `pom.xml` | Caminho para Maven Central; use JDK 17/21 como toolchain |
| API pública | `explicitApi` strict | Disciplina de lib: visibilidade e tipos explícitos na superfície |
| JVM mínima | 17 LTS | `Path.of`, cobertura ampla em enterprise BR |

Alternativas descartadas (mesmas do port Java): **StAX** (streaming exige
reconstruir a árvore e a noção de folha; sem ganho em XMLs TISS < 10 MB),
**JAXB** (removido do JDK 11+), **DOM4J/JDOM** (3rd party sem ganho).

## Segurança XML

A factory desabilita DOCTYPE (`disallow-doctype-decl`), entidades externas
(general + parameter), carga externa de DTD e XInclude. O entity resolver
retorna stream vazio (bloqueia I/O por SystemId). Entidades XML **predefinidas**
(`&amp; &lt; &gt; &quot; &apos;`) continuam sendo decodificadas, exigência do
algoritmo (ver [`AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md) #4).
DOCTYPE embutido é **rejeitado** (proteção XXE).

## Algoritmo (resumo)

1. Rejeita BOM UTF-16/UTF-32 (encodings fora de escopo do TISS).
2. Strip de BOM UTF-8 se presente.
3. Parse com `DocumentBuilder` seguro, namespace-aware, comentários preservados.
4. Zera o conteúdo do `<ans:hash>` (qualquer prefixo, casado pela **URI** do
   namespace TISS, não pelo prefixo literal). Documento sem `<ans:hash>` é
   válido; com múltiplos `<ans:hash>` é **rejeitado**.
5. Concatena o texto de cada **nó-folha** (Element ou Comment cujos filhos NÃO
   contêm Element/Comment/PI), em ordem de documento. Comentários XML **entram**
   no concat.
6. MD5 dos bytes **UTF-8** da string concatenada, não ISO-8859-1, apesar de o
   manual TISS dizer o contrário.
7. Hex lowercase, 32 caracteres.

Detalhes e ambiguidades fixadas:
[`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md).

## Build & test

### Caminho padrão deste port: `build.sh`

A partir da pasta do port (`langs/kotlin/`), com `kotlinc` e `java` no PATH:

```bash
cd langs/kotlin
./build.sh         # compila lib + harness e roda os 20 vetores + goldens reais
./build.sh jar     # idem + gera build/tiss-hash-kotlin-0.1.0.jar
./build.sh clean   # remove artefatos de build
```

O script é self-contained: detecta o `JAVA_HOME`, extrai as classes do JDK uma
vez (cache em `.libs/jdk-classes/`, fora do versionamento), baixa o `json.jar`
de teste se faltar, compila com `-Werror` e `-Xexplicit-api=strict`, e roda a
conformidade. Sai com código diferente de zero se algum teste falhar.

Cada **vetor** é um par "arquivo de entrada -> hash esperado": 18 positivos
(devem produzir um hash) e 2 negativos (devem ser rejeitados).

### Build com Gradle/Maven (caminho de publicação)

Os manifestos `build.gradle.kts` (+ `settings.gradle.kts`) e `pom.xml` estão
prontos para publicação em Maven Central. Hoje exigem um **JDK 17/21 LTS** como
toolchain de build (o `kotlinc`/Kotlin plugin 2.1.0 ainda não roda sob JDK 25).
Quando o toolchain suportar JDK 25 nativamente, o Gradle vira o caminho padrão.

```bash
# com Gradle instalado e um JDK 17/21 ativo
gradle build
gradle conformance   # task que roda o harness dos 20 vetores + goldens
```

## Conformidade

Roda os 20 vetores sintéticos (18 positivos + 2 negativos) em
`conformance/vectors.json`. Bate byte-a-byte com a referência Python e com os
demais ports (Python, Rust, Node, PHP, C, C++, Java, Go, C#). A lista canônica
vive em `conformance/vectors.json`.

```
== Vetores de conformidade (conformance/vectors.json) ==
  PASS  syn_minimal.xml
  PASS  syn_acento.xml
  PASS  syn_empty.xml
  PASS  syn_crlf_value.xml
  PASS  syn_multi_guia.xml
  PASS  syn_entidades_xml.xml
  PASS  syn_cdata.xml
  PASS  syn_comentario.xml
  PASS  syn_atributo_folha.xml
  PASS  syn_namespace_xsi.xml
  PASS  syn_whitespace_puro.xml
  PASS  syn_leading_zero.xml
  PASS  syn_iso8859_simbolos.xml
  PASS  syn_default_ns.xml
  PASS  syn_sem_hash.xml
  PASS  syn_entidade_numerica.xml
  PASS  syn_perf_grande.xml
  PASS  syn_bom_utf8.xml
  PASS  syn_multi_hash.xml (negativo: deve rejeitar)
  PASS  syn_utf16.xml (negativo: deve rejeitar)
  -> 20/20 PASS (18 positivos + 2 negativos)
```

Além dos sintéticos, o harness valida **goldens reais** (XMLs de produção que
vivem fora do repositório, por privacidade/LGPD). Essa validação é **cega**:
imprime apenas `PASS`/`FAIL` e um índice anônimo, nunca o hash, o nome do
arquivo de operadora, nem qualquer conteúdo do XML. Aponte o diretório via a
variável de ambiente `TISS_PRIVATE_XMLS` (se ausente, os goldens são pulados
sem falhar).

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
