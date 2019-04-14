{ ===============================================================================


  =============================================================================== }
Unit uFRMMain;

Interface

Uses
  Windows,
  Messages,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  StdCtrls,
  System.SysUtils,

  uClasses_Types,
  uClass_CNN,
  uClass_Imaging,
  uFunctions,

  ExtCtrls,
  TeEngine,
  TeeProcs,
  Chart,
  inifiles,
  Series, Menus, ComCtrls, VclTee.TeeGDIPlus;

Const
  c_PredictIMageCount = 100;
  c_accordance=3;

Type
  TInfoCMD = Procedure(iCMD: Integer; Var Data) Of Object;

  TLearnThread = Class(TThread)
  private
    opt: TOpt;
    probability_volume: TVolume;

    TrainReg: TTrainReg;

    iLearningSteps, k, iTrainingIDX: Integer;
    iChunkIDX: Integer;
    iImageBlock: Integer;
    TainingsDaten: TTrainData;
    i: Integer;

    Layer_Def: TList;
    Net: TNet;

    Options: TTrainerOpt;
    Trainer: TTrainer;

    Class_Imaging: TClass_Imaging;
    ResultArray: TMyArray;
    s: String;

    iRuns: Integer;
    iStatRuns: Integer; // beginnt nach jeder Ausgabe neu...
    CompletedRuns: Integer;

    StartTicks: int64;
    iStartTime: int64;
    TraineeStartTime: TDatetime;
    AVGRunsPerSec: Integer;
    iDisplayLayerIDX: Integer;

    LearningInfo: TLearningInfo;
  public

    InfoCMD: TInfoCMD;
    bDebug: Boolean;

    bMakePrediction: Boolean;

    sWeightsFilename: String;
    sResultsFilename: String;

    Constructor create;
    Procedure Init;
    Destructor Destroy; override;
    Procedure Execute; override;
    Procedure Learn;
    Procedure Sync;

    function LoadDefinition: Boolean;

    Procedure StoreResults(sFilename: String; iRun_Train: Integer;
      dLoss_Train: Single; dAcc_Train: Single; dAcc_Test: Single);
  End;

  { TFRMMain }

  TFRMMain = Class(TForm)
    Panel3: TPanel;
    lblRuns: TLabel;
    lblLoss: TLabel;
    Panel1: TPanel;
    imgDebug: TImage;
    btnStart: TButton;
    StatusBar: TStatusBar;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Load1: TMenuItem;
    Store1: TMenuItem;
    N1: TMenuItem;
    Close1: TMenuItem;
    cbDebug: TCheckBox;
    Panel2: TPanel;
    panButtons: TPanel;
    btnPrev: TButton;
    btnNext: TButton;
    btnTest: TButton;
    cbUseChunk: TCheckBox;
    cbShowWeights: TCheckBox;
    Chart1: TChart;
    ScrollBox1: TScrollBox;
    imgPrediction: TImage;
    Procedure btnStartClick(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    Procedure btnNextClick(Sender: TObject);
    Procedure FormCreate(Sender: TObject);
    Procedure cbDebugClick(Sender: TObject);
    Procedure btnPrevClick(Sender: TObject);
    Procedure Store1Click(Sender: TObject);
    Procedure Load1Click(Sender: TObject);
    Procedure FormResize(Sender: TObject);
    Procedure btnTestClick(Sender: TObject);
    procedure cbUseChunkClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private-Deklarationen }
  public

    LearnThread: TLearnThread;
    iDisplayLayerIDX: Integer;

    iPred: Integer;
    dLastPredicion: Single;

    // Chart
    lsLoss: TLineSeries;
    lsTrainAcc: TLineSeries;
    lsTestAcc: TLineSeries;

    Procedure BuildButtons(Net: TNet);
    Procedure btnLayerlick(Sender: TObject);
    Procedure AusgabeBilder(iLayerIDX: Integer; Net: TNet);
    Procedure InfoCMD(iCMD: Integer; Var Data);
    Procedure Prediction(bSilent: Boolean);

  End;

Var
  FRMMain: TFRMMain;

Implementation

{$R *.dfm}
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.AusgabeBilder(iLayerIDX: Integer; Net: TNet);
Var
  c_PicPerRow: Integer;
  s: TLayer;
  bmp: TBitmap;
  vol: TVolume;
  i, j, k, d, iRow, iwidth, x, y: Integer;
  Class_Imaging: TClass_Imaging;

  // die Bildposition berechnen
  Procedure NextXY;
  Begin
    x := x + iwidth + 5;
    If x + iwidth >= imgDebug.Width Then
    Begin
      x := 5;
      y := y + iwidth + 5
    End;
  End;

// die Bildposition berechnen
  Procedure NextLn;
  Begin
    x := 5;
    y := y + iwidth + 5
  End;

  Procedure Textout(s: String);
  Begin
    imgDebug.Canvas.Textout(x, y, s);

    x := 5;
    y := y + imgDebug.Canvas.TextHeight(s);
  End;

  Procedure TextoutMinMax(s: String; a: TMyArray);
  Var
    mm: TMinMax;
  Begin
    mm := Global.maxmin(a);
    imgDebug.Canvas.Textout(x, y, Format('%s  Max:%2.5f Min: %2.5f',
      [s, mm.maxv, mm.minv]));
    x := 5;
    y := y + imgDebug.Canvas.TextHeight(s);

  End;

Begin
  If Not imgDebug.Canvas.TryLock Then
    exit;

  x := 5;
  y := 5;

  // imgDebug.Canvas.Lock;

  // leere den Canvas
  imgDebug.Canvas.brush.color := clBlack;
  imgDebug.Canvas.Font.color := clWhite;
  imgDebug.Canvas.Rectangle(0, 0, imgDebug.Width, imgDebug.Height);

  s := Net.Layers[iLayerIDX];
  bmp := TBitmap.create;
  Try
    Class_Imaging := TClass_Imaging.create;
    iwidth := imgDebug.Width Div 10;

    TextoutMinMax('INPUT w ', TLayer(Net.Layers[0]).out_act.w);

    // DAS EINGANGABILD
    vol := TLayer(Net.Layers[0]).out_act;

    Class_Imaging.vol_to_bmp(vol, bmp, false);
    imgDebug.Canvas.StretchDraw(rect(x, y, x + iwidth, y + iwidth), bmp);
    NextLn;

    TextoutMinMax('INPUT dw ', TLayer(Net.Layers[0]).out_act.dw);
    Class_Imaging.vol_to_bmp(vol, bmp, true);
    imgDebug.Canvas.StretchDraw(rect(x, y, x + iwidth, y + iwidth), bmp);

    NextLn;

    Textout(s.layer_type + ' FWTime:' + inttostr(s.fwTime) + ' BWTime:' +
      inttostr(s.bwTime));

    iwidth := 32;

    If s Is TConvLayer Then
    Begin

      // iwidth := imgDebug.Width Div (TConvLayer(s).out_depth * TConvLayer(s).filters.Buffer[0].n Div 50);
      if cbShowWeights.Checked then
      begin

        Textout('FILTER Weights');
        // die Gewichte ausgeben
        For i := 0 To TConvLayer(s).out_depth - 1 Do
        Begin
          vol := TConvLayer(s).filters.Buffer[i];

          If iLayerIDX <= 2 Then
          Begin
            Class_Imaging.vol_to_bmpCol(vol, bmp, false);

            imgDebug.Canvas.StretchDraw(rect(x, y, x + iwidth,
              y + iwidth), bmp);

            NextXY;
          End
          Else
          Begin
            For j := 0 To vol.depth - 1 Do
            Begin
              Class_Imaging.vol_to_bmpSW(vol, bmp, false, j);

              imgDebug.Canvas.StretchDraw(rect(x, y, x + iwidth,
                y + iwidth), bmp);

              NextXY;

            End;

          End;

        End;

        NextLn;

        Textout('FILTER Grads');
        // die Gradienten ausgeben
        For i := 0 To TConvLayer(s).out_depth - 1 Do
        Begin
          vol := TConvLayer(s).filters.Buffer[i];
          If iLayerIDX <= 2 Then
          Begin
            Class_Imaging.vol_to_bmpCol(vol, bmp, true);

            imgDebug.Canvas.StretchDraw(rect(x, y, x + iwidth,
              y + iwidth), bmp);
            NextXY;
          End
          Else
          Begin
            For j := 0 To vol.depth - 1 Do
            Begin
              Class_Imaging.vol_to_bmpSW(vol, bmp, false, j);

              imgDebug.Canvas.StretchDraw(rect(x, y, x + iwidth,
                y + iwidth), bmp);

              NextXY;

            End;

          End;
        End;
      end;

    End;

    iwidth := 32;
    // AUSGANGS GEWICHTE
    NextLn;
    NextLn;
    vol := s.out_act;

    TextoutMinMax('Output w ', vol.w);

    For j := 0 To vol.depth Do
    Begin

      Class_Imaging.vol_to_bmpSW(vol, bmp, false, j);
      imgDebug.Canvas.StretchDraw(rect(x, y, x + iwidth, y + iwidth), bmp);
      NextXY;
    End;

    // AUSGANGS GRADIENTEN (NUR NICHT SOFTMAX)
    If Not(s Is TSoftMaxLayer) Then
    Begin
      NextLn;
      TextoutMinMax('Output dw ', vol.dw);
      For j := 0 To vol.depth Do
      Begin
        Class_Imaging.vol_to_bmpSW(vol, bmp, true, j);
        imgDebug.Canvas.StretchDraw(rect(x, y, x + iwidth, y + iwidth), bmp);
        NextXY;
      End;
    End;

    imgDebug.Refresh;
    imgDebug.Repaint;
  Finally
    bmp.Free;
    Class_Imaging.Free;
  End;

  imgDebug.Canvas.UnLock;
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.btnStartClick(Sender: TObject);
Begin
  If LearnThread.Suspended Then
  Begin
    // LearnThread.iRuns := 0;
    // LearnThread.StartTicks := GettickCount;
    LearnThread.Resume;

    btnStart.caption := 'Stopp';
  End
  Else
  Begin
    LearnThread.Suspend;
    btnStart.caption := 'Start'
  End;
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.BuildButtons(Net: TNet);
Var
  i: Integer;
  btn: TButton;
  s: String;
Begin
  For i := 0 To 100 Do
  Begin
    btn := TButton(panButtons.FindComponent('NETBTN' + inttostr(i)));
    If btn <> Nil Then
    Begin
      btn.Free;
    End;
  End;

  For i := 0 To Net.Layers.Count - 1 Do
  Begin
    s := inttostr(i) + '. ' + TLayer(Net.Layers[i]).sName + ': ' +
      inttostr(TLayer(Net.Layers[i]).out_sx) + 'x' +
      inttostr(TLayer(Net.Layers[i]).out_sy) + 'x' +
      inttostr(TLayer(Net.Layers[i]).out_depth);

    btn := TButton.create(panButtons);
    btn.Name := 'NETBTN' + inttostr(i);
    btn.Parent := panButtons;
    btn.caption := s;
    btn.Tag := i;
    btn.Width := panButtons.Width;
    btn.left := 0;
    btn.Top := i * btn.Height;
    btn.OnClick := btnLayerlick;
  End;
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.btnLayerlick(Sender: TObject);
Begin
  iDisplayLayerIDX := TButton(Sender).Tag;
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.btnNextClick(Sender: TObject);
Begin
  If iPred + c_PredictIMageCount <
    length(LearnThread.Class_Imaging._TestData) Then
    iPred := iPred + c_PredictIMageCount
  Else
    iPred := length(LearnThread.Class_Imaging._TestData) - c_PredictIMageCount;

  // Prediction;
  LearnThread.bMakePrediction := true;

  if LearnThread.Suspended then
    Prediction(false);
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.btnPrevClick(Sender: TObject);
Begin
  If iPred - c_PredictIMageCount >= 0 Then
    iPred := iPred - c_PredictIMageCount
  Else
    iPred := 0;
  // Prediction;
  LearnThread.bMakePrediction := true;

  if LearnThread.Suspended then
    Prediction(false);
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.cbDebugClick(Sender: TObject);
Begin
  LearnThread.bDebug := cbDebug.Checked;
End;

procedure TFRMMain.cbUseChunkClick(Sender: TObject);
begin
  LearnThread.Options.ChunkEnabled := cbUseChunk.Checked;
end;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.FormCreate(Sender: TObject);
Begin
  LearnThread := TLearnThread.create;
  LearnThread.InfoCMD := InfoCMD;
  LearnThread.Init;

  LearnThread.bDebug := true;

  lsLoss := TLineSeries.create(Nil);
  lsLoss.Clear;
  lsLoss.ParentChart := Chart1;
  lsLoss.Name := 'Loss';
  lsLoss.Identifier := 'Loss';
  lsLoss.color := clRed;
  // lsLoss.VertAxis := TVertAxis.aLeftAxis;

  lsTrainAcc := TLineSeries.create(Nil);
  lsTrainAcc.Clear;
  lsTrainAcc.ParentChart := Chart1;
  lsTrainAcc.Name := 'ACC';
  lsTrainAcc.Identifier := 'ACC';
  lsTrainAcc.color := clGreen;

  // lsTrainAcc.VertAxis := TVertAxis.aRightAxis; // aBothVertAxis;
  lsTestAcc := TLineSeries.create(Nil);
  lsTestAcc.Clear;
  lsTestAcc.ParentChart := Chart1;
  lsTestAcc.Name := 'Test_acc';
  lsTestAcc.Identifier := 'Test Acc';
  lsTestAcc.color := clBlue;

  iPred := 0;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.FormDestroy(Sender: TObject);
Begin
  // den THREAD NUR SO beenden!!!!!!!!!!!!!!
  LearnThread.Suspend;
  LearnThread.Net.Export;
  LearnThread.FreeOnTerminate := true;
  LearnThread.Terminate;

  lsTrainAcc.Free;
  lsLoss.Free;
  lsTestAcc.Free;

End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.InfoCMD(iCMD: Integer; Var Data);
Var
  i, k, ixPos, iyPOs: Integer;
  ResultVol: TVolume;
  iSec: Integer;
  TrainReg: TTrainReg;
  s: String;
  iPredict: Integer;
  iAnzGleicherSaetze: Integer;
  Predict: TPredict;
  PredictList: TList;
  bmp: TBitmap;
  TrainBmp: TBitmap;
  Class_Imaging: TClass_Imaging;
  iBMPWidth: Integer;
Begin
  Try

    Case iCMD Of
      - 1:
        Begin
          BuildButtons(TNet(Data));
          lblRuns.caption := 'Loading images';
          lblLoss.caption := '';
        End;
      0:
        Begin
          lblRuns.caption := 'Finished loading files ' + datetimetostr(now);
          lblLoss.caption := '';
        End;
      1:
        Begin
          TrainReg := TTrainReg(Data);

          If TrainReg.iRunStat <> 0 Then
          Begin
            lblLoss.caption :=
              Format('FWD-Time: %3.0f   BWD-Time: %3.0f    Loss: %2.3f     ' +
              'L2 Decay Loss: %2.4f   Train Acc: %2.4f    Test ACC: %2.2f%%',
              [TrainReg.fwd_time / 1000, TrainReg.bwd_time / 1000,
              TrainReg.SumCostLoss / TrainReg.iRunStat, TrainReg.Suml2decayloss
              / TrainReg.iRunStat, TrainReg.TrainingAccuracy /
              TrainReg.iRunStat, dLastPredicion * 100]);

            lsLoss.AddXY(TrainReg.iRuns, TrainReg.SumCostLoss /
              TrainReg.iRunStat);
            lsTrainAcc.AddXY(TrainReg.iRuns, TrainReg.TrainingAccuracy /
              TrainReg.iRunStat);

            LearnThread.StoreResults(LearnThread.sResultsFilename,
              TrainReg.iRuns, TrainReg.SumCostLoss / TrainReg.iRunStat,
              TrainReg.TrainingAccuracy / TrainReg.iRunStat, dLastPredicion);
          End;
        End;
      2:
        Begin
          AusgabeBilder(iDisplayLayerIDX, TNet(Data));
        End;
      3:
        Begin
          iSec := (GettickCount - LearnThread.StartTicks) Div 1000;
          If iSec > 0 Then
          Begin
            lblRuns.caption := 'RUNS:' + inttostr(LearnThread.iRuns) +
              '   Training:' + inttostr(LearnThread.iTrainingIDX) +
              '   CompletedRuns:' + inttostr(LearnThread.CompletedRuns) +
              '   Time: ' + Format('%2.2dT %2.2d:%2.2d:%2.2d',
              [(iSec Div (3600 * 24)), (iSec Div 3600) Mod 24,
              (iSec Div 60) Mod 60, iSec Mod 60]) + '   AVG-Time[runs/sec]:' +
              Format('%2.5d', [LearnThread.AVGRunsPerSec]);
          End;
        End;
      4:
        begin
          Prediction(false);
          LearnThread.bMakePrediction := false;
        end;
      5:
        Begin
          Prediction(true);
        End;

    End;
  except
  End;
End;

{ TLearnThread }

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Constructor TLearnThread.create;
Begin
  Inherited create(true);

  Priority := tpHighest;
  SetProcessAffinityMask(self.Handle, 2);

  FreeOnTerminate := false;
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TLearnThread.Init;
Var
  i: Integer;
  sDataPath: String;
  ActPic: TCifarImage;
Begin
  Try
    Layer_Def := TList.create;
    Net := TNet.create;
    Options := TTrainerOpt.create;

    iDisplayLayerIDX := 1;

    if LoadDefinition then
    begin

      // =========================================================================
      // erzeuge den Trainer....
      Trainer := TTrainer.create(Net, Options);
      // ========================================================================
      // zum Importieren müssen die Buffer alle erzeugt sein,
      // daher ein Vorwärtslauf....

      ActPic := Class_Imaging.GetTrainVol(0);
      Net.Forward(ActPic.PicVolume, false);
      Net.Import;

      ActPic.PicVolume.Free;

      FRMMain.cbUseChunk.Checked := Options.ChunkEnabled;
    end
    else
     showmessage('No definition file');
  Finally
    If assigned(InfoCMD) Then
      InfoCMD(0, TrainReg);

    // Resume;
  End;
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Destructor TLearnThread.Destroy;
Var
  i: Integer;

Begin
  ResultArray.Free;
  Class_Imaging.Free;
  Trainer.Free;

  If Layer_Def <> Nil Then
    For i := 0 To Layer_Def.Count - 1 Do
      TOpt(Layer_Def[i]).Free;

  Layer_Def.Free;
  Net.Free;
  Options.Free;

  Inherited;
End;

Procedure TLearnThread.Execute;
Begin

  StartTicks := GettickCount;
  iStartTime := StartTicks;
  iRuns := 0;
  iChunkIDX := 0;
  iTrainingIDX := 0;

  self.Priority := tpTimeCritical;
  SetPriorityClass(self.Handle, REALTIME_PRIORITY_CLASS);
  setThreadAffinityMask(Handle, 1 Shl 2);

  While Not Terminated Do
  Begin
    Learn;
  End;

End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

procedure TLearnThread.StoreResults(sFilename: String; iRun_Train: Integer;
  dLoss_Train, dAcc_Train, dAcc_Test: Single);
var
  tf: TextFile;
  fs: TFormatsettings;
begin
  exit;
  fs.DecimalSeparator := ',';
  Assignfile(tf, sFilename);
  if fileexists(sFilename) then
    Append(tf)
  else
  begin
    rewrite(tf);
    writeln(tf, 'Runs;Loss Train;Acc Train;Acc Test');
  end;
  writeln(tf, Format('%2.2d;%2.3f;%2.3f;%2.3f', [iRun_Train, dLoss_Train,
    dAcc_Train, dAcc_Test], fs));
  closeFile(tf);

end;

Procedure TLearnThread.Sync;
Begin
  Try
    If iRuns Mod 20 = 0 Then
    Begin
      If assigned(InfoCMD) Then
      Begin
        TrainReg.iRuns := iRuns;
        InfoCMD(1, TrainReg);
      End;
    End;

    If bDebug Then
    Begin
      If iRuns Mod Options.batch_size = Options.batch_size - 1 Then
      Begin
        If assigned(InfoCMD) Then
          InfoCMD(2, Net);
      End;
    End;

    If iRuns Mod 10 = 0 Then
    Begin
      If assigned(InfoCMD) Then
        InfoCMD(3, Net);
    End;

    If iRuns Mod 200 = 0 Then
    Begin
      TrainReg.TrainingAccuracy := 0;
      TrainReg.SumCostLoss := 0;
      TrainReg.Suml2decayloss := 0;
      iStartTime := GettickCount;
      TrainReg.iRunStat := 0;
    End;

    if bMakePrediction then
      If assigned(InfoCMD) Then
        InfoCMD(4, Net);

    If iRuns Mod 500 = 1 Then
    Begin
      If assigned(InfoCMD) Then
        InfoCMD(5, Net);

    End;
  Except
  End;
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TLearnThread.Learn;
var
  ActPic: TCifarImage;
Begin
  Try
    ActPic := Class_Imaging.GetTrainVol(iTrainingIDX);

    If ActPic.PicVolume <> Nil Then
    Begin
      iRuns := iRuns + 1;

      TPArrayDouble(ResultArray.Buffer^)[0] := ActPic.Detail;

      // eine Epoche trainieren
      TrainReg := Trainer.train(ActPic.PicVolume, ResultArray);

      // Lernerfolg prüfen....
      If Net.getPrediction = ActPic.Detail Then
        TrainReg.TrainingAccuracy := TrainReg.TrainingAccuracy + 1;

      // die Kostenergebnisse summieren
      TrainReg.SumCostLoss := TrainReg.SumCostLoss + TrainReg.cost_loss;

      TrainReg.Suml2decayloss := TrainReg.Suml2decayloss +
        TrainReg.l2_decay_loss;

      TrainReg.iRunStat := TrainReg.iRunStat + 1;

      If TrainReg.iRunStat > 2 Then
        AVGRunsPerSec :=
          round(1000 / ((GettickCount - iStartTime) / TrainReg.iRunStat));

      // alle 1000 Durchläufe speichern
      If iRuns Mod 1000 = 999 Then
        Net.Export;

      Synchronize(Sync);
    End;

    // Training von vorne, nach x Durchläufen
    If iTrainingIDX < Class_Imaging.iImageCount_TrainData Then
    Begin

      // Behandlung von Chunks
      if Options.ChunkEnabled then
      begin
        If iTrainingIDX Mod Options.ChunkSize = Options.ChunkSize - 1 Then
        Begin
          iChunkIDX := iChunkIDX + 1;

          If iChunkIDX >= Options.ChunkRepetitions Then
          Begin
            iTrainingIDX := iTrainingIDX + 1;
            iChunkIDX := 0;
          End
          Else
            iTrainingIDX := iTrainingIDX - (Options.ChunkSize - 1);
        End
        Else
          iTrainingIDX := iTrainingIDX + 1;
      end
      Else
        iTrainingIDX := iTrainingIDX + 1;
    End
    Else
    Begin
      iChunkIDX := 0;
      iTrainingIDX := 0;
      CompletedRuns := CompletedRuns + 1;

      // lade den nächsten Imageblock (jeweils 10000 Bilder)
      iImageBlock := iImageBlock + 1;
      If iImageBlock > c_MaxImageBlock Then
        iImageBlock := 1;

      Net.Export;
    End;
    ActPic.PicVolume.Free;

  Except
    On e: Exception Do
    Begin
      FRMMain.StatusBar.SimpleText := 'TLearnThread.Learn: ' + e.Message;
    End
  End;
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.Prediction(bSilent: Boolean);
const
  c_cols = 4;
Var
  i, k, ixPos, iyPOs: Integer;
  ResultVol: TVolume;
  iSec: Integer;
  // TrainReg: TTrainReg;
  s: String;
  iPredict: Integer;
  iAnzGleicherSaetze: Double;
  Predict: TPredict;
  PredictList: TList;
  bmp: TBitmap;
  TrainBmp: TBitmap;
  Class_Imaging: TClass_Imaging;
  iBMPWidth: Integer;

  ActPic: TCifarImage;
Begin
  Class_Imaging := TClass_Imaging.create;
  iAnzGleicherSaetze := 0;

  if not bSilent then
  begin
    bmp := TBitmap.create;
    bmp.Width := imgPrediction.Width;
    bmp.Height := imgPrediction.Height;
    bmp.Canvas.brush.color := clBlack;
    bmp.Canvas.Rectangle(0, 0, bmp.Width, bmp.Height);

    iBMPWidth := 60;
  end;

  TrainBmp := TBitmap.create;

  iAnzGleicherSaetze := 0;
  Try

    For i := iPred To iPred + c_PredictIMageCount - 1 Do
    Begin
      Try
        ixPos := 10 + (imgPrediction.Width Div c_cols) *
          ((i - iPred) Mod c_cols);
        iyPOs := (i - iPred) Div c_cols;

        ActPic := LearnThread.Class_Imaging.GetTestVol(i);

        ResultVol := LearnThread.Net.Forward(ActPic.PicVolume, false);

        if not bSilent then
        begin
          Class_Imaging.vol_to_bmp(ActPic.PicVolume, TrainBmp, false);
          bmp.Canvas.StretchDraw(rect(ixPos, 10 + iyPOs * iBMPWidth,
            ixPos + iBMPWidth, 10 + (iyPOs + 1) * iBMPWidth), TrainBmp);

        end;

        PredictList := LearnThread.Net.getPrediction(c_accordance);
        If PredictList.Count >= c_accordance-2 Then
        Begin
          s := '';
          if not bSilent then
          begin
            bmp.Canvas.Font.Size := 7;

            For k := 0 To c_accordance-1 Do
            Begin
              If ActPic.Detail = TPredict(PredictList[k]).iLabel Then
                bmp.Canvas.Font.color := clGreen
              Else
                bmp.Canvas.Font.color := clWhite;

              s := Format('%0.0d.%s %0.1f%%',
                [k + 1, LearnThread.Class_Imaging.sDetailTexts
                [TPredict(PredictList[k]).iLabel], TPredict(PredictList[k])
                .sLikeliHood * 100]);

              bmp.Canvas.Textout(iBMPWidth + ixPos + 3, 10 + iyPOs * iBMPWidth +
                k * (bmp.Canvas.TextHeight(s)), s)

            End;
          end;

          If (TPredict(PredictList[0]).iLabel = ActPic.Detail) Then
            iAnzGleicherSaetze := iAnzGleicherSaetze + 1
          Else If (TPredict(PredictList[1]).iLabel = ActPic.Detail) Then
            iAnzGleicherSaetze := iAnzGleicherSaetze + 1
          Else If (TPredict(PredictList[2]).iLabel = ActPic.Detail) Then
            iAnzGleicherSaetze := iAnzGleicherSaetze + 1
          Else If (TPredict(PredictList[3]).iLabel = ActPic.Detail) Then
            iAnzGleicherSaetze := iAnzGleicherSaetze + 1
          Else If (TPredict(PredictList[4]).iLabel = ActPic.Detail) Then
            iAnzGleicherSaetze := iAnzGleicherSaetze + 1;

        End;
        // Liste freigeben
        For k := 0 To PredictList.Count - 1 Do
        Begin
          TPredict(PredictList[k]).Free;
          PredictList[k] := Nil;
        End;
      Finally
        ActPic.PicVolume.Free;
        FreeandNil(PredictList);
      End;
    End;
  Except
    On e: Exception Do
    Begin
      FRMMain.StatusBar.SimpleText := 'TFRMMain.Prediction: ' + e.Message;
    End

  End;

  dLastPredicion := iAnzGleicherSaetze / c_PredictIMageCount;

  if LearnThread.TrainReg <> nil then
    lsTestAcc.AddXY(LearnThread.TrainReg.iRuns, dLastPredicion);

  if not bSilent then
  begin
    bmp.Canvas.Font.color := clWhite;
    bmp.Canvas.Textout(10, 10, // bmp.Height - bmp.Canvas.TextHeight('XXX'),
      Format('Pred: %2.1f%%', [100 * dLastPredicion]));

    imgPrediction.Canvas.Draw(0, 0, bmp);
    FreeandNil(bmp);
  end;
  FreeandNil(TrainBmp);
  FreeandNil(Class_Imaging);
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.Store1Click(Sender: TObject);
Begin
  LearnThread.Net.CSVExport('.\test.csv', LearnThread.Trainer,
    LearnThread.LearningInfo);
End;
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TFRMMain.Load1Click(Sender: TObject);
Begin

  LearnThread.Net.CSVImport('.\test.csv', LearnThread.Trainer,
    LearnThread.LearningInfo);

  If assigned(LearnThread.InfoCMD) Then
    LearnThread.InfoCMD(-1, LearnThread.Net);
  If assigned(LearnThread.InfoCMD) Then
    LearnThread.InfoCMD(0, LearnThread.TrainReg);

End;

function TLearnThread.LoadDefinition: Boolean;
var
  sFilename: string;
  ini: TInifile;
  SL, SL2, SLValues: TStringLIst;
  s: String;
  i, k: Integer;
  sDataPath: String;

  sLayerType: String;
  sName: String;
  iFilter_Size: Integer;
  iFilter_Count: Integer;
  iStride: Integer;
  iPad: Integer;

  iSize_x: Integer;
  iSize_y: Integer;
  iDepth: Integer;
  iSize: Integer;
  iOutSize: Integer;
  sdrop_prob: Single;

  sActivation: String;
begin

  Result := true;

  sFilename := ExtractFilePath(application.ExeName) + 'Structure.ini';
  if fileexists(sFilename) then
  begin

    ini := TInifile.create(sFilename);
    try
      // die Datenstruktur ausklamüsern
      SL := TStringLIst.create;
      SL.Delimiter := ',';
      SLValues := TStringLIst.create;
      SL2 := TStringLIst.create;
      SL2.Delimiter := ':';
      try
        ini.ReadSectionValues('Structure', SLValues);

        Layer_Def.Clear;

        // die LayerDefinition
        // über alle Layer
        for i := 0 to SLValues.Count - 1 do
        begin

          s := SLValues[i];
          delete(s, 1, pos('=', s));

          SL.DelimitedText := StringReplace(s, ' ', '', [rfReplaceAll]);

          // alle Parameter...
          for k := 0 to SL.Count - 1 do
          begin
            SL2.DelimitedText := SL[k];
            if lowercase(SL2[0]) = 'layer' then
              sLayerType := lowercase(SL2[1]);

            if lowercase(SL2[0]) = 'name' then
              sName := lowercase(SL2[1]);

            if lowercase(SL2[0]) = 'filter_size' then
              iFilter_Size := strToInt(lowercase(SL2[1]));

            if lowercase(SL2[0]) = 'filter_count' then
              iFilter_Count := strToInt(lowercase(SL2[1]));

            if lowercase(SL2[0]) = 'stride' then
              iStride := strToInt(lowercase(SL2[1]));

            if lowercase(SL2[0]) = 'size' then
              iSize := strToInt(lowercase(SL2[1]));

            if lowercase(SL2[0]) = 'pad' then
              iPad := strToInt(lowercase(SL2[1]));

            if lowercase(SL2[0]) = 'size_x' then
              iSize_x := strToInt(lowercase(SL2[1]));
            if lowercase(SL2[0]) = 'size_y' then
              iSize_y := strToInt(lowercase(SL2[1]));
            if lowercase(SL2[0]) = 'depth' then
              iDepth := strToInt(lowercase(SL2[1]));

            if lowercase(SL2[0]) = 'dropprob' then
              sdrop_prob := strTofloat(lowercase(SL2[1]));

            if lowercase(SL2[0]) = 'activation' then
              sActivation := lowercase(SL2[1]);
          end; // END FOR Layer Parameter

          // Übernehme die Definitionen der Layer
          if sLayerType = 'input' then
          begin
            Layer_Def.ADD(CreateOpt_Input(sName, iSize_x, iSize_y, iDepth));
          end;
          if sLayerType = 'conv' then
          begin
            Layer_Def.ADD(CreateOpt_Conv(sName, iFilter_Size, iFilter_Count,
              iStride, iPad, sActivation));
          end;

          if sLayerType = 'pool' then
          begin
            Layer_Def.ADD(CreateOpt_Pool(sName, iSize, iStride));
          end;

          if sLayerType = 'softmax' then
          begin
            Layer_Def.ADD(CreateOpt_Hidden(sName, 'softmax', iSize, 'NONE'));
            iOutSize := iSize;
          end;

          if sLayerType = 'fc' then
          begin
            Layer_Def.ADD(CreateOpt_FullyConnected(sName, iSize, sActivation));
            iOutSize := iSize;
          end;

          if sLayerType = 'dropout' then
          begin
            Layer_Def.ADD(CreateOpt_Dropout(sName, sdrop_prob));
            iOutSize := iSize;
          end;

        end; // END FOR LAYERS

        Net.makeLayers(Layer_Def);
        If assigned(InfoCMD) Then
          InfoCMD(-1, Net);

      finally
        SL2.Free;
        SL.Free;
        SLValues.Free;
      end;

      // ====================================================================
      sWeightsFilename := ini.ReadString('Data_Filenames', 'Weights', '');
      Net.sWightsFilename := sWeightsFilename;

      // Bilder laden
      iImageBlock := 1;
      Class_Imaging := TClass_Imaging.create;

      Class_Imaging.LoadCategories(ini.ReadString('Data_Filenames', 'Labels',
        ''), ini.ReadString('Data_Filenames', 'DetailLabels', ''));

      // sDataPath + 'coarse_label_names.txt',
      // sDataPath + 'fine_label_names.txt');

      Class_Imaging.StartTrainData(ini.ReadString('Data_Filenames',
        'TrainData', ''));
      Class_Imaging.StartTestData(ini.ReadString('Data_Filenames',
        'TestData', ''));

      sResultsFilename := ini.ReadString('Data_Filenames', 'Results', '');

      ResultArray := TMyArray.create(iOutSize);
      // es gibt z.B. 100 Klassen bei Cifar100

      // ===============================================================================
      // Lernen....
      // ===============================================================================

      // die Parameter
      Options.method := ini.ReadString('Options', 'method', 'adagrad');
      // 'adagrad';
      Options.batch_size := ini.ReadInteger('Options', 'batch_size', 15);
      // (4) nach jedem Batch werden die Gradienten gelöscht!

      Options.learning_rate := ini.ReadFloat('Options', 'learning_rate', 0.01);
      // 0.01; // 0.0001; //

      Options.momentum := ini.ReadFloat('Options', 'momentum', 0.9);
      // 0.9; // 0.9

      Options.l1_decay := ini.ReadFloat('Options', 'l1_decay', 0); // 0;
      Options.l2_decay := ini.ReadFloat('Options', 'l2_decay', 0.0001);
      // 0.0001;

      Options.ro := ini.ReadFloat('Options', 'ro', 0.95); // 0.95;
      Options.eps := ini.ReadFloat('Options', 'eps', 1E-6); // 1E-6;

      // =========================================================================
      // DER CHUNK
      // ein Block an Infomationen, der sicher gelernt sein muss, bevor der nächste Chunk gelernt werden kann
      // wird eine Information nicht gelernt, so kommt sie in den nächsten Chank zum wiederholten Lernen
      Options.ChunkEnabled := ini.ReadBool('Chunk', 'ChunkEnabled', true);

      Options.ChunkSize := ini.ReadInteger('Chunk', 'ChunkSize',
        10 * Options.batch_size);
      // 10 * Options.batch_size;
      // Anzahl der zu lernenden Bilder
      Options.ChunkRepetitions := ini.ReadInteger('Chunk', 'ChunkRepetitions',
        4); // ; // Anzahl der Wiederholungen
      Options.ChunkAccLikeliHood := ini.ReadFloat('Chunk', 'ChunkAccLikeliHood',
        0.8); // 0.8;
      // Mindest-W-keit, dass eine Information als gelernt akzeptiert wird
      Options.ChunkNonAccLikeliHood := ini.ReadFloat('Chunk',
        'ChunkNonAccLikeliHood', 0.2); // 0.2;
      // Mindest-W-keit, dass eine Information als gelernt akzeptiert wird

    finally
      ini.Free;
    end;
  end
  else
    Result := false;
end;

Procedure TFRMMain.FormResize(Sender: TObject);
Begin
  imgDebug.Picture.Bitmap.Width := imgDebug.Width;
  imgDebug.Picture.Bitmap.Height := imgDebug.Height;
End;

procedure TFRMMain.FormShow(Sender: TObject);
begin
  LearnThread.bMakePrediction := true;

  if LearnThread.Suspended then
    Prediction(false);
end;

Procedure TFRMMain.btnTestClick(Sender: TObject);
Begin
  LearnThread.bMakePrediction := true;

  if LearnThread.Suspended then
    Prediction(false);
End;

End.
