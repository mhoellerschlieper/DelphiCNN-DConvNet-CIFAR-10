Unit uFunctions;

Interface

Uses Windows,
  Messages,
  SysUtils,
  Classes,
  Math,
  uClasses_Types;

Function CreateOpt_Input(sName: String;
  out_sx, out_sy, out_depth: Integer): TOpt;
Function CreateOpt_Conv(sName: String; Filter_Size, Filter_Count, Stride,
  pad: Integer; activation: String): TOpt;
Function CreateOpt_Pool(sName: String; Size, Stride: Integer): TOpt;
Function CreateOpt_Dropout(sName: String; drop_prob: Double): TOpt;
Function CreateOpt_FullyConnected(sName: String; NumNeurons: Integer;
  activation: String): TOpt;

Function CreateOpt_Hidden(sName: String; sType: String; NumNeurons: Integer;
  activation: String): TOpt;

Function augment(v: TVolume; crop, dx, dy: Integer; fliplr: Boolean): TVolume;
Function tanh(x: Double): Double;

Implementation

// ==============================================================================
// Zusatzfunktionen
// ==============================================================================

Function CreateOpt_Input(sName: String;
  out_sx, out_sy, out_depth: Integer): TOpt;
Var
  opt: TOpt;
Begin
  opt := TOpt.create;
  opt.sType := 'input';
  opt.out_sx := out_sx;
  opt.out_sy := out_sy;
  opt.out_depth := out_depth;
  opt.sName := sName;
  result := opt;
End;

Function CreateOpt_FullyConnected(sName: String; NumNeurons: Integer;
  activation: String): TOpt;
Var
  opt: TOpt;
Begin
  opt := TOpt.create;
  opt.sType := 'fc';
  opt.num_neurons := NumNeurons;
  opt.num_classes := NumNeurons;
  opt.activation := activation;
  opt.bias_pref := 0.1;
  opt.sName := sName;
  result := opt;
End;

Function CreateOpt_Hidden(sName: String; sType: String; NumNeurons: Integer;
  activation: String): TOpt;
Var
  opt: TOpt;
Begin
  opt := TOpt.create;
  opt.sType := sType;
  opt.num_neurons := NumNeurons;
  opt.num_classes := NumNeurons;
  opt.activation := activation;
  opt.bias_pref := 0.1;
  opt.sName := sName;
  result := opt;
End;

Function CreateOpt_Conv(sName: String; Filter_Size, Filter_Count, Stride,
  pad: Integer; activation: String): TOpt;
Var
  opt: TOpt;
Begin
  opt := TOpt.create;
  opt.sType := 'conv';
  opt.Filter_sx := Filter_Size;
  opt.Filter_sy := Filter_Size;
  opt.Filters := Filter_Count;
  opt.Stride := Stride;
  opt.pad := pad;
  opt.activation := activation;
  opt.bias_pref := 0.1;
  opt.sName := sName;
  result := opt;
End;

Function CreateOpt_Pool(sName: String; Size, Stride: Integer): TOpt;
Var
  opt: TOpt;
Begin
  opt := TOpt.create;
  opt.Filter_sx := Size;
  opt.Filter_sy := Size;
  opt.sType := 'pool';
  opt.Stride := Stride;
  opt.bias_pref := 0.1;
  opt.sName := sName;
  result := opt;
End;

Function CreateOpt_Dropout(sName: String; drop_prob: Double): TOpt;
Var
  opt: TOpt;
Begin
  opt := TOpt.create;
  opt.sType := 'dropout';
  opt.drop_prob := drop_prob;
  opt.sName := sName;
  result := opt;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function tanh(x: Double): Double;
Var
  y: Double;
Begin
  y := exp(2 * x);
  result := (y - 1) / (y + 1);
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function augment(v: TVolume; crop, dx, dy: Integer; fliplr: Boolean): TVolume;
Var
  w, W2: TVolume;
  x, y, d: Integer;
Begin
  // note assumes square outputs of size crop x crop
  // if(typeof(fliplr)==='undefined') var fliplr = false;
  // if(typeof(dx)==='undefined') var dx = global.randi(0, V.sx - crop);
  // if(typeof(dy)==='undefined') var dy = global.randi(0, V.sy - crop);

  // randomly sample a crop in the input volume

  If (crop <> v.sx) Or (dx <> 0) Or (dy <> 0) Then
  Begin
    w := TVolume.create(crop, crop, v.depth, 0.0);
    For x := 0 To crop - 1 Do
    Begin
      For y := 0 To crop - 1 Do
      Begin
        If (x + dx < 0) Or (x + dx >= v.sx) Or (y + dy < 0) Or
          (y + dy >= v.sy) Then
          continue; // oob
        For d := 0 To v.depth - 1 Do
        Begin
          w.setVal(x, y, d, v.get(x + dx, y + dy, d)); // copy data over
        End
      End
    End
  End
  Else
  Begin
    w := v;
  End;

  If (fliplr) Then
  Begin
    // flip volume horziontally
    W2 := w.cloneAndZero();
    For x := 0 To w.sx - 1 Do
    Begin
      For y := 0 To w.sy - 1 Do
      Begin
        For d := 0 To w.depth - 1 Do
        Begin
          W2.setVal(x, y, d, w.get(w.sx - x - 1, y, d)); // copy data over
        End;
      End;
    End;
    w := W2; // swap
  End;
  result := w;
End;

End.
