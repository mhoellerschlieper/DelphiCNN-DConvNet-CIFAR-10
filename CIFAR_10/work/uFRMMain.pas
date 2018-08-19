Unit uFRMMain;

Interface

Uses
  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  StdCtrls,

  uClasses_Types,
  uClass_CNN,
  uClass_Imaging,
  uFunctions,

  ExtCtrls,
  TeEngine,
  TeeProcs,
  Chart,
  Series, Menus, ComCtrls
  ;

Const
  c_PredictIMageCount = 100;
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
    iStatRuns: Integer;                 // beginnt nach jeder Ausgabe neu...
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

    Constructor create;
    Procedure Init;
    Destructor Destroy; override;
    Procedure Execute; override;
    Procedure Learn;
    Procedure Sync;
  End;

  { TFRMMain }

  TFRMMain = Class(TForm)
    Panel3: TPanel;
    lblRuns: TLabel;
    lblLoss: TLabel;
    Panel1: TPanel;
    panButtons: TPanel;
    Chart1: TChart;
    Image1: TImage;
    imgPrediction: TImage;
    btnStart: TButton;
    btnNext: TButton;
    StatusBar1: TStatusBar;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Laod1: TMenuItem;
    Store1: TMenuItem;
    N1: TMenuItem;
    Close1: TMenuItem;
    btnPrev: TButton;
    cbDebug: TCheckBox;
    Procedure btnStartClick(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    Procedure btnNextClick(Sender: TObject);
    Procedure FormCreate(Sender: TObject);
    Procedure cbDebugClick(Sender: TObject);
    Procedure Image1Click(Sender: TObject);
    Procedure btnPrevClick(Sender: TObject);
    Procedure Store1Click(Sender: TObject);
    Procedure Laod1Click(Sender: TObject);
  private
    { Private-Deklarationen }
  public

    LearnThread: TLearnThread;
    iDisplayLayerIDX: Integer;

    iPred: Integer;

    // Chart
    lsLoss: TLineSeries;
    lsTrainAcc: TLineSeries;

    Procedure BuildButtons(Net: TNet);
    Procedure btnLayerlick(Sender: TObject);
    Procedure AusgabeBilder(iLayerIDX: Integer; Net: TNet);
    Procedure InfoCMD(iCMD: Integer; Var Data);
    Procedure Prediction;
  End;

Var
  FRMMain           : TFRMMain;

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
  c_PicPerRow       : Integer;
  s                 : TLayer;
  bmp               : TBitmap;
  vol               : TVolume;
  i, j, k, d, iRow, iwidth, x, y: Integer;
  Class_Imaging     : TClass_Imaging;

  // die Bildposition berechnen
  Procedure NextXY;
  Begin
    x := x + iwidth + 5;
    If x + iwidth >= Image1.Width Then
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
    Image1.Canvas.Textout(x, y, s);

    x := 5;
    y := y + Image1.Canvas.TextHeight(s);
  End;

  Procedure TextoutMinMax(s: String; a: TMyArray);
  Var
    mm              : TMinMax;
  Begin
    mm := Global.maxmin(a);
    Image1.Canvas.Textout(x, y, Format('%s  Max:%2.5f Min: %2.5f', [s, mm.maxv, mm.minv]));
    x := 5;
    y := y + Image1.Canvas.TextHeight(s);

  End;

Begin
  If Not Image1.Canvas.TryLock Then
    exit;

  x := 5;
  y := 5;

  //Image1.Canvas.Lock;

  // leere den Canvas
  Image1.Canvas.brush.color := clBlack;
  Image1.Canvas.Font.color := clWhite;
  Image1.Canvas.Rectangle(0, 0, Image1.Width, Image1.Height);

  s := Net.Layers[iLayerIDX];
  bmp := TBitmap.create;
  Try
    Class_Imaging := TClass_Imaging.create;
    iwidth := Image1.Width Div 10;

    TextoutMinMax('INPUT w ', TLayer(Net.Layers[0]).out_act.w);

    // DAS EINGANGABILD
    vol := TLayer(Net.Layers[0]).out_act;

    Class_Imaging.vol_to_bmp(vol, bmp, false);
    Image1.Canvas.StretchDraw(
      rect(x, y, x + iwidth, y + iwidth), bmp);
    NextLn;

    TextoutMinMax('INPUT dw ', TLayer(Net.Layers[0]).out_act.dw);
    Class_Imaging.vol_to_bmp(vol, bmp, true);
    Image1.Canvas.StretchDraw(
      rect(x, y, x + iwidth, y + iwidth), bmp);

    NextLn;

    Textout(s.layer_type + ' FWTime:' + inttostr(s.fwTime) + ' BWTime:' + inttostr(s.bwTime));

    iwidth := 20;

    If s Is TConvLayer Then
    Begin

      //iwidth := Image1.Width Div (TConvLayer(s).out_depth * TConvLayer(s).filters.Buffer[0].n Div 50);

      Textout('FILTER Weights');
      // die Gewichte ausgeben
      For i := 0 To TConvLayer(s).out_depth - 1 Do
      Begin
        vol := TConvLayer(s).filters.Buffer[i];

        If iLayerIDX = 1 Then
        Begin
          Class_Imaging.vol_to_bmpCol(vol, bmp, false);

          Image1.Canvas.StretchDraw(
            rect(x, y, x + iwidth, y + iwidth), bmp);

          NextXY;
        End
        Else
        Begin
          For j := 0 To vol.depth - 1 Do
          Begin
            Class_Imaging.vol_to_bmpSW(vol, bmp, false, j);

            Image1.Canvas.StretchDraw(
              rect(x, y, x + iwidth, y + iwidth), bmp);

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
        If iLayerIDX = 1 Then
        Begin
          Class_Imaging.vol_to_bmpCol(vol, bmp, true);

          Image1.Canvas.StretchDraw(
            rect(x, y, x + iwidth, y + iwidth),
            bmp);
          NextXY;
        End
        Else
        Begin
          For j := 0 To vol.depth - 1 Do
          Begin
            Class_Imaging.vol_to_bmpSW(vol, bmp, false, j);

            Image1.Canvas.StretchDraw(
              rect(x, y, x + iwidth, y + iwidth), bmp);

            NextXY;

          End;

        End;
      End;
    End;

    iwidth := Image1.Width Div 30;
    // AUSGANGS GEWICHTE
    NextLn;
    NextLn;
    vol := s.out_act;

    TextoutMinMax('Output w ', vol.w);

    For j := 0 To vol.depth Do
    Begin

      Class_Imaging.vol_to_bmpSW(vol, bmp, false, j);
      Image1.Canvas.StretchDraw(
        rect(x, y, x + iwidth, y + iwidth
        ), bmp);
      NextXY;
    End;

    // AUSGANGS GRADIENTEN (NUR NICHT SOFTMAX)
    If Not (s Is TSoftMaxLayer) Then
    Begin
      NextLn;
      TextoutMinMax('Output dw ', vol.dw);
      For j := 0 To vol.depth Do
      Begin
        Class_Imaging.vol_to_bmpSW(vol, bmp, true, j);
        Image1.Canvas.StretchDraw(rect(x, y, x + iwidth, y + iwidth), bmp);
        NextXY;
      End;
    End;

    Image1.Refresh;
    Image1.Repaint;
  Finally
    bmp.Free;
    Class_Imaging.Free;
  End;

  Image1.Canvas.UnLock;
End;

Procedure TFRMMain.btnStartClick(Sender: TObject);
Begin
  If LearnThread.Suspended Then
  Begin
    //LearnThread.iRuns := 0;
    //LearnThread.StartTicks := GettickCount;
    LearnThread.Resume;

    btnStart.caption := 'Stopp';
  End
  Else
  Begin
    LearnThread.Suspend;
    btnStart.caption := 'Start'
  End;
End;

Procedure TFRMMain.BuildButtons(Net: TNet);
Var
  i                 : Integer;
  btn               : TButton;
  s                 : String;
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
    s := inttostr(i) + '. ' +
      TLayer(Net.Layers[i]).sName + ' ' +
      inttostr(TLayer(Net.Layers[i]).out_sx) + 'x' +
      inttostr(TLayer(Net.Layers[i]).out_sy) + 'x' +
      inttostr(TLayer(Net.Layers[i]).out_depth);

    btn := TButton.Create(panButtons);
    btn.Name := 'NETBTN' + inttostr(i);
    btn.Parent := panButtons;
    btn.Caption := s;
    btn.Tag := i;
    btn.Width := panButtons.Width;
    btn.left := 0;
    btn.Top := i * btn.Height;
    btn.OnClick := btnLayerlick;
  End;
End;

Procedure TFRMMain.btnLayerlick(Sender: TObject);
Begin
  iDisplayLayerIDX := TButton(Sender).Tag;
End;

Procedure TFRMMain.btnNextClick(Sender: TObject);
Begin
  If iPred + c_PredictImageCount < length(LearnThread.Class_Imaging.TestData) Then
    iPred := iPred + c_PredictImageCount
  Else
    iPred := length(LearnThread.Class_Imaging.TestData) - c_PredictImageCount;

  Prediction;
End;

Procedure TFRMMain.btnPrevClick(Sender: TObject);
Begin
  If iPred - c_PredictImageCount >= 0 Then
    iPred := iPred - c_PredictImageCount
  Else
    iPred := 0;
  Prediction;
End;

Procedure TFRMMain.cbDebugClick(Sender: TObject);
Begin
  LearnThread.bDebug := cbDebug.Checked;
End;

Procedure TFRMMain.Image1Click(Sender: TObject);
Begin

End;

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

  lsLoss := TLineSeries.create(Nil);
  lsLoss.Clear;
  lsLoss.ParentChart := Chart1;
  lsLoss.Name := 'Loss';
  lsLoss.Identifier := 'Loss';
  // lsLoss.VertAxis := TVertAxis.aLeftAxis;

  lsTrainAcc := TLineSeries.create(Nil);
  lsTrainAcc.Clear;
  lsTrainAcc.ParentChart := Chart1;
  lsTrainAcc.Name := 'ACC';
  lsTrainAcc.Identifier := 'ACC';
  // lsTrainAcc.VertAxis := TVertAxis.aRightAxis; // aBothVertAxis;

  LearnThread.bDebug := cbDebug.Checked;

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
  LearnThread.FreeOnTerminate := True;
  LearnThread.Terminate;

  lsTrainAcc.Free;
  lsLoss.Free;

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
  ResultVol         : TVolume;
  iSec              : Integer;
  TrainReg          : TTrainReg;
  s                 : String;
  iPredict          : Integer;
  iAnzGleicherSaetze: Integer;
  Predict           : TPredict;
  PredictList       : TList;
  bmp               : TBitmap;
  TrainBmp          : TBitmap;
  Class_Imaging     : TClass_Imaging;
  iBMPWidth         : Integer;
Begin
  Try

    Case iCMD Of
      -1:
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
            lblLoss.caption := Format('FWD-Time: %3.0f   BWD-Time: %3.0f    Loss: %2.5f     L2 Decay Loss: %2.8f   Train Acc: %2.8f',
              [TrainReg.fwd_time / 1000,
              TrainReg.bwd_time / 1000,
                TrainReg.SumCostLoss / TrainReg.iRunStat,
                TrainReg.Suml2decayloss / TrainReg.iRunStat,
                TrainReg.TrainingAccuracy / TrainReg.iRunStat
                ]);

            lsLoss.AddXY(TrainReg.iRuns, TrainReg.SumCostLoss / TrainReg.iRunStat);
            lsTrainAcc.AddXY(TrainReg.iRuns, TrainReg.TrainingAccuracy / TrainReg.iRunStat)
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
            lblRuns.caption :=
              'RUNS:' + inttostr(LearnThread.iRuns) +
              '   Training:' + inttostr(LearnThread.iTrainingIDX) +
              '   CompletedRuns:' + inttostr(LearnThread.CompletedRuns) +
              '   Time: ' + Format('%2.2dT %2.2d:%2.2d:%2.2d', [(iSec Div (3600 * 24)), (iSec Div 3600) Mod 24, (iSec Div 60) Mod 60, iSec Mod 60]) +
            '   AVG-Time[runs/sec]:' + Format('%2.5d', [LearnThread.AVGRunsPerSec])
              ;
          End;
        End;
    End;
  Finally
  End;
End;

{ TLearnThread }

Constructor TLearnThread.create;
Begin
  Inherited create(true);

  Priority := tpHighest;
  SetProcessAffinityMask(self.Handle, $FF);

  FreeOnTerminate := false;
End;

Procedure TLearnThread.Init;
Var
  i                 : Integer;
  sDataPath         : String;
Begin
  Try

    Layer_Def := TList.create;
    Net := TNet.create;
    Options := TTrainerOpt.create;

    iDisplayLayerIDX := 1;

    // Die Layer-Definition......
    Layer_Def.Clear;
    Layer_Def.ADD(CreateOpt_Input('input', 32, 32, 3));
    Layer_Def.ADD(CreateOpt_Conv('conv', 5, 16, 0, 0, 'relu'));
    Layer_Def.ADD(CreateOpt_Pool('pool', 2, 2));
    Layer_Def.ADD(CreateOpt_Conv('conv', 5, 20, 1, 2, 'relu'));
    Layer_Def.ADD(CreateOpt_Pool('pool', 2, 2));
    Layer_Def.ADD(CreateOpt_Conv('conv', 5, 20, 1, 2, 'relu'));
    Layer_Def.ADD(CreateOpt_Pool('pool', 2, 2));
    Layer_Def.ADD(CreateOpt_Hidden('softmax', 'softmax', 10, 'NONE'));
    Net.makeLayers(Layer_Def);

    If assigned(InfoCMD) Then
      InfoCMD(-1, Net);

    // Bilder laden
    iImageBlock := 1;
    Class_Imaging := TClass_Imaging.create;
    sDataPath := '.\Data\cifar-10-batches-bin\';
    Class_Imaging.LoadCifar_ADDTrainData(sDataPath + 'data_batch_' + inttostr(iImageBlock) + '.bin', sDataPath + 'batches.meta.txt', Cifar10);
    Class_Imaging.LoadCifar_ADDTestData(sDataPath + '\test_batch.bin', sDataPath + 'batches.meta.txt', Cifar10);

    ResultArray := TMyArray.create(10); // es gibt 10 Klasse,

    // ===============================================================================
    // Lernen....
    // ===============================================================================

    // die Parameter
    Options.method := 'adadelta';
    Options.batch_size := 15;           // nach jedem Batch werden die Gradienten gelöscht!
    Options.learning_rate := 0.005;
    Options.momentum := 0.9;
    Options.l1_decay := 0;
    Options.l2_decay := 0.0001;
    Options.ro := 0.95;
    Options.eps := 1E-6;

    //=========================================================================
    // DER CHUNK
    // ein Block an Infomationen, der sicher gelernt sein muss, bevor der nächste Chunk gelernt werden kann
    // wird eine Information nicht gelernt, so kommt sie in den nächsten Chank zum wiederholten Lernen
    Options.ChunkSize := 40 * Options.batch_size;
    Options.ChunkAccLikeliHood := 0.8;  // Mindest-W-keit, dass eine Information als gelernt akzeptiert wird
    Options.ChunkNonAccLikeliHood := 0.2; // Mindest-W-keit, dass eine Information als gelernt akzeptiert wird

    //=========================================================================
    // erzeuge den Trainer....
    Trainer := TTrainer.create(Net, Options);
    // ========================================================================
    // zum Importieren müssen die Buffer alle erzeugt sein,
    // daher ein Vorwärtslauf....

    Net.Forward(Class_Imaging.TrainData[0].PicVolume, false);
    Net.Import;

  Finally
    If assigned(InfoCMD) Then
      InfoCMD(0, TrainReg);

    //Resume;
  End;

  FRMMain.Prediction;
End;

Destructor TLearnThread.Destroy;
Var
  i                 : Integer;

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
  While Not Terminated Do
  Begin
    Learn;
  End;

End;

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

    If iRuns Mod 20 = 0 Then
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
  Except
  End;
End;

Procedure TLearnThread.Learn;
Begin

  If Class_Imaging.TrainData[iTrainingIDX].PicVolume <> Nil Then
  Begin
    iRuns := iRuns + 1;

    TPArraysingle(ResultArray.Buffer^)[0] := Class_Imaging.TrainData[iTrainingIDX].Cat1;

    // eine Epoche trainieren
    TrainReg := Trainer.train(Class_Imaging.TrainData[iTrainingIDX].PicVolume, ResultArray);

    // Lernerfolg prüfen....
    If Net.getPrediction = Class_Imaging.TrainData[iTrainingIDX].Cat1 Then
      TrainReg.TrainingAccuracy := TrainReg.TrainingAccuracy + 1;

    // die Kostenergebnisse summieren
    TrainReg.SumCostLoss := TrainReg.SumCostLoss + TrainReg.cost_loss;
    TrainReg.Suml2decayloss := TrainReg.Suml2decayloss + TrainReg.l2_decay_loss;

    TrainReg.iRunStat := TrainReg.iRunStat + 1;

    If TrainReg.iRunStat > 2 Then
      AVGRunsPerSec := round(1000 / ((GettickCount - iStartTime) / TrainReg.iRunStat));

    // alle 1000 Durchläufe speichern
    If iRuns Mod 1000 = 999 Then
      Net.Export;

    Synchronize(Sync);
  End;

  // Training von vorne, nach x Durchläufen
  If iTrainingIDX < Class_IMaging.iImageCount_TrainData Then //high(Class_Imaging.TrainData) then
  Begin

    // Behandlung von Chunks
   { If iTrainingIDX Mod Options.ChunkSize = Options.ChunkSize - 1 Then
    Begin
      iChunkIDX := iChunkIDX + 1;

      If iChunkIDX > 3 Then
      Begin
        iTrainingIDX := iTrainingIDX + 1;
        iChunkIDX := 0;
      End
      Else
        iTrainingIDX := iTrainingIDX - (Options.ChunkSize - 1);
    End
    Else}
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

    Class_Imaging.LoadCifar_ADDTrainData(
      'c:\Entwicklung\Projekte\ALOBV\Delphi\Data\cifar-10-batches-bin\data_batch_' + inttostr(iImageBlock) + '.bin', '',
      Cifar10);

    Net.Export;
  End;
End;

Procedure TFRMMain.Prediction;
Var
  i, k, ixPos, iyPOs: Integer;
  ResultVol         : TVolume;
  iSec              : Integer;
  TrainReg          : TTrainReg;
  s                 : String;
  iPredict          : Integer;
  iAnzGleicherSaetze: Single;
  Predict           : TPredict;
  PredictList       : TList;
  bmp               : TBitmap;
  TrainBmp          : TBitmap;
  Class_Imaging     : TClass_Imaging;
  iBMPWidth         : Integer;
Begin
  Class_Imaging := TClass_Imaging.create;
  iAnzGleicherSaetze := 0;

  bmp := TBitmap.create;
  bmp.Width := imgPrediction.Width;
  bmp.height := imgPrediction.Height;
  bmp.Canvas.brush.color := clBlack;
  bmp.Canvas.Rectangle(0, 0, bmp.Width, bmp.Height);

  iBMPWidth := 60;

  TrainBmp := TBitmap.Create;

  iAnzGleicherSaetze := 0;
  Try

    For i := iPred To iPred + c_PredictIMageCount - 1 Do
    Begin
      Try
        ixPos := 10 + (imgPrediction.width Div 3) * ((i - iPred) Mod 3);
        iyPOs := (i - iPred) Div 3;

        ResultVol := LearnThread.Net.forward(LearnThread.Class_Imaging.TestData[i].PicVolume, false);

        Class_Imaging.vol_to_bmp(LearnThread.Class_Imaging.TestData[i].PicVolume, TrainBmp, false);
        bmp.Canvas.StretchDraw(Rect(ixPos, 10 + iyPOs * iBMPWidth, ixPos + iBMPWidth, 10 + (iyPOs + 1) * iBMPWidth), TrainBmp);

        PredictList := LearnThread.Net.getPrediction(3);
        If PredictList.count >= 3 Then
        Begin
          s := '';
          For k := 0 To 2 Do
          Begin
            If LearnThread.Class_Imaging.TestData[i].Cat1 = TPredict(PredictList[k]).iLabel Then
              bmp.Canvas.Font.Color := clGreen
            Else
              bmp.Canvas.Font.Color := clRed;

            s := Format('%s %0.3f%%', [
              LearnThread.Class_Imaging.sLabelTexts[TPredict(PredictList[k]).iLabel],
                TPredict(PredictList[k]).sLikeliHood * 100]);

            bmp.Canvas.TextOut(iBMPWidth + ixPos, 10 + iyPOs * iBMPWidth + k * (bmp.Canvas.textheight(s) + 3), s);
          End;

          If (TPredict(PredictList[0]).iLabel = LearnThread.Class_Imaging.TestData[i].Cat1) Then
            iAnzGleicherSaetze := iAnzGleicherSaetze + 1
          Else If (TPredict(PredictList[1]).iLabel = LearnThread.Class_Imaging.TestData[i].Cat1) Then
            iAnzGleicherSaetze := iAnzGleicherSaetze + 1
          Else If (TPredict(PredictList[2]).iLabel = LearnThread.Class_Imaging.TestData[i].Cat1) Then
            iAnzGleicherSaetze := iAnzGleicherSaetze + 1;

        End;
        // Liste freigeben
        For k := 0 To PredictList.count - 1 Do
        Begin
          TPredict(PredictList[k]).Free;
          PredictList[k] := Nil;
        End;
      Finally
        FreeandNil(PredictList);
      End;
    End;
  Except
  End;

  bmp.Canvas.Font.color := clWhite;
  bmp.Canvas.TextOut(10, bmp.Height - bmp.Canvas.TextHeight('XXX'),
    Format('Result: %2.3f%%', [100 * iAnzGleicherSaetze / c_PredictIMageCount]));

  imgPrediction.Canvas.Draw(0, 0, bmp);
  FreeandNil(bmp);
  FreeandNil(TrainBmp);
  FreeAndNil(Class_Imaging);
End;

Procedure TFRMMain.Store1Click(Sender: TObject);
Begin
  LearnThread.Net.CSVExport('.\test.csv', LearnThread.Trainer, LearnThread.LearningInfo);
End;

Procedure TFRMMain.Laod1Click(Sender: TObject);
Begin

  LearnThread.Net.CSVImport('.\test.csv', LearnThread.Trainer, LearnThread.LearningInfo);

  If assigned(LearnThread.InfoCMD) Then
    LearnThread.InfoCMD(-1, LearnThread.Net);
  If assigned(LearnThread.InfoCMD) Then
    LearnThread.InfoCMD(0, LearnThread.TrainReg);

End;

End.

