unit Unt_FuncaoLog;

interface

type

  /// <summary>
  /// Classe respons�vel pela gera��o de LOG
  /// </summary>
  TGeraLog = class
  private
  /// <summary>
  /// Indica o arquivo em que o LOG ser� gerado, no caso, no mesmo diret�rio do execut�vel
  /// </summary>
    const
    C_ARQUIVO = '.\arquivo_log.txt';
    /// <summary>
    /// Inst�ncia �nica do objeto
    /// </summary>
    class var FInstance: TGeraLog;
    /// <summary>
    /// M�todo respons�vel por instanciar o objeto singleton
    /// </summary>
    class function GetInstancia: TGeraLog; static;
  public
    /// <summary>
    /// Deleta o arquivo de LOG caso o mesma exista
    /// </summary>
    procedure AfterConstruction; override;
    /// <summary>
    /// M�todo que efetivamente gera o LOG
    /// </summary>
    /// <param name="AReferencia">Refer�ncia � thread chamadora</param>
    /// <param name="AData">Date e hora da gera��o do LOG</param>
    /// <param name="ATextoLog">Texto a ser escrito no arquivo de log</param>
    procedure GerarLog(const AReferencia: string; const AData: TDateTime; const ATextoLog: string);
    /// <summary>
    /// Refer�ncia � inst�ncia singleton
    /// </summary>
    class property Instancia: TGeraLog read GetInstancia;
  end;

implementation

uses
  System.SysUtils;

{ TGeraLog }

procedure TGeraLog.AfterConstruction;
begin
  inherited;
  DeleteFile(Self.C_ARQUIVO);
end;

procedure TGeraLog.GerarLog(const AReferencia: string; const AData: TDateTime; const ATextoLog: string);
var
  _arquivo  : TextFile;
  sNovaLinha: string;
begin
  sNovaLinha := Format('%s|%s|%s', [AReferencia, DateTimeToStr(AData), ATextoLog]);

  AssignFile(_arquivo, Self.C_ARQUIVO);
  if (FileExists(Self.C_ARQUIVO)) then
  begin
    Append(_arquivo);
  end else begin
    Rewrite(_arquivo);
  end;

  Writeln(_arquivo, sNovaLinha);

  CloseFile(_arquivo);
end;

class function TGeraLog.GetInstancia: TGeraLog;
begin
  if not(Assigned(FInstance)) then
  begin
    FInstance := TGeraLog.Create;
  end;
  Result := FInstance;
end;

initialization

finalization

TGeraLog.Instancia.Free;

end.
