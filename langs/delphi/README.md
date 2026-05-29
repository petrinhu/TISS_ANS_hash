# tisshash (Object Pascal, Free Pascal / Delphi)

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
- **Byte**: a menor unidade de dado do computador; um arquivo de texto e uma
  fila de bytes.

Em uma frase: voce passa os bytes de um XML TISS e recebe os 32 caracteres do
hash. Este e o port **Object Pascal** ("port" = a mesma lib reescrita em outra
linguagem) da biblioteca `tiss-hash`, voltado ao ecossistema **Delphi / Free
Pascal**, muito comum em sistemas de faturamento medico no Brasil. Para
entender o problema que a lib resolve, veja [`docs/USAGE.md`](../../docs/USAGE.md)
(guia de uso) e [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) (conceitos).

Bate **byte-a-byte** com a implementacao de referencia Python
(`conformance/reference.py`) e com os outros ports (C, C++, Rust, Python, PHP,
Node.js, Java, C#, Go) nos 20 vetores publicos (18 positivos + 2 negativos).

## Status

- Alpha (v0.1.0).
- Suite de conformidade: **20/20 PASS** (18 positivos + 2 negativos: multi-hash
  e UTF-16 sao rejeitados).
- Goldens reais (3 XMLs TISS reais, fora do repo): **3/3 PASS**.
- Toolchain de build/teste nesta maquina: **Free Pascal (FPC) 3.2.3**.
- Codigo escrito em `{$mode delphi}` (compat Delphi); ver
  [nota de compatibilidade Delphi](#nota-de-compatibilidade-delphi).
- Licenca: MIT.

## Antes de comecar: instalar o Free Pascal (ou Lazarus)

**Free Pascal (FPC)** e o compilador usado aqui. **Lazarus** e a IDE que vem
com o FPC embutido (opcional, util no Windows).

- **Linux (Fedora/RHEL)**: `sudo dnf install fpc`
- **Linux (Debian/Ubuntu)**: `sudo apt install fpc`
- **Windows / macOS / outros**: baixe pelo site oficial
  <https://www.freepascal.org/download.html> ou instale o Lazarus
  (que ja traz o FPC) em <https://www.lazarus-ide.org/>.

Confira a instalacao:

```bash
fpc -iV   # mostra a versao (3.2+ recomendado)
```

As unidades usadas (**fcl-xml** para o DOM, **md5** para o hash, **fcl-json**
para ler o `vectors.json`) ja vem na instalacao padrao do FPC: nenhuma
biblioteca extra precisa ser baixada.

## Uso (API)

A API publica esta na unit `TissHash` (`src/TissHash.pas`):

```pascal
program exemplo;

{$mode delphi}{$H+}

uses
  SysUtils, Classes, TissHash;

var
  Bytes: TBytes;
  Stream: TFileStream;
  HashHex: string;
begin
  // A partir de um arquivo (caminho do disco):
  HashHex := HashTissFile('lote.xml');
  Writeln(HashHex);  // 32 chars hex minusculos

  // Ou a partir dos bytes crus, se voce ja tem o conteudo em memoria:
  Stream := TFileStream.Create('lote.xml', fmOpenRead);
  try
    SetLength(Bytes, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Bytes[0], Stream.Size);
  finally
    Stream.Free;
  end;
  HashHex := HashTiss(Bytes);
  Writeln(HashHex);
end.
```

### Tratamento de erro

Entrada fora do contrato (encoding fora de escopo, multiplos `<ans:hash>`, XML
mal-formado, entrada vazia) lanca a excecao tipada `EInvalidTissXml`:

```pascal
uses SysUtils, TissHash;

try
  HashHex := HashTiss(Bytes);
except
  on E: EInvalidTissXml do
    // XML mal-formado, encoding nao suportado, ou >1 <ans:hash>
    Writeln(ErrOutput, 'XML invalido: ', E.Message);
end;
```

`HashTissFile` ainda pode propagar `EFOpenError` / `EReadError` (falha de I/O)
da RTL: capture-as separadamente se precisar distinguir I/O de XML invalido.

### CLI de demonstracao

Ha um pequeno executavel de exemplo, `tisshash_cli`, que imprime
`<hash>  <arquivo>` por arquivo (formato igual ao `reference.py`):

```bash
./build/tisshash_cli lote1.xml lote2.xml
```

## Constantes / funcoes publicas

- `TISS_HASH_NAMESPACE` (const string): URI do namespace TISS, usada para
  identificar `<ans:hash>` independente de prefixo. Valor:
  `http://www.ans.gov.br/padroes/tiss/schemas`.
- `TissHashVersion: string`: versao desta implementacao.
- `HashTiss(const Bytes: TBytes): string`: hash a partir de bytes crus.
- `HashTissFile(const Path: string): string`: hash a partir de um arquivo.
- `EInvalidTissXml = class(Exception)`: erro de entrada fora de contrato.

## Build / Test

A partir desta pasta (`langs/delphi/`):

```bash
make            # compila lib + CLI + testes em build/
make test       # roda os 20 vetores de conformidade (exit != 0 se falhar)
make goldens    # roda os 3 goldens reais (PASS/FAIL apenas; privados)
make check      # test + goldens
make clean      # manda artefatos de build pra lixeira (gio trash)
```

Sem `make` (ex.: Windows sem GNU Make), compile direto com o `fpc`:

```bash
fpc -O2 -Mdelphi -Fusrc -FEbuild -FUbuild src/conformance_test.pas
fpc -O2 -Mdelphi -Fusrc -FEbuild -FUbuild src/golden_test.pas
fpc -O2 -Mdelphi -Fusrc -FEbuild -FUbuild src/tisshash_cli.pas
```

Os flags significam: `-O2` otimiza; `-Mdelphi` liga o modo de compatibilidade
Delphi; `-Fusrc` aponta o diretorio das units; `-FEbuild` / `-FUbuild` mandam
os binarios e units compiladas para `build/`.

Rodar a conformidade:

```bash
./build/conformance_test            # acha conformance/ subindo a arvore
./build/conformance_test ../../conformance   # ou aponte explicitamente
```

Cada **vetor** e um par "arquivo de entrada -> hash esperado": 18 positivos
(devem produzir um hash) e 2 negativos (devem ser rejeitados). O runner sai
com codigo `!= 0` se qualquer vetor falhar.

### Goldens (XMLs TISS reais)

Os 3 XMLs reais que validam o algoritmo **nunca entram no repositorio** (LGPD).
O `golden_test` os le de um diretorio externo e imprime **apenas PASS/FAIL**:
nunca o hash, a versao TISS ou o nome da operadora.

```bash
# usa o env TISS_PRIVATE_XMLS ou o path default conhecido:
./build/golden_test
# ou aponte o diretorio explicitamente:
./build/golden_test /caminho/para/xmls_reais
```

## Decisoes de implementacao

**Parser XML**: `fcl-xml` (units `DOM` + `XMLRead`), o parser DOM padrao do
Free Pascal. Usamos `TDOMParser` com duas opcoes ligadas:

- `Options.Namespaces := True`, **obrigatorio**: sem isso o fcl-xml deixa
  `NamespaceURI` e `LocalName` vazios e nao da pra casar `<ans:hash>` pela URI
  (so pelo prefixo literal, o que e fragil). Com a opcao ligada, casamos por
  URI `http://www.ans.gov.br/padroes/tiss/schemas` + local name `hash`.
- `Options.PreserveWhitespace := True`, **obrigatorio**: por padrao o fcl-xml
  descarta texto so-de-espacos (ignorable whitespace), o que apagaria o valor
  de `<campo>   </campo>` (vetor `syn_whitespace_puro.xml`). Whitespace ENTRE
  elementos vira filho `Text` de um no NAO-folha e nunca e concatenado (so
  concatenamos texto de folhas), entao preservar e seguro.

**Comentarios**: o DOM do fcl-xml expoe `COMMENT_NODE`. Conforme a referencia
(em que um `Comment` do lxml satisfaz `len(el)==0`), comentarios XML
`<!--...-->` **entram** no concat. Ver `conformance/AMBIGUITY_NOTES.md` §9.

**MD5**: unit `md5` do FPC (`MD5String` + `MD5Print`). `MD5String` aplicado a
uma `RawByteString` hasheia os bytes crus, sem reencodar: exatamente os bytes
UTF-8 que montamos.

**Encoding (o ponto critico)**: o fcl-xml **decodifica** o documento conforme a
declaracao (tipicamente `iso-8859-1`) e entrega os valores como `DOMString`
(Unicode/UTF-16 interno). Os bytes do MD5 sao os bytes **UTF-8** dessa string
Unicode, **NAO** os bytes ISO-8859-1 originais. Convertemos com
`UTF8Encode()`. **Atencao**: nesta toolchain (FPC 3.2.3/Linux) NAO use
`TEncoding.UTF8.GetBytes` para esse passo: naquele build ela nao reencoda o
`WideString` corretamente (devolve os codepoints como bytes crus, produzindo
hash errado no vetor `syn_acento.xml`). `UTF8Encode` e o caminho confiavel e
portavel (FPC e Delphi).

**Buffer de concatenacao**: usamos um buffer `UnicodeString` proprio
(`TUStrBuf`) com crescimento por dobramento de capacidade, em vez de
`TStringBuilder`. Dois motivos: (1) no FPC em `{$H+}` o `TStringBuilder` e
baseado em `AnsiString`, o que introduziria conversao implicita de codepage
(fragil para o encoding); (2) o buffer Unicode mantem o tipo honesto e da
concatenacao O(n) total (importante para o vetor de performance, ~600 KB).

**Algoritmo** (identico aos demais ports):

1. Rejeita BOM UTF-16/UTF-32 nos bytes crus, antes do parse (UTF-32 testado
   antes de UTF-16: o BOM UTF-32-LE `FF FE 00 00` tem o UTF-16-LE `FF FE` como
   prefixo). BOM UTF-8 e aceito (UTF-8 em escopo).
2. Parse DOM namespace-aware.
3. Conta `<ans:hash>` (URI TISS): `>1` lanca `EInvalidTissXml`. Documento SEM
   `<ans:hash>` e valido. Zera o conteudo do unico `<ans:hash>` se existir.
4. Caminha a arvore em ordem de documento; para cada folha (Element OU Comment
   sem filhos Element/Comment/PI) acumula o texto. `<ans:hash>` contribui
   string vazia.
5. MD5 dos bytes UTF-8 do concat. Hex minusculo, 32 chars.

Ver `src/TissHash.pas` para detalhes e justificativas.

## Nota de compatibilidade Delphi

O codigo-fonte e escrito em `{$mode delphi}` e usa apenas construcoes
disponiveis tambem no Delphi: `TBytes`, excecoes, `UTF8Encode`, `TFileStream`,
e a API DOM (`TDOMNode`, `NamespaceURI`, `LocalName`, `TextContent`,
`NodeValue`, `FirstChild`/`NextSibling`/`RemoveChild`).

A diferenca pratica esta no **parser DOM**:

- **Free Pascal**: usa o `fcl-xml` (units `DOM` + `XMLRead`), como neste
  repositorio: funciona out-of-the-box.
- **Delphi (VCL/FMX)**: o DOM padrao e o `Xml.xmldom` / `Xml.XMLDoc` (sobre
  MSXML no Windows, ou ADOM/OmniXML como vendors alternativos). Esses
  fornecedores expoem os mesmos conceitos (`namespaceURI`, `localName`,
  `text`/`nodeValue`, navegacao por filhos), entao a logica de
  `src/TissHash.pas` se traduz quase 1:1: basta trocar `uses DOM, XMLRead`
  pelas units do fornecedor escolhido e ligar o processamento de namespace e a
  preservacao de whitespace equivalentes. A regra critica de encoding
  (`UTF8Encode` da string Unicode antes do MD5) e identica em Delphi.

O **build e os testes desta maquina rodam em FPC 3.2.3** (o Delphi e
proprietario / Windows); a paridade byte-a-byte e garantida pelos 20 vetores +
3 goldens.

## Garantias

- Algoritmo idempotente, sem estado global mutavel (a inicializacao do parser
  e por chamada via `TDOMParser` local).
- Erros tipados via `EInvalidTissXml`; a mensagem preserva a causa do parser.
  Validacao em borda: encoding fora de escopo e rejeitado antes do parse
  (melhor falhar do que produzir hash errado).
- Sem rede; I/O apenas leitura local opcional (`HashTissFile`).
- `TDOMParser` com `Validate := False` (sem busca de DTD/entidade externa).

## Referencia canonica

- Guia de uso (comece por aqui): [`docs/USAGE.md`](../../docs/USAGE.md)
- Conceitos e visao geral: [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md)
- Spec: [`docs/SPEC.md`](../../docs/SPEC.md)
- Algoritmo de referencia (o "oraculo" que define a resposta certa):
  [`conformance/reference.py`](../../conformance/reference.py)
- Vetores: [`conformance/vectors.json`](../../conformance/vectors.json)
- Ambiguidades fixadas: [`conformance/AMBIGUITY_NOTES.md`](../../conformance/AMBIGUITY_NOTES.md)
- Como portar para outra linguagem: [`docs/PORTING_GUIDE.md`](../../docs/PORTING_GUIDE.md)

## Dependencias e licencas

Todas as unidades usadas vem na instalacao padrao do Free Pascal (parte da RTL
/ Free Component Library). Nenhuma dependencia externa de terceiros:

| Unidade | Pacote FPC | Licenca | Uso |
|---|---|---|---|
| `DOM`, `XMLRead` | fcl-xml | LGPL-2.1 with linking exception | parse XML em DOM namespace-aware |
| `md5` | rtl (hash) | LGPL-2.1 with linking exception | calculo do MD5 |
| `fpjson`, `jsonparser` | fcl-json | LGPL-2.1 with linking exception | ler `vectors.json`/`expected_hashes.json` nos testes |

A "linking exception" da FPC RTL/FCL permite uso e distribuicao em software
proprietario sem obrigar abertura do codigo do aplicativo. Este port em si e
licenciado sob **MIT** (ver `LICENSE`).
