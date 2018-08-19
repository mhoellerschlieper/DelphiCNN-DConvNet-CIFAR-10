unit uClass_NN;

// Unit uClass_NN :
// Author : Macus Schlieper (c) 2000
//
// ------ Quickprop
// Bem.: Für große Netze ist es empfehlenswert SplitEpsilon = 1 zu setzen,
// da sie sonst ihre Aufgabe ( nach Fahlmann ) nicht lernen können
//
//

interface

uses Windows,
  Messages,
  SysUtils,
  Classes,
  Math;

Const
  N = 500;

  Sigmoid = 1; // Output zwischen -0.5 .. +0.5
  AsymSigmoid = 2; // Output zwischen 0 .. +1.0
  Gaussian = 3; // Output zwischen 0.. +1.0
  VarSigmoid = 4; // Outpus zwischen SigmoidMin .. SigmoidMax

  QuickProp = 0;
  BackProp = 1;

Type
  TNeurons = Array [0 .. N] of Real;

  TClass_NN = Class
  Public
    Epoch: Integer;
    WeightRange: Real;
    SigmoidPrimeOffset: Real;
    HyperErr: Integer;
    SplitEpsilon: Integer;
    Epsilon: Real;
    Momentum: Real;
    ModeSwitchThreshold: Real;
    MaxFactor: Real;
    Decay: Real;
    SinglePAss: Integer;
    SingleEpoch: Integer;
    SingleStep: Integer;
    Step, Restart, KeepScore: Integer;
    TotalError: Real;
    ScoreThreshold: Real;
    TotalErrorBits: Integer;
    DidGradient: Integer;
    InpRandom: Real;

    NUnits: Integer;
    Ninputs: Integer;
    FirstHidden: Integer;
    NHidden: Integer;
    FirstOutput: Integer;
    NOutputs: Integer;
    Unit_type: Integer;
    TestNr: Integer;
    KindOfOpt: Byte;

    SigmoidMin: Real;
    SigmoidMax: Real;

    Outputs: array [0 .. N] of Real;
    Sums: array [0 .. N] of Real;
    ErrorSums: array [0 .. N] of Real;
    Errors: array [0 .. N] of Real;

    NConnections: array [0 .. N] of Integer;
    Connections: array [0 .. N, 0 .. N] of Integer;

    Weights: array [0 .. N, 0 .. N] of Real;
    DeltaWeights: array [0 .. N, 0 .. N] of Real;
    Slopes: array [0 .. N, 0 .. N] of Real;
    PrevSlopes: array [0 .. N, 0 .. N] of Real;


    NTrainingPatterns: Integer;
    NTestPatterns: Integer;
    TrainingInputs: array [0 .. 200] of TNeurons;
    TrainingOutputs: array [0 .. 200] of TNeurons;

    TestInputs: array [0 .. 200] of TNeurons;

    constructor Create;
    Destructor Destroy;

    Procedure Initialize_Globals;
    Procedure Build_Data_Structures(LNInputs, LNHidden, LNOutputs: Integer);
    Procedure Connect_Layers(Start1, End1, Start2, End2: Integer);
    Procedure Init_weights;
    Procedure Clear_Slopes;
    Function ACTIVATION(Sum: Real): Real;
    Function ACTIVATION_PRIME(Value, Sum: Real): Real;
    Function ErrorFun(Desired, Actual: Real): Real;
    Procedure Forward_Pass(Input: TNeurons);
    Procedure Backward_Pass(Goal: TNeurons);
    Procedure UpDate_Weights;
    Procedure BackPropUpDate_Weights;

    Procedure Train_One_epoch;
    Procedure Train(Times: Integer; Monitor: TStrings);

    Function ReadScript(Script, Monitor: TStrings): Boolean;
    Procedure RunTests(Monitor: TStrings);
  end;

function FloatToFix(f: Real): String;

implementation

// ------------------------------------------------------------------------------
function FloatToFix(f: Real): String;
begin
  str(f: 5: 5, result);
end;

constructor TClass_NN.Create;
begin
  Initialize_Globals;
end;

Destructor TClass_NN.Destroy;
begin
end;

// ------------------------------------------------------------------------------

Procedure TClass_NN.Initialize_Globals;
begin
  Randomize;
  Unit_type := Sigmoid;
  Epoch := 0;
  WeightRange := 0.7;
  SigmoidPrimeOffset := 0.1;
  HyperErr := 1;
  SplitEpsilon := 1;
  Epsilon := 0.55; // 1.0
  Momentum := 0.9; // 0.0
  ModeSwitchThreshold := 0.0;
  MaxFactor := 1.75;
  Decay := -0.0001; // Wight Decay
  SinglePAss := 0;
  SingleEpoch := 0;
  Step := 0;
  KeepScore := 0;
  Restart := 1;
  TotalError := 0.0;
  ScoreThreshold := 0.35;
  TotalErrorBits := 0;
  SigmoidMin := -0.5;
  SigmoidMax := 0.5;
  KindOfOpt := QuickProp;
end;

// ------------------------------------------------------------------------------

Procedure TClass_NN.Build_Data_Structures(LNInputs, LNHidden, LNOutputs: Integer);
var
  i: Integer;
begin
  NUnits := 1 + LNInputs + LNHidden + LNOutputs;

  Ninputs := LNInputs;
  FirstHidden := 1 + LNInputs;
  NHidden := LNHidden;
  FirstOutput := 1 + LNInputs + LNHidden;
  NOutputs := LNOutputs;

  For i := 0 to NUnits do
  begin
    Outputs[i] := 0.0;
    ErrorSums[i] := 0.0;
    Errors[i] := 0.0;
    NConnections[i] := 0;
  end;

  Outputs[0] := 1.0; // Das Bias Neuron

end;

// ------------------------------------------------------------------------------

Function Random_Weight(Range: Real): Real;
begin
  result := Range * (Random(1000) / 500.0) - Range;
end;

// ------------------------------------------------------------------------------

Procedure TClass_NN.Connect_Layers(Start1, End1, Start2, End2: Integer);
var
  N, i, j, k: Integer;
begin
  Epoch := 0;
  for i := Start2 to End2 do
  begin
    if (NConnections[i] = 0) then
    begin
      NConnections[i] := NConnections[i] + 1;
      Connections[i, 0] := 0;
      Weights[i, 0] := Random_Weight(WeightRange);
      DeltaWeights[i, 0] := 0.0;
      Slopes[i, 0] := 0.0;
      PrevSlopes[i, 0] := 0.0;
      k := 1;
    end
    else
      k := NConnections[i];

    For j := Start1 to End1 do
    begin
      NConnections[i] := NConnections[i] + 1;
      Connections[i, k] := j;
      Weights[i, k] := Random_Weight(WeightRange);
      DeltaWeights[i, k] := 0.0;
      Slopes[i, k] := 0.0;
      PrevSlopes[i, k] := 0.0;
      inc(k);
    end;
  end;

end;

// ------------------------------------------------------------------------------

Procedure TClass_NN.Init_weights;
var
  i, j: Integer;
begin
  Epoch := 0;
  For i := 0 to NUnits - 1 do
    for j := 0 to NConnections[i] - 1 do
    begin
      Weights[i, j] := Random_Weight(WeightRange);
      DeltaWeights[i, j] := 0.0;
      Slopes[i, j] := 0.0;
      PrevSlopes[i, j] := 0.0;
    end
end;

// ------------------------------------------------------------------------------

Procedure TClass_NN.Clear_Slopes;
var
  i, j: Integer;
begin
  for i := FirstHidden to NUnits - 1 do
    For j := 0 to NConnections[i] - 1 do
    begin
      PrevSlopes[i, j] := Slopes[i, j];
      Slopes[i, j] := Decay * Weights[i, j];
    end;
end;

// ------------------------------------------------------------------------------

Function TClass_NN.ACTIVATION(Sum: Real): Real;
Var
  Temp: Real;
begin
  Case Unit_type of
    Sigmoid:
      Begin
        if Sum < -15.0 then
          result := -0.5
        else
          if Sum > 15.0 then
          result := 0.5
        else
          result := 1.0 / (1.0 + exp(-Sum)) - 0.5;
      end;
    AsymSigmoid:
      Begin
        if Sum < -15.0 then
          result := 0.0
        else
          if Sum > 15.0 then
          result := 1.0
        else
          result := 1.0 / (1.0 + exp(-Sum));
      end;
    Gaussian:
      Begin
        Temp := -0.5 * Sum * Sum;
        if Temp < -75 then
          result := 0.0
        else
          result := exp(Temp);
      End;
    VarSigmoid:
      Begin
        if Sum < -15.0 then
          result := SigmoidMin
        else
          if Sum > 15.0 then
          result := SigmoidMax
        else
          result := ((SigmoidMax - SigmoidMin) / (1.0 + exp(-Sum)) + SigmoidMin)

      End;
  end;
end;

// ------------------------------------------------------------------------------

Function TClass_NN.ACTIVATION_PRIME(Value, Sum: Real): Real;
begin
  Case Unit_type of
    Sigmoid:
      result := SigmoidPrimeOffset + (0.25 - Value * Value);
    AsymSigmoid:
      result := SigmoidPrimeOffset + (Value * (1.0 - Value));
    Gaussian:
      result := Sum * (-Value);
    VarSigmoid:
      result := ((Value - SigmoidMin) * (1.0 - (Value - SigmoidMin) / (SigmoidMax - SigmoidMin)));
  end;
end;

// ------------------------------------------------------------------------------

Function TClass_NN.ErrorFun(Desired, Actual: Real): Real;
VAr
  Dif: Real;
begin
  Dif := Desired - Actual;

  if KeepScore = 1 then
  begin
    TotalError := TotalError + Dif * Dif;
    if abs(Dif) >= ScoreThreshold then
      inc(TotalErrorBits);
  end;

  if HyperErr = 0 then
    if (-0.1 < Dif) and (Dif < 0.1) then
      result := 0.0
    else
      result := Dif
  else
  begin
    if Dif < -0.9999999 then
      result := -17.0
    else
      if Dif > 0.9999999 then
      result := 17.0
    else
      result := log10((1.0 + Dif) / (1.0 - Dif));
  end;

end;

// ------------------------------------------------------------------------------

Procedure TClass_NN.Forward_Pass(Input: TNeurons);
var
  i, j: Integer;
  Sum: Real;
begin
  for i := 0 to Ninputs - 1 do
    Outputs[i + 1] := Input[i];  // +1 wg.Bias Neuron

  For j := FirstHidden to NUnits - 1 do
  begin
    Sum := 0.0;
    For i := 0 to NConnections[j] - 1 do
      Sum := Sum + Outputs[Connections[j, i]] * Weights[j, i];

    Sums[j] := Sum;
    Outputs[j] := ACTIVATION(Sum);
  end;
end;

// ------------------------------------------------------------------------------

Procedure TClass_NN.Backward_Pass(Goal: TNeurons);
var
  i, j, Cix: Integer;
begin
  // fülle den Output mit dem zu lernenden Zielvektor....
  // un berechne dabei die Differenz zwischen Zielvektor und den Outputs
  For i := FirstOutput to NUnits - 1 do
    ErrorSums[i] := ErrorFun(Goal[i - FirstOutput], Outputs[i]);

  // ...alle anderen Fehlerfelder werden mit 0 initialisiert
  For i := 0 to FirstOutput - 1 do
    ErrorSums[i] := 0;

  // für alle Neuronen
  For j := NUnits - 1 downto FirstHidden do
  begin
    Errors[j] := ACTIVATION_PRIME(Outputs[j], Sums[j]) * ErrorSums[j];

    For i := 0 to NConnections[j] - 1 do
    begin
      Cix := Connections[j, i];
      ErrorSums[Cix] := ErrorSums[Cix] + (Errors[j] * Weights[j, i]);
      Slopes[j, i] := Slopes[j, i] + (Errors[j] * Outputs[Cix]);
    end;
  end;
end;

// ------------------------------------------------------------------------------

Procedure TClass_NN.UpDate_Weights;
var
  i, j: Integer;
  Next_Step, Shrink_Factor: Real;
begin
  Shrink_Factor := MaxFactor / (1 + MaxFactor);

  For j := FirstHidden to NUnits - 1 do
    for i := 0 to NConnections[j] - 1 do
    begin
      Next_Step := 0.0;

      If DeltaWeights[j, i] > ModeSwitchThreshold then
      begin
        if Slopes[j, i] > 0.0 then
          if SplitEpsilon = 1 then
            Next_Step := Next_Step + (Epsilon * Slopes[j, i] / NConnections[j])
          else
            Next_Step := Next_Step + (Epsilon * Slopes[j, i]);

        If Slopes[j, i] > Shrink_Factor * PrevSlopes[j, i] then
          Next_Step := Next_Step + MaxFactor * DeltaWeights[j, i]
        else
          Next_Step := Next_Step + (Slopes[j, i] / (PrevSlopes[j, i] - Slopes[j, i])) * DeltaWeights[j, i];
      end
      else
        If DeltaWeights[j, i] < -ModeSwitchThreshold then
      Begin
        if Slopes[j, i] < 0.0 then
          if SplitEpsilon = 1 then
            Next_Step := Next_Step + (Epsilon * Slopes[j, i] / NConnections[j])
          else
            Next_Step := Next_Step + (Epsilon * Slopes[j, i]);

        If Slopes[j, i] < Shrink_Factor * PrevSlopes[j, i] then
          Next_Step := Next_Step + MaxFactor * DeltaWeights[j, i]
        else
          Next_Step := Next_Step + (Slopes[j, i] / (PrevSlopes[j, i] - Slopes[j, i])) * DeltaWeights[j, i];
      End
      else
      begin
        inc(DidGradient);
        if SplitEpsilon = 1 then
          Next_Step := Next_Step + (Epsilon * Slopes[j, i] / NConnections[j]) + (Momentum * DeltaWeights[j, i])
        else
          Next_Step := Next_Step + (Epsilon * Slopes[j, i]) + (Momentum * DeltaWeights[j, i]);
      end;

      DeltaWeights[j, i] := Next_Step;
      Weights[j, i] := Weights[j, i] + Next_Step;

    end;
end;


// ------------------------------------------------------------------------------

Procedure TClass_NN.BackPropUpDate_Weights;
var
  i, j: Integer;
begin
  For j := FirstHidden to NUnits - 1 do
    for i := 0 to NConnections[j] - 1 do
    begin
      DeltaWeights[j, i] := (Epsilon * Slopes[j, i]) + (Momentum * DeltaWeights[j, i]);
      Weights[j, i] := Weights[j, i] + DeltaWeights[j, i];
    end;

end;

// ------------------------------------------------------------------------------


// ------------------------------------------------------------------------------

Procedure TClass_NN.Train_One_epoch;
var
  i, j: Integer;
  TI: TNeurons;
begin
  Clear_Slopes;
  for i := 0 to NTrainingPatterns - 1 do
  begin
    if InpRandom <> 0.0 then
    begin
      TI := TrainingInputs[i];
      for j := 0 to Ninputs - 1 do
        TI[j] := TI[j] + (InpRandom / 2) * Random(100) - (InpRandom / 2);
      Forward_Pass(TI);
    end
    else
      Forward_Pass(TrainingInputs[i]);

    Backward_Pass(TrainingOutputs[i]);
  end;

  if KindOfOpt = QuickProp then
    UpDate_Weights
  else
    BackPropUpDate_Weights;

  inc(Epoch);
end;

// ------------------------------------------------------------------------------

Procedure TClass_NN.Train(Times: Integer; Monitor: TStrings);
var
  i: Integer;
Begin
  For i := 1 to Times - 1 do
    Train_One_epoch;

  DidGradient := 0;
  KeepScore := 1;
  TotalError := 0;
  TotalErrorBits := 0;

  Train_One_epoch;

  KeepScore := 0;

  if Monitor <> nil then
  begin
    Monitor.add('Bits Wrong  : ' + FloatToFix(TotalErrorBits));
    Monitor.add('Total Error : ' + FloatToFix(TotalError));
    Monitor.add('# Gradient  : ' + FloatToFix(DidGradient));
    Monitor.add('Epoche      : ' + inttostr(Epoch));
    Monitor.add('Epsilon     : ' + FloatToFix(Epsilon));
    Monitor.add('Decay       : ' + FloatToFix(Decay));
    Monitor.add('Momentum    : ' + FloatToFix(Momentum));
  end;

end;

// ------------------------------------------------------------------------------

Procedure TClass_NN.RunTests(Monitor: TStrings);
var
  i, j: Integer;
begin

  for i := 1 to TestNr do
  begin
    Forward_Pass(TestInputs[i - 1]);
    for j := 0 to NOutputs - 1 do
      Monitor.add('Test' + inttostr(i) + ' : ' + FloatToFix(Outputs[FirstOutput + j]));
  end;
end;

// ------------------------------------------------------------------------------
function TClass_NN.ReadScript(Script, Monitor: TStrings): Boolean;
VAr
  inp, hid, outp: Integer;
  Bef, S, s1: String;
  NetDef: Boolean;
  Start1, End1,
    Start2, End2, tp, j: Integer;
  r: Real;
  Input: TNeurons;
  Zeile: Integer;

  function Parse(var S: String): String;
  var
    ix: Integer;

    Procedure Trim(Var S: String);
    begin
      while (S <> '') and (S[1] = ' ') do
        delete(S, 1, 1);
    end;

    procedure Nextline;
    begin
      Trim(S);
      while (Zeile <= Script.count - 1) and (S = '') do
      begin
        inc(Zeile);
        S := Script.Strings[Zeile];
        Trim(S);
      end;
    end;

  begin

    Nextline;

    ix := pos(' ', S);
    if (ix <> 0) and (S <> '') then
    begin
      result := Uppercase(copy(S, 1, ix - 1));
      delete(S, 1, ix);
    end
    else
    begin
      result := Uppercase(S);
      S := '';
    end;
  end;

Begin
  try
    NetDef := False;
    S := '';
    tp := 0;
    TestNr := 0;
    InpRandom := 0.0;

    Zeile := 0;
    S := Script.Strings[Zeile];

    while Zeile <= Script.count - 1 do
    begin
      Bef := Parse(S);

      if Bef = 'NAME' then
        S := ''
      else
        if Bef = '#' then
        S := ''
      else
        if Bef = 'INPUTS' then
        inp := strtoint(Parse(S))
      else
        if Bef = 'HIDDEN' then
        hid := strtoint(Parse(S))
      else
        if Bef = 'OUTPUTS' then
        outp := strtoint(Parse(S))
      else
        if Bef = 'LEARNING' then
        KindOfOpt := Byte(Parse(S)[1] <> 'Q')
      else

        if Bef = 'DECAY' then
        Decay := strtoFloat(Parse(S))
      else
        if Bef = 'MOMENTUM' then
        Momentum := strtoFloat(Parse(S))
      else
        if Bef = 'EPSILON' then
        Epsilon := strtoFloat(Parse(S))
      else
        if Bef = 'SIGMOIDMIN' then
        SigmoidMin := strtoFloat(Parse(S))
      else
        if Bef = 'SIGMOIDMAX' then
        SigmoidMax := strtoFloat(Parse(S))
      else
        if Bef = 'SPLITEPSILON' then
        SplitEpsilon := strtoint(Parse(S))
      else
        if Bef = 'RANDOM' then
        InpRandom := strtoFloat(Parse(S))
      else

        if Bef = 'TYPE' then
      begin
        s1 := Parse(S);

        case s1[1] of
          'S':
            Unit_type := Sigmoid;
          'A':
            Unit_type := AsymSigmoid;
          'G':
            Unit_type := Gaussian;
          'V':
            Unit_type := VarSigmoid;
        end;
      end
      else
        if Bef = 'CONNECT' then
      begin
        if not NetDef then
        begin
          NetDef := True;

          if (inp > N) or (hid > N) or (outp > N) then
          begin
            // Showmessage('Netz nicht definierbar !!!');
            exit;
          end;

          Randomize;
          Init_weights;

          Build_Data_Structures(inp, hid, outp);
        end;

        Start1 := strtoint(Parse(S));
        End1 := strtoint(Parse(S));
        Start2 := strtoint(Parse(S));
        End2 := strtoint(Parse(S));

        if (Start1 > NUnits) or
          (Start2 > NUnits) or
          (End1 > NUnits) or
          (End2 > NUnits) then
        begin
          // Showmessage('Verbindung nicht definierbar !!!');
          exit;
        end;

        Connect_Layers(Start1, End1, Start2, End2);

      end
      else
        if Bef = 'PATTERN' then
      Begin
        inc(tp);
        for j := 0 to Ninputs - 1 do
          TrainingInputs[tp - 1, j] := strtoFloat(Parse(S));

        for j := 0 to NOutputs - 1 do
          TrainingOutputs[tp - 1, j] := strtoFloat(Parse(S));

        NTrainingPatterns := tp;
      end
      else
        if Bef = 'TRAINING' then
      begin
        Train(strtoint(Parse(S)), Monitor);
      end
      else
        if Bef = 'TEST' then
      Begin
        inc(TestNr);
        for j := 0 to Ninputs - 1 do
          TestInputs[TestNr - 1, j] := strtoFloat(Parse(S));

        Forward_Pass(TestInputs[TestNr - 1]);

        for j := 0 to NOutputs - 1 do
          Monitor.add('Test' + inttostr(TestNr) + ' : ' + FloatToFix(Outputs[FirstOutput + j]));

      end
      else
        if (Bef <> '') and (Bef <> ' ') then
      Begin
        // Showmessage(Bef+' ist nicht bekannt !!');
        exit;
      end;

    end; // of While

  Except
    // showmessage('Es ist ein Fehler aufgetreten !! Zeile :'+inttostr(Zeile+1));
  end;

end;

end.
