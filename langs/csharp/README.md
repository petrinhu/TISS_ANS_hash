# TissHash (.NET)

Calcula a "impressão digital" do trecho final de um documento TISS/ANS. Antes
do código, os termos essenciais:

- **XML**: formato de arquivo de texto que organiza dados em etiquetas (tags)
  aninhadas, como caixas dentro de caixas. O Padrão TISS é o XML que operadoras
  de saúde e consultórios usam no Brasil para trocar dados de atendimento.
- **Hash**: sequência curta e fixa de caracteres calculada a partir de um
  texto, como uma impressão digital. Mude uma letra, o hash muda inteiro.
- **MD5**: a receita (algoritmo) que gera o hash; sempre 32 caracteres
  hexadecimais (`0-9` e `a-f`).
- **Epílogo**: a parte final do documento TISS, a etiqueta `<ans:hash>`, onde o
  hash precisa ser gravado.
- **Byte**: a menor unidade de dado do computador; um arquivo de texto é uma
  fila de bytes.

Em uma frase: você passa os bytes de um XML TISS e recebe os 32 caracteres do
hash. Este é o port C# / .NET ("port" = a mesma lib reescrita em outra
linguagem) da biblioteca **`tiss-hash`**. Para entender o problema que a lib
resolve, veja [`docs/USAGE.md`](../../docs/USAGE.md) (guia de uso) e
[`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) (conceitos e visão geral).

Bate **byte-a-byte** com a referência Python (`conformance/reference.py`)
nos **20 vetores** de conformidade (18 positivos + 2 negativos)
compartilhados em `conformance/vectors.json`.

- **Status:** alpha (20/20 vetores PASS: 18 positivos + 2 negativos)
- **TFM:** `net8.0` (LTS)
- **Licença:** MIT
- **Dependências runtime:** `System.Text.Encoding.CodePages` (provider
  oficial Microsoft, necessário para `iso-8859-1` em .NET Core+)

## Antes de começar: instalar o .NET SDK

Para compilar e rodar código C# você precisa do **.NET SDK** (Software
Development Kit: compilador + ferramentas de build + runtime). Ele traz o
comando `dotnet`, que também baixa as dependências.

- Baixe e instale pelo site oficial: <https://dotnet.microsoft.com/download>
  (escolha a versão 8.0 LTS ou mais nova). Há instalador para Windows, Linux e
  macOS.
- Confira a instalação:

```bash
dotnet --version
```

## Instalação

Uma **dependência** é uma biblioteca de terceiros que o seu código usa; o
`dotnet` a baixa por você.

> Pacote **não está publicado no NuGet** (o repositório oficial de pacotes
> .NET). Para usar localmente, adicione o projeto como referência (a partir da
> pasta que você baixou com `git clone`):
>
> ```bash
> dotnet add reference path/to/lib_hash_ans/langs/csharp/src/TissHash/TissHash.csproj
> ```

Quando publicado:

```bash
dotnet add package TissHash --version 0.1.0
```

## Uso

```csharp
using TissHashLib = TissHash.TissHash; // alias evita ambiguidade ns vs classe

// A partir de bytes
byte[] xml = File.ReadAllBytes("lote.xml");
string md5 = TissHashLib.HashTiss(xml);
Console.WriteLine(md5); // 32 hex lowercase

// Atalho a partir de path
string md5b = TissHashLib.HashTissFile("lote.xml");
```

Erros:

- `ArgumentNullException`: entrada nula.
- `TissHash.InvalidTissXmlException`: XML mal-formado, vazio ou rejeitado
  pelo parser (DTD proibida, encoding inválido, etc.). A causa original
  (`System.Xml.XmlException`) fica em `InnerException`.

## Algoritmo (resumo)

1. Parse do XML (encoding detectado do prólogo ou BOM).
2. Localizar o `<ans:hash>` (qualquer prefixo, namespace
   `http://www.ans.gov.br/padroes/tiss/schemas`) e tratar seu conteúdo como
   string vazia. Documento sem `<ans:hash>` é válido; com múltiplos
   `<ans:hash>` é **rejeitado** (`InvalidTissXmlException`).
3. Concatenar o `textContent` de cada **nó-folha** (`XElement` ou
   `XComment` cujos filhos NÃO contêm `XElement`/`XComment`/PI) em ordem
   de documento.
4. MD5 sobre os bytes **UTF-8** da string concatenada.
5. Hex lowercase, 32 caracteres.

Para detalhes completos e as 15 ambiguidades canônicas, ver:

- `docs/SPEC.md` na raiz do repositório
- `conformance/AMBIGUITY_NOTES.md`

## Decisões técnicas

- **Parser: `System.Xml.Linq.XDocument`**: LINQ to XML, stdlib, zero dep
  externa, preserva `XComment` como nodes filhos por padrão (essencial
  para a ambiguidade #2 da referência: comentários XML ENTRAM no concat).
- **Reader: `XmlReader.Create(Stream, settings)`** com
  `DtdProcessing.Prohibit` + `XmlResolver = null` (anti-XXE) e
  `IgnoreComments = false`, `IgnoreWhitespace = false`.
- **MD5: `System.Security.Cryptography.MD5.HashData`**: API stateless
  moderna (.NET 5+), evita alocação de instância.
- **Encoding ISO-8859-1:** registrado via
  `Encoding.RegisterProvider(CodePagesEncodingProvider.Instance)` no
  construtor estático (idempotente). Necessário porque .NET Core+ não
  embute code pages legacy por default. Encodings suportados: ISO-8859-1 e
  UTF-8; UTF-16/UTF-32 são rejeitados (fora de escopo).
- **Hash bytes = UTF-8** (não ISO-8859-1, apesar do manual TISS dizer o
  contrário; ver caveat na seção 4 do `SPEC.md`).

## Build e teste

Da pasta `langs/csharp/` (dentro do repositorio que voce baixou com
`git clone`):

```bash
dotnet restore           # baixa as dependencias
dotnet build -c Release  # compila a biblioteca
dotnet test              # roda os 20 vetores de conformidade
```

Esperado: **PASS** em 20 vetores de conformidade (18 positivos + 2
negativos rejeitados) mais os testes de API/erro auxiliares. Cada **vetor** é um
par "arquivo de entrada -> hash esperado": positivo deve produzir um hash,
negativo deve ser rejeitado (a lib precisa recusar o arquivo, em vez de inventar
um hash).

## Compatibilidade

- **.NET 8.0+** (LTS).
- Funciona em Windows, Linux, macOS (qualquer runtime .NET 8).
- Sem deps nativas; tudo via BCL + 1 pacote oficial Microsoft.

## Estrutura

```
langs/csharp/
├── TissHash.sln
├── LICENSE
├── README.md
├── .gitignore
├── src/TissHash/
│   ├── TissHash.csproj
│   ├── TissHash.cs                  # API pública (static class)
│   └── InvalidTissXmlException.cs
└── tests/TissHash.Tests/
    ├── TissHash.Tests.csproj
    └── ConformanceTests.cs
```

## Licença

MIT, ver `LICENSE`.

## Ver também

- [`docs/USAGE.md`](../../docs/USAGE.md): guia de uso, receitas e perguntas
  frequentes (comece por aqui se você quer só usar a lib).
- [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md): conceitos e visão geral.
- [`docs/SPEC.md`](../../docs/SPEC.md): especificação canônica do algoritmo.
- [`docs/PORTING_GUIDE.md`](../../docs/PORTING_GUIDE.md): guia para portar para
  outras linguagens.
- [`conformance/reference.py`](../../conformance/reference.py): implementação de
  referência (o "oráculo" que define a resposta certa).
