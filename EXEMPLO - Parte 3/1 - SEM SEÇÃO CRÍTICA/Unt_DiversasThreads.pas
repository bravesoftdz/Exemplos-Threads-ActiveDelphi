unit Unt_DiversasThreads;

interface

uses
  System.Classes,
  Unt_FuncaoLog;

type

  /// <summary>
  /// Thread que disputar� o recurso de gera��o de LOG
  /// </summary>
  TDiversaThread = class(TThread)
  private
    FReferencia   : string;
    FDescricaoErro: string;
  public
    /// <summary>
    /// Rotina a ser executada pelo thread que eventualmente
    /// gerar� uma linha no arquivo de LOG
    /// </summary>
    procedure Execute; override;
    /// <summary>
    /// Refer�ncia que ser� escrito no arquivo
    /// de LOG para sabermos de onde veio a linha
    /// </summary>
    property Referencia: string read FReferencia write FReferencia;
    /// <summary>
    /// Caso ocorra um erro durante a execu��o do thread
    /// o erro poder� ser consultado nesta propriedade
    /// </summary>
    property DescricaoErro: string read FDescricaoErro;
  end;

implementation

uses
  System.SysUtils;

{ TDiversaThread }

procedure TDiversaThread.Execute;
var
  bGerarLog: Boolean;
begin
  inherited;
  try
    // Loop enquanto o thread n�o for finalizado
    while not(Self.Terminated) do
    begin
      //Faz com que n�o haja um consumo elevado de CPU
      Sleep(10);

      //Sorteia um n�mero e verifica se o resto da divis�o por dois � zero
      bGerarLog := (Random(1000000) mod 2) = 0;

      if (bGerarLog) then
      begin
        //Invoca o m�todo de gera��o de LOG
        TGeraLog.Instancia.GerarLog(Self.FReferencia, Now, 'O rato roeu a roupa do Rei de Roma');
      end;
    end;
  except
    on E: EInOutError do
    begin
      Self.FDescricaoErro := Format('Erro de I/O #%d - %s', [E.ErrorCode, SysErrorMessage(E.ErrorCode)]);
    end;
    on E: Exception do
    begin
      Self.FDescricaoErro := Format('(%s) - %s', [E.ClassName, E.Message]);
    end;
  end;
end;

end.
