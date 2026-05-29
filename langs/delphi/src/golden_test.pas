{
  golden_test - Validacao do port contra os 3 XMLs TISS REAIS (goldens).

  PRIVACIDADE (LGPD) - CRITICO:
    - Os XMLs reais e seus hashes NUNCA entram no repo.
    - Este programa imprime APENAS PASS/FAIL por arquivo. NUNCA imprime o hash
      calculado, o hash esperado, a versao TISS nem nome de operadora.
    - Le os goldens de um diretorio externo ao repo (env TISS_PRIVATE_XMLS ou
      o path default), junto de expected_hashes.json.

  Uso:
    golden_test [<dir_goldens>]
  Sem argumento: usa env TISS_PRIVATE_XMLS, senao o path default conhecido.

  Exit code:
    0  todos os goldens bateram
    1  ao menos um divergiu
    2  goldens nao encontrados (SKIP -> tratado como setup, exit 2)

  Licenca: MIT.
}
program golden_test;

{$ifdef FPC}
  {$mode delphi}{$H+}
{$endif}

uses
  SysUtils, Classes, fpjson, jsonparser, TissHash;

const
  DEFAULT_GOLDEN_DIR =
    '/home/petrus/IDrive/Documentos/projetos_claudebrain/Projects/_private_tiss_real_xmls';

function LoadFileBytes(const Path: string): TBytes;
var
  Stream: TFileStream;
  Size: Int64;
begin
  SetLength(Result, 0);
  Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    Size := Stream.Size;
    SetLength(Result, Size);
    if Size > 0 then
      Stream.ReadBuffer(Result[0], Size);
  finally
    Stream.Free;
  end;
end;

function LoadFileText(const Path: string): RawByteString;
var
  B: TBytes;
begin
  B := LoadFileBytes(Path);
  SetLength(Result, Length(B));
  if Length(B) > 0 then
    Move(B[0], Result[1], Length(B));
end;

var
  GoldenDir, ExpectedPath, FileName, ExpectedHash, GotHash, Name: string;
  Data: TJSONData;
  Obj: TJSONObject;
  i: Integer;
  Passed, Failed: Integer;
  Ok: Boolean;

begin
  GoldenDir := '';
  if ParamCount >= 1 then
    GoldenDir := ParamStr(1)
  else
    GoldenDir := GetEnvironmentVariable('TISS_PRIVATE_XMLS');
  if GoldenDir = '' then
    GoldenDir := DEFAULT_GOLDEN_DIR;
  GoldenDir := IncludeTrailingPathDelimiter(GoldenDir);

  ExpectedPath := GoldenDir + 'expected_hashes.json';

  if not FileExists(ExpectedPath) then
  begin
    Writeln('SKIP: goldens nao encontrados (sem expected_hashes.json em diretorio privado).');
    Writeln('      Defina TISS_PRIVATE_XMLS ou passe o diretorio como argumento.');
    Halt(2);
  end;

  Writeln('Goldens (privados, fora do repo): PASS/FAIL apenas.');
  Writeln('');

  Data := GetJSON(LoadFileText(ExpectedPath));
  try
    Obj := Data as TJSONObject;
    Passed := 0;
    Failed := 0;

    for i := 0 to Obj.Count - 1 do
    begin
      Name := Obj.Names[i];
      ExpectedHash := Obj.Items[i].AsString;
      FileName := GoldenDir + Name;

      if not FileExists(FileName) then
      begin
        Writeln(Format('FAIL  %s (arquivo ausente)', [Name]));
        Inc(Failed);
        Continue;
      end;

      Ok := False;
      try
        GotHash := HashTiss(LoadFileBytes(FileName));
        Ok := SameText(GotHash, ExpectedHash);
      except
        on E: Exception do
          Ok := False;
      end;

      if Ok then
      begin
        Writeln(Format('PASS  %s', [Name]));
        Inc(Passed);
      end
      else
      begin
        { NUNCA imprimir o hash calculado nem o esperado. }
        Writeln(Format('FAIL  %s', [Name]));
        Inc(Failed);
      end;
    end;

    Writeln('');
    Writeln(Format('Goldens: %d/%d PASS', [Passed, Passed + Failed]));

    if Failed = 0 then
      Halt(0)
    else
      Halt(1);
  finally
    Data.Free;
  end;
end.
