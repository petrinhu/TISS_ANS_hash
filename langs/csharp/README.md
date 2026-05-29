# TissHash (.NET)

Port C# / .NET da biblioteca **`tiss-hash`**: hash MD5 canônico do
`<ans:hash>` em XMLs do Padrão TISS/ANS (saúde suplementar brasileira).

Bate **byte-a-byte** com a referência Python (`conformance/reference.py`)
nos **20 vetores** de conformidade (18 positivos + 2 negativos)
compartilhados em `conformance/vectors.json`.

- **Status:** alpha (20/20 vetores PASS: 18 positivos + 2 negativos)
- **TFM:** `net8.0` (LTS)
- **Licença:** MIT
- **Dependências runtime:** `System.Text.Encoding.CodePages` (provider
  oficial Microsoft, necessário para `iso-8859-1` em .NET Core+)

## Instalação

> Pacote **não está publicado no NuGet**. Para usar localmente, adicione
> o projeto como referência:
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

Da raiz `langs/csharp/`:

```bash
dotnet restore
dotnet build -c Release
dotnet test
```

Esperado: **PASS** em 20 vetores de conformidade (18 positivos + 2
negativos rejeitados) mais os testes de API/erro auxiliares.

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
