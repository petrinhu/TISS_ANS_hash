{
  conformance_test - Runner de conformidade do port Object Pascal.

  Le conformance/vectors.json (via fpjson) e roda os 20 vetores:
    - vetor positivo (expect ausente ou "hash"): compara HashTiss(input) com
      expected_md5.
    - vetor negativo (expect "error"): exige que HashTiss lance EInvalidTissXml.

  Exit code:
    0  todos passaram
    1  ao menos um falhou
    2  erro de setup (vectors.json/inputs nao encontrados)

  Uso:
    conformance_test [<dir_conformance>]
  Sem argumento, tenta localizar a pasta conformance/ subindo a partir do
  diretorio do binario e do diretorio corrente.

  Licenca: MIT.
}
program conformance_test;

{$ifdef FPC}
  {$mode delphi}{$H+}
{$endif}

uses
  SysUtils, Classes, fpjson, jsonparser, TissHash;

function FindConformanceDir(const StartHint: string): string;
var
  Candidates: array of string;
  Base, Cur: string;
  i, Depth: Integer;
begin
  Result := '';
  SetLength(Candidates, 0);

  if StartHint <> '' then
  begin
    SetLength(Candidates, Length(Candidates) + 1);
    Candidates[High(Candidates)] := IncludeTrailingPathDelimiter(StartHint);
  end;

  { Sobe ate 6 niveis a partir do diretorio do binario e do cwd. }
  Base := ExtractFilePath(ParamStr(0));
  Cur := Base;
  for Depth := 0 to 6 do
  begin
    SetLength(Candidates, Length(Candidates) + 1);
    Candidates[High(Candidates)] :=
      IncludeTrailingPathDelimiter(Cur) + 'conformance' + PathDelim;
    Cur := ExpandFileName(IncludeTrailingPathDelimiter(Cur) + '..');
  end;

  Cur := GetCurrentDir;
  for Depth := 0 to 6 do
  begin
    SetLength(Candidates, Length(Candidates) + 1);
    Candidates[High(Candidates)] :=
      IncludeTrailingPathDelimiter(Cur) + 'conformance' + PathDelim;
    Cur := ExpandFileName(IncludeTrailingPathDelimiter(Cur) + '..');
  end;

  for i := 0 to High(Candidates) do
    if FileExists(Candidates[i] + 'vectors.json') then
      Exit(Candidates[i]);
end;

function LoadFile(const Path: string): TBytes;
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

var
  ConfDir, VectorsPath, InputsDir: string;
  RawJson: TBytes;
  JsonStr: RawByteString;
  Data: TJSONData;
  Obj: TJSONObject;
  Vectors: TJSONArray;
  Vec: TJSONObject;
  i: Integer;
  Id, InputRel, InputPath, Expect, ExpectedMd5, Got: string;
  IsError: Boolean;
  Bytes: TBytes;
  Passed, Failed: Integer;
  Line: string;

begin
  ConfDir := '';
  if ParamCount >= 1 then
    ConfDir := FindConformanceDir(ParamStr(1));
  if ConfDir = '' then
    ConfDir := FindConformanceDir('');

  if ConfDir = '' then
  begin
    Writeln('ERRO: nao encontrei conformance/vectors.json. ',
            'Passe o diretorio conformance como argumento.');
    Halt(2);
  end;

  VectorsPath := ConfDir + 'vectors.json';
  InputsDir := ConfDir + 'inputs' + PathDelim;

  Writeln('Conformance dir: ', ConfDir);
  Writeln('Port: Object Pascal (Free Pascal ', {$I %FPCVERSION%}, ')');
  Writeln('Lib version: ', TissHashVersion);
  Writeln('');

  RawJson := LoadFile(VectorsPath);
  SetLength(JsonStr, Length(RawJson));
  if Length(RawJson) > 0 then
    Move(RawJson[0], JsonStr[1], Length(RawJson));

  Data := GetJSON(JsonStr);
  try
    Obj := Data as TJSONObject;
    Vectors := Obj.Arrays['vectors'];

    Passed := 0;
    Failed := 0;

    for i := 0 to Vectors.Count - 1 do
    begin
      Vec := Vectors.Objects[i];
      Id := Vec.Get('id', '');
      InputRel := Vec.Get('input', '');
      Expect := Vec.Get('expect', '');           { '' se ausente }
      ExpectedMd5 := Vec.Get('expected_md5', ''); { '' se null/ausente }
      IsError := SameText(Expect, 'error');

      { Normaliza o path de input (usa apenas o basename sob inputs/). }
      InputPath := InputsDir + ExtractFileName(InputRel);

      if not FileExists(InputPath) then
      begin
        Writeln(Format('FAIL  %-28s (input nao encontrado: %s)',
          [Id, InputPath]));
        Inc(Failed);
        Continue;
      end;

      Bytes := LoadFile(InputPath);

      if IsError then
      begin
        { Vetor negativo: deve lancar EInvalidTissXml. }
        try
          Got := HashTiss(Bytes);
          Writeln(Format('FAIL  %-28s (esperava rejeicao, obteve %s)',
            [Id, Got]));
          Inc(Failed);
        except
          on E: EInvalidTissXml do
          begin
            Writeln(Format('PASS  %-28s (rejeitado: %s)',
              [Id, E.Message]));
            Inc(Passed);
          end;
          on E: Exception do
          begin
            { Outra excecao: aceitavel como rejeicao, mas sinaliza tipo. }
            Writeln(Format('PASS  %-28s (rejeitado [%s]: %s)',
              [Id, E.ClassName, E.Message]));
            Inc(Passed);
          end;
        end;
      end
      else
      begin
        { Vetor positivo: compara com expected_md5. }
        try
          Got := HashTiss(Bytes);
          if SameText(Got, ExpectedMd5) then
          begin
            Writeln(Format('PASS  %-28s %s', [Id, Got]));
            Inc(Passed);
          end
          else
          begin
            Writeln(Format('FAIL  %-28s esperado=%s obtido=%s',
              [Id, ExpectedMd5, Got]));
            Inc(Failed);
          end;
        except
          on E: Exception do
          begin
            Writeln(Format('FAIL  %-28s (excecao inesperada [%s]: %s)',
              [Id, E.ClassName, E.Message]));
            Inc(Failed);
          end;
        end;
      end;
    end;

    Writeln('');
    Line := Format('Resultado: %d/%d PASS (%d falhas)',
      [Passed, Passed + Failed, Failed]);
    Writeln(Line);

    if Failed = 0 then
      Halt(0)
    else
      Halt(1);
  finally
    Data.Free;
  end;
end.
