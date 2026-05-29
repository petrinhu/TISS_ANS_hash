# tiss_hash (Dart)

Calcula a "impressao digital" do trecho final de um documento TISS/ANS. Antes
do codigo, os termos essenciais:

- **XML**: formato de arquivo de texto que organiza dados em etiquetas (tags)
  aninhadas, como caixas dentro de caixas. O Padrao TISS e o XML que operadoras
  de saude e consultorios usam no Brasil para trocar dados de atendimento
  (regulamentado pela Agencia Nacional de Saude Suplementar, a ANS).
- **Hash**: sequencia curta e fixa de caracteres calculada a partir de um
  texto, como uma impressao digital. Mude uma letra, o hash muda inteiro.
- **MD5**: a receita (algoritmo) que gera o hash; sempre 32 caracteres
  hexadecimais (`0-9` e `a-f`).
- **Epilogo**: a parte final do documento TISS, a etiqueta `<ans:hash>`, onde o
  hash precisa ser gravado.
- **Byte**: a menor unidade de dado do computador; um arquivo de texto e uma
  fila de bytes.

Em uma frase: voce passa os bytes de um XML TISS e recebe os 32 caracteres do
hash. Este e o port Dart ("port" = a mesma lib reescrita em outra linguagem) da
biblioteca [`lib_hash_ans`](https://github.com/petrinhu/TISS_ANS_hash). Outras
linguagens (Python, Rust, Node.js, C, C++, PHP, Java, Go, C#) seguem o mesmo
contrato e os mesmos vetores de conformidade. Para entender o problema que a lib
resolve, veja [`docs/USAGE.md`](../../docs/USAGE.md) (guia de uso) e
[`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) (conceitos e visao geral).

- **Status:** alpha. 20/20 vetores sinteticos PASS (18 positivos + 2 negativos)
  em `conformance/vectors.json`.
- **Licenca:** MIT.
- **SDK:** Dart `^3.4` (testado em 3.12).
- **Dependencias runtime:** [`xml`](https://pub.dev/packages/xml) (parser) e
  [`crypto`](https://pub.dev/packages/crypto) (MD5).

## Antes de comecar: instalar o Dart

Dart e a linguagem e o ambiente que executa este codigo. O comando `dart` ja vem
com o `pub`, o gerenciador que baixa e instala bibliotecas (dependencias).

- Baixe e instale pelo site oficial: <https://dart.dev/get-dart> (Dart 3.4 ou
  mais novo). O SDK do Flutter tambem inclui o Dart.
- Confira a instalacao:

```bash
dart --version
```

## Instalacao

Uma **dependencia** e uma biblioteca de terceiros que o seu codigo usa; o `pub`
a baixa e instala. Para adicionar esta lib ao seu projeto:

```bash
dart pub add tiss_hash
```

> A publicacao no [pub.dev](https://pub.dev) (o repositorio oficial de pacotes
> Dart) ainda nao foi feita. Por enquanto, aponte para o checkout do repositorio
> (a pasta que voce baixou com `git clone`) no seu `pubspec.yaml`:
>
> ```yaml
> dependencies:
>   tiss_hash:
>     path: /caminho/para/lib_hash_ans/langs/dart
> ```

## Quickstart

```dart
import 'dart:io';
import 'package:tiss_hash/tiss_hash.dart';

Future<void> main() async {
  // A partir de bytes (sincrono).
  final md5 = hashTiss(File('lote.xml').readAsBytesSync());
  print(md5); // ex.: 3aa0c578c95cdb861a125f480a8a4de5

  // A partir de um caminho de arquivo (assincrono).
  final md5b = await hashTissFile('lote.xml');
  print(md5b);
}
```

### Tratamento de erro

```dart
import 'package:tiss_hash/tiss_hash.dart';
import 'dart:convert';

void main() {
  try {
    hashTiss(utf8.encode('<nao-eh-xml'));
  } on InvalidTissXmlException catch (e) {
    print('XML rejeitado: ${e.message}');
  }
}
```

Ha um exemplo executavel em
[`example/tiss_hash_example.dart`](example/tiss_hash_example.dart):

```bash
dart run example/tiss_hash_example.dart lote.xml
```

## API

| Simbolo | Tipo | Descricao |
| --- | --- | --- |
| `hashTiss(bytes)` | `String Function(List<int>)` | Hash MD5 (hex, 32 chars minusculo) a partir dos bytes do XML. Sincrono. |
| `hashTissFile(path)` | `Future<String> Function(String)` | Atalho assincrono: le o arquivo e calcula o hash. |
| `InvalidTissXmlException` | `class implements Exception` | Lancada quando o XML e mal-formado, com encoding fora de escopo, ou com mais de um `<ans:hash>`. |
| `tissNamespace` | `String` | URI do namespace TISS: `http://www.ans.gov.br/padroes/tiss/schemas`. |

## Algoritmo

Resumo do que `hashTiss` faz:

1. Decodifica os bytes do XML respeitando a declaracao `encoding="..."`:
   - `iso-8859-1` (padrao TISS): mapeia cada byte para o codepoint Unicode
     correspondente (latin1) e reescreve a declaracao para `utf-8` antes de
     passar ao parser.
   - `utf-8`: usa direto. Strippa BOM UTF-8 se presente.
2. Normaliza fim-de-linha conforme a spec XML 1.0 (secao 2.11): `\r\n` e `\r`
   isolado viram `\n`.
3. Parseia o XML com [`xml`](https://pub.dev/packages/xml), preservando
   comentarios.
4. Localiza o `<ans:hash>` (por **namespace URI**, nao por prefixo) e zera seu
   conteudo. Documento sem `<ans:hash>` e valido; com mais de um e
   **rejeitado** (erro).
5. Caminha a arvore em ordem de documento (depth-first, pre-order). Para cada
   **no-folha**, isto e, `Element` ou `Comment` cujos filhos NAO contem
   `Element`/`Comment`/`ProcessingInstruction`, concatena o texto ao buffer.
   O `<ans:hash>` contribui `""`.
6. Calcula `MD5` sobre os bytes **UTF-8** da string concatenada.
7. Devolve o hex em minusculo (32 caracteres).

### Atencao: encoding do MD5 e UTF-8, nao ISO-8859-1

O manual TISS diz "O encoding a ser utilizado sera sempre o ISO-8859-1". **Essa
frase e ambigua** e foi historicamente mal interpretada. Refere-se ao encoding
do arquivo XML, **nao** dos bytes que alimentam o MD5.

Na pratica (validada contra goldens reais privados, fora do repo, alem dos
vetores sinteticos publicos), os valores extraidos do XML sao re-encodados em
**UTF-8** antes do MD5. Implementacoes que aplicam MD5 sobre bytes ISO-8859-1
produzem hash diferente e **errado**.

Spec completa:
[`docs/SPEC.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/docs/SPEC.md).
Catalogo das decisoes canonicas (CDATA, entidades, atributos, comentarios,
etc.):
[`conformance/AMBIGUITY_NOTES.md`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/AMBIGUITY_NOTES.md).

## Decisao de parser: `package:xml`

| Parser | Decisao | Motivo |
| --- | --- | --- |
| **`xml`** | escolhido | DOM puro, pure-Dart, sem deps nativas. Modela `XmlComment` como no proprio na arvore e os mantem em `descendants` por padrao, essencial pra reproduzir a ambiguidade #2 da referencia (comentarios XML ENTRAM no concat). API de namespace por URI (`name.namespaceUri`). |
| `xml` em modo SAX/eventos | descartado | Exigiria reconstruir manualmente a nocao de "arvore" e de "folha". Sem ganho real (XMLs TISS < 10 MB). |

> Nota de fim-de-linha: ao contrario do `lxml` (referencia) e do `@xmldom/xmldom`
> (port Node), o `package:xml` nao normaliza `\r\n`/`\r` para `\n` durante o
> parse. Este port faz essa normalizacao **antes** do parse para bater
> byte-a-byte com a referencia (ver vetor `syn_crlf_value.xml`).

## Conformidade

Esta lib passa os **20 vetores sinteticos** (18 positivos + 2 negativos) em
[`conformance/vectors.json`](https://github.com/petrinhu/TISS_ANS_hash/blob/main/conformance/vectors.json),
cobrindo:

- **18 positivos:** minimo, acentuacao (UTF-8 vs ISO-8859-1), campos vazios,
  CR/LF, multiplas guias, entidades XML, entidades numericas, CDATA,
  comentarios, atributos, namespaces variados, namespace default, sem
  `<ans:hash>` (valido), whitespace puro, zeros a esquerda, simbolos
  ISO-8859-1, performance (~600 KB), BOM UTF-8.
- **2 negativos** (esperam erro): `syn_multi_hash.xml` (multiplos `<ans:hash>`)
  e `syn_utf16.xml` (UTF-16 fora de escopo).

Cada **vetor** e um par "arquivo de entrada -> hash esperado": positivo deve
produzir um hash, negativo deve ser rejeitado (a lib precisa recusar o arquivo,
em vez de inventar um hash).

Rodar os testes localmente, a partir desta pasta:

```bash
dart pub get   # baixa as dependencias
dart test      # roda os 20 vetores de conformidade + asserts de API
```

A suite resolve o diretorio `conformance/` subindo a partir do CWD, entao ela
precisa rodar dentro do checkout completo do repo `lib_hash_ans`.

### Goldens reais (privado)

Alem dos vetores sinteticos publicos, o mantenedor valida o port contra XMLs
TISS **reais** que contem PII de pacientes. Esses arquivos vivem FORA do repo
(LGPD) e nunca sao commitados. A validacao roda via:

```bash
dart run tool/golden_check.dart [DIR_PRIVADO]
```

O script reporta apenas `PASS`/`FAIL` por arquivo: nunca imprime o hash, o
conteudo do XML, a versao TISS ou a operadora.

## Limitacoes conhecidas

- **Multiplos `<ans:hash>` no mesmo documento:** **rejeitado** (lanca
  `InvalidTissXmlException`). Cenario patologico, nao previsto pelo padrao TISS;
  falhar e mais seguro que adivinhar qual zerar.
- **Encodings suportados:** ISO-8859-1 e UTF-8. UTF-16/UTF-32 sao **rejeitados**
  (fora de escopo, detectados por BOM).
- **Bytes invalidos no encoding declarado:** lancam `InvalidTissXmlException`;
  a lib nao tenta recuperar.

## Dependencias e licencas

| Dependencia | Licenca | Uso |
| --- | --- | --- |
| [`xml`](https://pub.dev/packages/xml) | MIT | parser DOM (pure-Dart) |
| [`crypto`](https://pub.dev/packages/crypto) | BSD-3-Clause | MD5 |

Atribuicao consolidada de todos os ports em
[`THIRD_PARTY_LICENSES.md`](../../THIRD_PARTY_LICENSES.md) na raiz do repo.

## Licenca

[MIT](LICENSE) Copyright (c) 2026 Petrus Silva Costa

## Ver tambem

- [`docs/USAGE.md`](../../docs/USAGE.md): guia de uso, receitas e perguntas
  frequentes (comece por aqui se voce quer so usar a lib).
- [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md): conceitos e visao geral.
- [`docs/SPEC.md`](../../docs/SPEC.md): especificacao canonica do algoritmo.
- [`docs/PORTING_GUIDE.md`](../../docs/PORTING_GUIDE.md): guia para portar para
  outras linguagens.
- [`conformance/reference.py`](../../conformance/reference.py): implementacao de
  referencia (o "oraculo" que define a resposta certa).
