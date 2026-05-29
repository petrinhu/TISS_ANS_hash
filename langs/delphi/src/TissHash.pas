{
  TissHash - Port Object Pascal (Free Pascal / compat Delphi) do hash MD5 do
  epilogo TISS/ANS.

  ---------------------------------------------------------------------------
  Algoritmo (identico aos demais ports; referencia em conformance/reference.py)
  ---------------------------------------------------------------------------
    1. Parse do XML em DOM, com resolucao de namespace (namespace-aware).
    2. Localizar <ans:hash> pela URI "http://www.ans.gov.br/padroes/tiss/schemas"
       + local name "hash" (por URI, nunca pelo prefixo literal "ans:").
       - Mais de um <ans:hash> => documento nao conforme => EInvalidTissXml.
       - Nenhum <ans:hash> => documento VALIDO (concatena tudo).
    3. Zerar o conteudo do unico <ans:hash> (se existir).
    4. Concatenar o texto de cada NO-FOLHA, em ordem de documento:
       - folha = Element OU Comment sem filhos estruturados
         (Element/Comment/PI). TISS nao tem conteudo misto, entao um Element
         com so texto dentro e folha de valor.
       - Comentarios XML <!--...--> ENTRAM no concat (igual a referencia lxml,
         em que um Comment satisfaz len(el)==0). Ver AMBIGUITY_NOTES.md §9.
       - Atributos NAO entram; apenas o texto do no.
    5. MD5 dos bytes UTF-8 da string concatenada.
    6. hexdigest em 32 caracteres hex minusculos.

  ---------------------------------------------------------------------------
  ENCODING (ponto critico que discrimina certo/errado)
  ---------------------------------------------------------------------------
  O fcl-xml (DOM) DECODIFICA o documento conforme a declaracao (tipicamente
  iso-8859-1) e entrega os valores como DOMString (Unicode, UTF-16 internamente).
  Os bytes do MD5 sao os bytes UTF-8 dessa string Unicode -- NAO os bytes
  ISO-8859-1 originais do arquivo.

  Convertemos via UTF8Encode() (RTL FPC/Delphi), que produz UTF-8 correto.
  ATENCAO: nesta toolchain (FPC 3.2.3/Linux) NAO usar TEncoding.UTF8.GetBytes
  para esse passo -- naquele build ela nao reencoda o WideString corretamente
  (devolve os codepoints como bytes crus). UTF8Encode e o caminho confiavel e
  portavel (FPC e Delphi). Validado pelo vetor syn_acento.xml.

  ---------------------------------------------------------------------------
  Rejeicoes (escopo do Padrao TISS = ISO-8859-1 + UTF-8)
  ---------------------------------------------------------------------------
    - UTF-16 / UTF-32 detectados por BOM nos BYTES CRUS (antes do parse).
      Ordem: UTF-32 (FF FE 00 00 / 00 00 FE FF) antes de UTF-16 (FF FE / FE FF),
      pois o BOM UTF-32-LE tem o BOM UTF-16-LE como prefixo.
      BOM UTF-8 (EF BB BF) NAO e rejeitado (UTF-8 em escopo).
    - Mais de um <ans:hash>.
    - XML mal-formado (propagado do parser).

  API publica:
    function HashTiss(const Bytes: TBytes): string;
    function HashTissFile(const Path: string): string;
    EInvalidTissXml = class(Exception)

  Compat Delphi: o codigo usa modo delphi, TBytes, exceptions, UTF8Encode e
  o DOM do fcl-xml. Em Delphi VCL/FMX o DOM padrao difere (Xml.xmldom /
  Xml.XMLDoc); ver nota no README sobre como adaptar (MSXML/ADOM/OmniXML
  expoem NamespaceURI/localName equivalentes).

  Licenca: MIT.
}
unit TissHash;

{$ifdef FPC}
  {$mode delphi}{$H+}
{$endif}

interface

uses
  SysUtils, Classes, DOM;

type
  { Entrada fora do contrato do hash TISS (rejeitada antes/durante o calculo). }
  EInvalidTissXml = class(Exception);

{ Calcula o hash TISS a partir dos bytes crus de um documento XML.
  Retorna 32 caracteres hex minusculos. Lanca EInvalidTissXml para entrada
  fora de contrato (encoding fora de escopo, multiplos <ans:hash>, XML
  mal-formado). }
function HashTiss(const Bytes: TBytes): string;

{ Le um arquivo e calcula o hash TISS. Lanca EInvalidTissXml em entrada
  invalida; propaga EFOpenError/EReadError em falha de I/O. }
function HashTissFile(const Path: string): string;

{ Versao desta lib (string). }
function TissHashVersion: string;

const
  TISS_HASH_NAMESPACE = 'http://www.ans.gov.br/padroes/tiss/schemas';
  TISS_HASH_VERSION   = '0.1.0';

implementation

uses
  XMLRead, md5;

type
  { Buffer de UnicodeString com crescimento amortizado (dobramento de
    capacidade), pra concatenar o texto das folhas em O(n) total em vez do
    O(n^2) de concatenacao ingenua de string. Mantem o tipo Unicode honesto
    (sem passar por AnsiString/codepage), garantindo encoding correto em
    FPC e Delphi. }
  TUStrBuf = record
    Data: UnicodeString;
    Len: Integer;
  end;

procedure BufInit(out Buf: TUStrBuf);
begin
  Buf.Data := '';
  Buf.Len := 0;
  SetLength(Buf.Data, 4096);
end;

procedure BufAppend(var Buf: TUStrBuf; const S: UnicodeString);
var
  Need, Cap: Integer;
begin
  if Length(S) = 0 then
    Exit;
  Need := Buf.Len + Length(S);
  Cap := Length(Buf.Data);
  if Need > Cap then
  begin
    if Cap = 0 then
      Cap := 4096;
    while Cap < Need do
      Cap := Cap * 2;
    SetLength(Buf.Data, Cap);
  end;
  Move(S[1], Buf.Data[Buf.Len + 1], Length(S) * SizeOf(WideChar));
  Buf.Len := Need;
end;

function BufToString(const Buf: TUStrBuf): UnicodeString;
begin
  Result := Copy(Buf.Data, 1, Buf.Len);
end;

{ ------------------------------------------------------------------------- }
{ Deteccao de BOM fora de escopo (UTF-16 / UTF-32)                          }
{ ------------------------------------------------------------------------- }

{ Retorna True se os bytes crus comecam com um BOM UTF-16 ou UTF-32.
  UTF-32 e testado ANTES de UTF-16 porque o BOM UTF-32-LE (FF FE 00 00) tem
  o BOM UTF-16-LE (FF FE) como prefixo. }
function HasOutOfScopeBom(const Bytes: TBytes): Boolean;
var
  n: Integer;
begin
  Result := False;
  n := Length(Bytes);
  { UTF-32 LE: FF FE 00 00 ; UTF-32 BE: 00 00 FE FF }
  if n >= 4 then
  begin
    if (Bytes[0] = $FF) and (Bytes[1] = $FE) and
       (Bytes[2] = $00) and (Bytes[3] = $00) then
      Exit(True);
    if (Bytes[0] = $00) and (Bytes[1] = $00) and
       (Bytes[2] = $FE) and (Bytes[3] = $FF) then
      Exit(True);
  end;
  { UTF-16 LE: FF FE ; UTF-16 BE: FE FF }
  if n >= 2 then
  begin
    if (Bytes[0] = $FF) and (Bytes[1] = $FE) then
      Exit(True);
    if (Bytes[0] = $FE) and (Bytes[1] = $FF) then
      Exit(True);
  end;
end;

{ ------------------------------------------------------------------------- }
{ Predicados de no                                                           }
{ ------------------------------------------------------------------------- }

{ Filho "estruturado" desclassifica o pai como folha:
  Element, Comment ou Processing Instruction. Text/CDATA NAO contam. }
function IsStructuredChild(Node: TDOMNode): Boolean;
begin
  Result := (Node.NodeType = ELEMENT_NODE) or
            (Node.NodeType = COMMENT_NODE) or
            (Node.NodeType = PROCESSING_INSTRUCTION_NODE);
end;

{ True se o no e folha-pro-hash: Element OU Comment sem filhos estruturados. }
function IsLeafForHash(Node: TDOMNode): Boolean;
var
  Child: TDOMNode;
begin
  if (Node.NodeType <> ELEMENT_NODE) and (Node.NodeType <> COMMENT_NODE) then
    Exit(False);
  Child := Node.FirstChild;
  while Child <> nil do
  begin
    if IsStructuredChild(Child) then
      Exit(False);
    Child := Child.NextSibling;
  end;
  Result := True;
end;

{ True se o Element e o <ans:hash> do namespace TISS, casado pela URI +
  local name (nunca pelo prefixo literal). }
function IsTissHashElement(Node: TDOMNode): Boolean;
begin
  Result := (Node.NodeType = ELEMENT_NODE) and
            (Node.LocalName = 'hash') and
            (Node.NamespaceURI = TISS_HASH_NAMESPACE);
end;

{ ------------------------------------------------------------------------- }
{ Busca / contagem de <ans:hash>                                            }
{ ------------------------------------------------------------------------- }

{ Conta todos os <ans:hash> TISS na sub-arvore (DFS pre-order). }
function CountTissHash(Node: TDOMNode): Integer;
var
  Child: TDOMNode;
begin
  Result := 0;
  if IsTissHashElement(Node) then
    Inc(Result);
  Child := Node.FirstChild;
  while Child <> nil do
  begin
    Result := Result + CountTissHash(Child);
    Child := Child.NextSibling;
  end;
end;

{ Acha o primeiro <ans:hash> TISS em ordem de documento (DFS pre-order). }
function FindFirstTissHash(Node: TDOMNode): TDOMNode;
var
  Child, Found: TDOMNode;
begin
  if IsTissHashElement(Node) then
    Exit(Node);
  Child := Node.FirstChild;
  while Child <> nil do
  begin
    Found := FindFirstTissHash(Child);
    if Found <> nil then
      Exit(Found);
    Child := Child.NextSibling;
  end;
  Result := nil;
end;

{ Remove todos os filhos de um no (usado pra "zerar" <ans:hash>). }
procedure ClearChildren(Node: TDOMNode);
var
  Child, NextChild: TDOMNode;
begin
  Child := Node.FirstChild;
  while Child <> nil do
  begin
    NextChild := Child.NextSibling;
    Node.RemoveChild(Child).Free;
    Child := NextChild;
  end;
end;

{ ------------------------------------------------------------------------- }
{ Walker: concatena o texto das folhas em ordem de documento                }
{ ------------------------------------------------------------------------- }

{ Texto de uma folha:
  - Element-folha: TextContent (concatena Text/CDATA filhos ja decodificados).
    Folha sem filhos => ''.
  - Comment-folha: NodeValue (o texto entre <!-- e -->).
  Retorna UnicodeString (DOMString convertido) pra manter o tipo honesto no
  buffer Unicode. }
function LeafText(Leaf: TDOMNode): UnicodeString;
begin
  if Leaf.NodeType = COMMENT_NODE then
    Result := Leaf.NodeValue
  else
    Result := Leaf.TextContent;
end;

{ Walker recursivo. Acumula em Builder (UTF-16) em ordem de documento.
  Pula explicitamente o no <ans:hash> (ja zerado): mantem a semantica
  "<ans:hash> contribui string vazia" e protege contra mudanca futura. }
procedure Walk(Node: TDOMNode; var Buf: TUStrBuf; HashNode: TDOMNode);
var
  Child: TDOMNode;
begin
  if (Node.NodeType <> ELEMENT_NODE) and (Node.NodeType <> COMMENT_NODE) then
    Exit;
  if IsLeafForHash(Node) then
  begin
    if Node = HashNode then
      Exit; { <ans:hash> contribui string vazia }
    BufAppend(Buf, LeafText(Node));
    Exit;
  end;
  Child := Node.FirstChild;
  while Child <> nil do
  begin
    Walk(Child, Buf, HashNode);
    Child := Child.NextSibling;
  end;
end;

{ ------------------------------------------------------------------------- }
{ MD5 (unit md5 da FPC) + concat -> UTF-8                                   }
{ ------------------------------------------------------------------------- }

{ Concatena as folhas, converte pra UTF-8 e devolve os bytes (RawByteString
  com bytes UTF-8 crus). }
function ConcatUtf8(Root: TDOMNode; HashNode: TDOMNode): RawByteString;
var
  Buf: TUStrBuf;
  Utf8: UTF8String;
begin
  BufInit(Buf);
  Walk(Root, Buf, HashNode);
  { UTF8Encode: UnicodeString -> UTF8String (bytes UTF-8 corretos).
    NAO usar TEncoding.UTF8 nesta toolchain (ver cabecalho da unit). }
  Utf8 := UTF8Encode(BufToString(Buf));
  SetLength(Result, Length(Utf8));
  if Length(Utf8) > 0 then
    Move(Utf8[1], Result[1], Length(Utf8));
end;

{ MD5 dos bytes UTF-8 -> 32 hex minusculos.
  MD5String(RawByteString) hasheia os BYTES CRUS da string (sem reencodar),
  exatamente os bytes UTF-8 que montamos. MD5Print devolve hex; aplicamos
  LowerCase por garantia de contrato (32 hex minusculos). }
function Md5HexOfBytes(const Data: RawByteString): string;
begin
  Result := LowerCase(MD5Print(MD5String(Data)));
end;

{ ------------------------------------------------------------------------- }
{ Parse                                                                      }
{ ------------------------------------------------------------------------- }

{ Faz o parse namespace-aware dos bytes. Em falha de parse, lanca
  EInvalidTissXml com a causa do parser preservada na mensagem. }
function ParseDoc(const Bytes: TBytes): TXMLDocument;
var
  Parser: TDOMParser;
  Stream: TMemoryStream;
  Source: TXMLInputSource;
begin
  Result := nil;
  Parser := TDOMParser.Create;
  try
    { Namespace-aware: sem isso NamespaceURI/LocalName vem vazios e nao
      conseguimos casar <ans:hash> pela URI. }
    Parser.Options.Namespaces := True;
    { Preservar whitespace: por padrao o fcl-xml descarta texto so-espacos
      (ignorable whitespace), o que apagaria o valor de <campo>   </campo>.
      A referencia preserva os espacos literais dentro de uma folha
      (vetor syn_whitespace_puro.xml). Whitespace ENTRE elementos vira filho
      Text de um no NAO-folha e nunca e concatenado (so concatenamos o texto
      de folhas), entao preservar e seguro. }
    Parser.Options.PreserveWhitespace := True;
    { Nao expandir/validar DTD externa: hardening minimo anti-XXE. O fcl-xml
      nao busca entidades externas por padrao; mantemos Validate desligado. }
    Parser.Options.Validate := False;

    Stream := TMemoryStream.Create;
    try
      if Length(Bytes) > 0 then
        Stream.WriteBuffer(Bytes[0], Length(Bytes));
      Stream.Position := 0;
      Source := TXMLInputSource.Create(Stream);
      try
        try
          Parser.Parse(Source, Result);
        except
          on E: Exception do
            raise EInvalidTissXml.Create('XML invalido ou mal-formado: ' +
              E.Message);
        end;
      finally
        Source.Free;
      end;
    finally
      Stream.Free;
    end;
  finally
    Parser.Free;
  end;

  if (Result = nil) or (Result.DocumentElement = nil) then
  begin
    if Result <> nil then
      Result.Free;
    raise EInvalidTissXml.Create('XML invalido: sem elemento raiz');
  end;
end;

{ ------------------------------------------------------------------------- }
{ API publica                                                                }
{ ------------------------------------------------------------------------- }

function HashTiss(const Bytes: TBytes): string;
var
  Doc: TXMLDocument;
  Root, HashNode: TDOMNode;
  Concat: RawByteString;
begin
  if Length(Bytes) = 0 then
    raise EInvalidTissXml.Create('entrada vazia');

  { Rejeicao de encoding fora de escopo (UTF-16/UTF-32 por BOM), ANTES do
    parse. O fcl-xml aceitaria UTF-16 silenciosamente; queremos fail-fast
    com causa raiz clara. }
  if HasOutOfScopeBom(Bytes) then
    raise EInvalidTissXml.Create(
      'encoding fora de escopo (UTF-16/UTF-32 por BOM); escopo: ISO-8859-1, UTF-8');

  Doc := ParseDoc(Bytes);
  try
    Root := Doc.DocumentElement;

    { 1) Rejeitar >1 <ans:hash> (TISS preve exatamente um; multiplos sao
         ambiguos: qual zerar?). Documento SEM <ans:hash> e VALIDO. }
    if CountTissHash(Root) > 1 then
      raise EInvalidTissXml.Create(
        'documento nao conforme: multiplos <ans:hash> (esperado no maximo 1)');

    { 2) Zerar o conteudo do unico <ans:hash> (se existir). }
    HashNode := FindFirstTissHash(Root);
    if HashNode <> nil then
      ClearChildren(HashNode);

    { 3-5) Walk + UTF-8 + MD5. }
    Concat := ConcatUtf8(Root, HashNode);
    Result := Md5HexOfBytes(Concat);
  finally
    Doc.Free;
  end;
end;

function HashTissFile(const Path: string): string;
var
  Stream: TFileStream;
  Bytes: TBytes;
  Size: Int64;
begin
  Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    Size := Stream.Size;
    SetLength(Bytes, Size);
    if Size > 0 then
      Stream.ReadBuffer(Bytes[0], Size);
  finally
    Stream.Free;
  end;
  Result := HashTiss(Bytes);
end;

function TissHashVersion: string;
begin
  Result := TISS_HASH_VERSION;
end;

end.
