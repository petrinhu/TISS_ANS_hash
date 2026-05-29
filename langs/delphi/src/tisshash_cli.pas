{
  tisshash_cli - Demo de linha de comando do port Object Pascal.

  Uso:
    tisshash_cli <arquivo.xml> [<arquivo2.xml> ...]

  Imprime "<hash>  <arquivo>" por arquivo (igual reference.py). Em entrada
  invalida, imprime "ERRO: <causa>  <arquivo>" no stderr e segue para o
  proximo, terminando com exit code 1 se houve qualquer erro.

  Licenca: MIT.
}
program tisshash_cli;

{$ifdef FPC}
  {$mode delphi}{$H+}
{$endif}

uses
  SysUtils, TissHash;

var
  i: Integer;
  HadError: Boolean;
  HashHex, Path: string;

begin
  if ParamCount < 1 then
  begin
    Writeln(StdErr, 'uso: tisshash_cli <arquivo.xml> [...]');
    Halt(2);
  end;

  HadError := False;
  for i := 1 to ParamCount do
  begin
    Path := ParamStr(i);
    try
      HashHex := HashTissFile(Path);
      Writeln(HashHex, '  ', Path);
    except
      on E: EInvalidTissXml do
      begin
        Writeln(StdErr, 'ERRO: ', E.Message, '  ', Path);
        HadError := True;
      end;
      on E: Exception do
      begin
        Writeln(StdErr, 'ERRO[', E.ClassName, ']: ', E.Message, '  ', Path);
        HadError := True;
      end;
    end;
  end;

  if HadError then
    Halt(1);
end.
