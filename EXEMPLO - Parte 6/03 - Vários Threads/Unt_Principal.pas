unit Unt_Principal;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  Vcl.ExtDlgs,
  Vcl.CheckLst;

type

  /// <summary>
  /// Simula a efetiva importa��o dos dados
  /// </summary>
  TThreadImportacao = class(TThread)
  private
    FAfinidade       : Integer;
    FNomeArquivo     : string;
    FTempoSegundos   : NativeUInt;
    FQuantidadeLinhas: NativeUInt;
  public
    /// <summary>
    /// Recebe o nome do arquivo alvo
    /// </summary>
    constructor Create(const ANomeArquivo: string); reintroduce;
    /// <summary>
    /// Define corretamente a m�scara de afinidade
    /// </summary>
    procedure DefinirAfinidade(ANumCPU: Byte);
    /// <summary>
    /// Rotina a ser executado pelo thread
    /// </summary>
    procedure Execute; override;
    /// <summary>
    /// Tempo total de execu��o
    /// </summary>
    property TempoSegundos: NativeUInt read FTempoSegundos;
    /// <summary>
    /// Quantidade de linhas processadas
    /// </summary>
    property QuantidadeLinhas: NativeUInt read FQuantidadeLinhas write FQuantidadeLinhas;
  end;

  /// <summary>
  /// Thread de gerenciamento das m�ltiplas threads
  /// </summary>
  TThreadGerente = class(TThread)
  private
    FNomeArquivo     : string;
    FTempoSegundos   : NativeUInt;
    FQuantidadeLinhas: NativeUInt;
    FThreads         : array of TThreadImportacao;
    /// <summary>
    /// Divide o arquivo em partes e os distribui aos threads
    /// </summary>
    procedure DividirArquivo;
  protected
    /// <summary>
    /// Utilizado para terminar os threads de importa��o
    /// </summary>
    procedure TerminatedSet; override;
  public
    /// <summary>
    /// Recebe o nome do arquivo alvo
    /// </summary>
    constructor Create(const ANomeArquivo: string); reintroduce;
    /// <summary>
    /// Rotina a ser executado pelo thread
    /// </summary>
    procedure Execute; override;
    /// <summary>
    /// Tempo total de execu��o
    /// </summary>
    property TempoSegundos: NativeUInt read FTempoSegundos;
    /// <summary>
    /// Quantidade de linhas processadas
    /// </summary>
    property QuantidadeLinhas: NativeUInt read FQuantidadeLinhas write FQuantidadeLinhas;
  end;

  TfImportacao = class(TForm)
    Button1: TButton;
    OpenTextFileDialog1: TOpenTextFileDialog;
    lTempo: TLabel;
    ComboBox1: TComboBox;
    Label1: TLabel;
    Button2: TButton;
    lQuantidade: TLabel;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    FThreadUnica  : TThreadImportacao;
    FThreadGerente: TThreadGerente;
    procedure QuandoTerminarThread(Sender: TObject);
  public
    { Public declarations }
  end;

var
  fImportacao: TfImportacao;

implementation

uses
  System.StrUtils,
  System.Diagnostics,
  System.TypInfo;

{$R *.dfm}
{ TThreadImportacao }

constructor TThreadImportacao.Create(const ANomeArquivo: string);
begin
  inherited Create(True);
  Self.FNomeArquivo := ANomeArquivo;
end;

procedure TThreadImportacao.DefinirAfinidade(ANumCPU: Byte);
var
  sBits   : string;
  i       : Integer;
  iTamanho: Integer;
begin
  sBits := '00000000';
  sBits[ANumCPU] := '1';
  sBits := ReverseString(sBits);
  iTamanho := Length(sBits);

  for i := iTamanho downto 1 do
  begin
    if (sBits[i] = '1') then
      Self.FAfinidade := Self.FAfinidade + (1 shl (iTamanho - i));
  end;
end;

procedure TThreadImportacao.Execute;
const
  C_INSTRUCAO_SQL = 'INSERT INTO tbcliente (NOME_CLIENTE, CNPJ, ENDERECO, TELEFONE_1, TELEFONE_2, EMAIL) VALUES ("%s", "%s", "%s", "%s", "%s", "%s");';
var
  _csv         : TextFile;
  sLinha       : string;
  slAuxiliar   : TStringList;
  sInstrucaoSQL: string;
  rTempo       : TStopwatch;
  i            : Integer;
begin
  inherited;
  rTempo := TStopwatch.StartNew;

  // Define a m�scara de afinidade, se diferente de zeroS
  SetThreadAffinityMask(Self.Handle, Self.FAfinidade);

  // Instancia o StringList
  slAuxiliar := TStringList.Create;

  // Associa o maniopulador ao arquivo alvo
  AssignFile(_csv, Self.FNomeArquivo);
  try
    // Abre o arquivo para leitura
    Reset(_csv);

    // Enquanto n�o for o fim do arquivo ...
    while not Eof(_csv) do
    begin
      // Incrementa a quantidade de linhas processadas
      Inc(Self.FQuantidadeLinhas);

      // Se o thread foi sinalizado para terminar,
      // interrompe o ciclo
      if Self.Terminated then
      begin
        Break;
      end;

      // L� a pr�xima linha
      Readln(_csv, sLinha);

      // Quebra os campos CSV
      slAuxiliar.CommaText := sLinha;

      // Monta a instru��o SQL
      sInstrucaoSQL := Format(C_INSTRUCAO_SQL, [slAuxiliar[0], slAuxiliar[1], slAuxiliar[2], slAuxiliar[3], slAuxiliar[4], slAuxiliar[5]]);

      //
      // PONTO EM QUE O BANCO DE DADOS SERIA ACIONADO!
      // ESTAMOS FAZENDO UM PROCESSAMENTO FAKE
      //
      for i := 0 to Length(sLinha) do
      begin
        SendMessage(0, 0, 0, 0)
      end;
    end;
  finally
    rTempo.Stop;
    Self.FTempoSegundos := rTempo.ElapsedMilliseconds div 1000;
    slAuxiliar.Free;
    CloseFile(_csv);
  end;
end;

procedure TfImportacao.Button1Click(Sender: TObject);
var
  sNomeArquivo: string;
  iPrioridade : Integer;
  bRet        : Boolean;
begin
  // Abre a caixa de di�logo para selecionar o arquivo
  Self.OpenTextFileDialog1.Title := 'Selecionar arquivo ...';
  Self.OpenTextFileDialog1.Filter := 'Arquivo CSV|*.csv';
  bRet := Self.OpenTextFileDialog1.Execute(Self.Handle);

  // Se o usu�rio confirmou ...
  if (bRet) then
  begin
    // Desabilita os bot�es
    Self.Button1.Enabled := False;
    Self.Button2.Enabled := False;
    Self.ComboBox1.Enabled := False;

    // Determina o nome do arquivo
    sNomeArquivo := Self.OpenTextFileDialog1.FileName;

    // Determina o Ord() da prioridade do thread
    iPrioridade := GetEnumValue(TypeInfo(TThreadPriority), Self.ComboBox1.Text);

    // Configura e inicializa o thread
    Self.FThreadUnica := TThreadImportacao.Create(sNomeArquivo);
    Self.FThreadUnica.Priority := TThreadPriority(iPrioridade);
    Self.FThreadUnica.FreeOnTerminate := True;
    Self.FThreadUnica.OnTerminate := Self.QuandoTerminarThread;
    Self.FThreadUnica.Start;
  end;
end;

procedure TfImportacao.Button2Click(Sender: TObject);
var
  sNomeArquivo: string;
  iPrioridade : Integer;
  bRet        : Boolean;
begin
  // Abre a caixa de di�logo para selecionar o arquivo
  Self.OpenTextFileDialog1.Title := 'Selecionar arquivo ...';
  Self.OpenTextFileDialog1.Filter := 'Arquivo CSV|*.csv';
  bRet := Self.OpenTextFileDialog1.Execute(Self.Handle);

  // Se o usu�rio confirmou ...
  if (bRet) then
  begin
    // Desabilita os bot�es
    Self.Button1.Enabled := False;
    Self.Button2.Enabled := False;
    Self.ComboBox1.Enabled := False;

    // Determina o nome do arquivo
    sNomeArquivo := Self.OpenTextFileDialog1.FileName;

    // Configura e inicializa o thread
    Self.FThreadGerente := TThreadGerente.Create(sNomeArquivo);
    Self.FThreadGerente.FreeOnTerminate := True;
    Self.FThreadGerente.OnTerminate := Self.QuandoTerminarThread;
    Self.FThreadGerente.Start;
  end;
end;

procedure TfImportacao.FormClose(Sender: TObject; var Action: TCloseAction);
var
  oThread: TThread;
begin
  // Inicializa a variavel
  oThread := nil;

  // Se a thread �nica estiver sinalizada, assume
  if Assigned(Self.FThreadUnica) then
  begin
    oThread := Self.FThreadUnica;
  end;

  // Se a thread gerente estiver sinalizada, assume
  if Assigned(Self.FThreadGerente) then
  begin
    oThread := Self.FThreadGerente;
  end;

  // Se sinalizado ...
  if Assigned(oThread) then
  begin
    // "Desliga" o OnTerminate
    oThread.OnTerminate := nil;

    // "Desliga" o FreeOnTerminate
    oThread.FreeOnTerminate := False;

    // Indica o t�rmino
    oThread.Terminate;

    // Aguarda o t�rmino
    oThread.WaitFor;

    // Libera a inst�ncia
    oThread.Free;
  end;
end;

procedure TfImportacao.FormCreate(Sender: TObject);
begin
  ReportMemoryLeaksOnShutdown := True;
end;

procedure TfImportacao.QuandoTerminarThread(Sender: TObject);
const
  C_TEMPO = 'Tempo: [%s] - [%d]';
var
  sTexto : string;
  iLinhas: NativeUInt;
begin
  // Se for um thread de importa��o ...
  if Sender is TThreadImportacao then
  begin
    sTexto := Format(C_TEMPO, ['Um thread!', Self.FThreadUnica.TempoSegundos]);
    iLinhas := Self.FThreadUnica.QuantidadeLinhas;
    Self.FThreadUnica := nil;
  end;

  // Se for a thread gerenciadora ...
  if Sender is TThreadGerente then
  begin
    sTexto := Format(C_TEMPO, ['V�rios threads!', Self.FThreadGerente.TempoSegundos]);
    iLinhas := Self.FThreadGerente.QuantidadeLinhas;
    Self.FThreadGerente := nil;
  end;

  // Elementos de tela
  Self.lTempo.Caption := sTexto;
  Self.lQuantidade.Caption := FormatFloat('#,###,##0', iLinhas);
  Self.Button1.Enabled := True;
  Self.Button2.Enabled := True;
  Self.ComboBox1.Enabled := True;
end;

{ TThreadGerente }

constructor TThreadGerente.Create(const ANomeArquivo: string);
begin
  inherited Create(True);
  Self.FNomeArquivo := ANomeArquivo;
end;

procedure TThreadGerente.DividirArquivo;
const
  C_ASCII_10 = 10;
var
  _arq_entrada     : file;
  _arq_saida       : file;
  aBuffer          : array [1 .. MAXWORD] of Byte;
  iQuantProcessador: Byte;
  iTamEntrada      : NativeUInt;
  iTamPorArquivo   : NativeUInt;
  iNumProcessador  : NativeUInt;
  iTamBuffer       : NativeUInt;
  iTotalLido       : NativeUInt;
  sNomeArquivoSaida: string;
  iPosArray        : Byte;
begin
  // Associa o arquivo de entrada a um manipulador
  AssignFile(_arq_entrada, Self.FNomeArquivo);
  try
    // Vai para o in�cio do arquivo
    Reset(_arq_entrada, 1);

    // Quantidade de processadores
    iQuantProcessador := TThread.ProcessorCount;
    SetLength(Self.FThreads, iQuantProcessador);

    // Tamanho do arquivo em bytes
    iTamEntrada := FileSize(_arq_entrada);

    // Tamanho aproximando para cada arquivo
    iTamPorArquivo := iTamEntrada div iQuantProcessador;

    // Varre-se de tras p�ra frente para definir a afinidade do
    // �ltimo n�cleo ao primeiro
    for iNumProcessador := iQuantProcessador downto 1 do
    begin
      // Zera a quantidade lida
      iTotalLido := 0;

      // Nome do arquivo de sa�da
      sNomeArquivoSaida := Format('.\arquivo_%d.csv', [iNumProcessador]);

      // Associa o arquivo de sa�da a um manipulador
      AssignFile(_arq_saida, sNomeArquivoSaida);

      // Coloca o arquivo em modo de escrita
      Rewrite(_arq_saida, 1);
      try
        while True do
        begin
          // L� um bloco do arquivo de entrada
          BlockRead(_arq_entrada, aBuffer, MAXWORD, iTamBuffer);

          // Escreve este bloco no arquivo de sa�da
          BlockWrite(_arq_saida, aBuffer, iTamBuffer);

          // Finaliza se chegou ao fim do arquivo de entrada
          if Eof(_arq_entrada) then
          begin
            Exit;
          end;

          // Se estiver no �ltimo arquivo n�o precisa
          // mais verifica��es
          if (iNumProcessador = 1) then
          begin
            Continue;
          end;

          // Se j� atingiu o tamanho proposto ...
          Inc(iTotalLido, iTamBuffer);
          if (iTotalLido >= iTamPorArquivo) then
          begin
            // Se o �ltimo caracter n�o for #10 continua lendo
            // byte a byte para finalizar um arquivo �ntegro
            if (aBuffer[iTamBuffer] <> C_ASCII_10) then
            begin
              // L� o arquivo continuamente at� encontrar um #10
              repeat
                BlockRead(_arq_entrada, aBuffer, 1, iTamBuffer);
                BlockWrite(_arq_saida, aBuffer, iTamBuffer);
              until (aBuffer[1] = C_ASCII_10);
            end;

            // Finaliza o [while True do]
            Break;
          end;
        end;
      finally
        // Encerra o manipulador do arquivo de sa�da
        CloseFile(_arq_saida);

        // Determina a posi��o no array
        iPosArray := iNumProcessador - 1;
        // Cria um thread de importa��o passando o arquivo de sa�da
        Self.FThreads[iPosArray] := TThreadImportacao.Create(sNomeArquivoSaida);
        // Define a afinade com o n�cleo correspondente
        Self.FThreads[iPosArray].DefinirAfinidade(iNumProcessador);
        // Aumenta a prioridade do thread
        Self.FThreads[iPosArray].Priority := tpHigher;
        // Inicia o thread
        Self.FThreads[iPosArray].Start;
      end;
    end;
  finally
    // Encerra o manipulador do arquivo de entrada
    CloseFile(_arq_entrada);
  end;
end;

procedure TThreadGerente.Execute;
var
  aHandles: array [1 .. MAXBYTE] of THandle;
  _crono  : TStopwatch;
  i       : Integer;
  cRet    : Cardinal;
begin
  inherited;
  _crono := TStopwatch.StartNew;
  try
    // Define a m�scara de afinidade para o primeiro nucleo
    SetThreadAffinityMask(Self.Handle, 1);

    // Aumenta a prioridade do thread
    Self.Priority := tpHighest;

    // Divide o arquivo gigante em partes e inicia o thread
    // de importa��o correspondente
    Self.DividirArquivo;

    // Volta a prioridade normal
    Self.Priority := tpNormal;

    // Anota os manipuladores dos threads
    for i := 0 to High(Self.FThreads) do
    begin
      aHandles[Succ(i)] := Self.FThreads[i].Handle;
    end;

    // Aguarda o t�rminos dos threads de importa��o
    cRet := WaitForMultipleObjects(Length(Self.FThreads), @aHandles, True, INFINITE);

    // Determina a quantidade de linhas processadas
    for i := 0 to High(Self.FThreads) do
    begin
      Inc(Self.FQuantidadeLinhas, Self.FThreads[i].QuantidadeLinhas);
    end;

    // For�a a libera��o dos threads de importa��o
    Self.Terminate;
  finally
    _crono.Stop;
    Self.FTempoSegundos := _crono.ElapsedMilliseconds div 1000;
  end;

end;

procedure TThreadGerente.TerminatedSet;
var
  i: Integer;
begin
  inherited;
  // Varre o array de threads ...
  for i := 0 to High(Self.FThreads) do
  begin
    // Se estiver sinalizada ...
    if Assigned(Self.FThreads[i]) then
    begin
      // Se N�O estiver finalizada, indica o t�rmino
      if not(Self.FThreads[i].Finished) then
      begin
        Self.FThreads[i].Terminate;
        Self.FThreads[i].WaitFor;
      end;

      // Libera a inst�ncia
      Self.FThreads[i].Free;
    end;
  end;
end;

end.
