Unit uClasses_Types;

Interface

Uses
  Windows,
  Messages,
  SysUtils,
  Classes,
  Math
  ;

Const
  c_Undefined       = -1;

Type
  { ============================================================================= }
  TPArrayDouble = Array[0..0] Of Double;
  TPArrayInteger = Array[0..0] Of integer;

  TMyArray = Class
  Private
  Public
    Buffer: Pointer;
    length: Integer;
    Constructor create(Len: Integer);
    Destructor destroy; Override;

    Procedure FillZero;
  End;

  { ============================================================================= }
  TVolume = Class
  Public
    n: Integer;
    sx, sy, depth: Integer;

    w: TMyArray;
    dw: TMyArray;

    Constructor create(_sx, _sy, _depth: Integer; _c: Double = c_Undefined); Overload;
    Constructor create(_StartInitValues: Array Of Double); Overload;
    Destructor destroy; Override;

    Procedure setVal(_x, _y, _d: Integer; _v: Double);
    Function get(_x, _y, _d: Integer): Double;
    Procedure add(_x, _y, _d: Integer; _v: Double);
    Procedure add_grad(_x, _y, _d: Integer; _v: Double);
    Function get_grad(_x, _y, _d: Integer): Double;
    Function set_grad(_x, _y, _d: Integer; _v: Double): Double;

    Function cloneAndZero: TVolume;
    Function clone: TVolume;
    Procedure Copy(Var v: TVolume);

    Procedure addFrom(v: TVolume);
    Procedure addFromScaled(v: TVolume; a: Double);
    Procedure setConst(a: Double);

  End;

  TPVolume = Array[0..0] Of TVolume;

  TFilter = Class
  Public
    Buffer: ^TPVolume;
    length: Integer;
    Constructor create(Len: Integer);
    Destructor destroy; Override;
  End;

  { ============================================================================= }
  TOpt = Class
    sType: String;
    sName: String;

    filters: Integer;

    Filter_sx: Integer;
    Filter_sy: Integer;
    stride: Integer;
    pad: Integer;

    in_depth: Integer;
    in_sx: Integer;
    in_sy: Integer;

    out_depth: Integer;
    depth: Integer;

    out_sx: Integer;
    out_sy: Integer;

    width: Integer;
    height: Integer;

    num_neurons: Integer;
    num_classes: Integer;

    group_size: Integer;

    drop_prob: Double;

    l1_decay_mul: Double;
    l2_decay_mul: Double;
    bias_pref: Double;

    activation: String;
  End;

  { ============================================================================= }
  TMinMax = Record
    maxi,
      maxv,
      mini,
      minv,
      dv: Double;
  End;

  { ============================================================================= }
  TGlobal = Class
    return_v: Boolean;
    v_val: Double;

    Function gaussRandom(): Double;
    Function randf(a, b: Double): Double;
    Function randi(a, b: Double): Integer;
    Function randn(mu, std: Double): Double;

    Function Zeros(n: Integer): TMyArray;
    Function arrContains(arr: TMyArray; elt: Double): Boolean;
    Function arrUnique(arr: TMyArray): TMyArray;

    Function maxmin(w: TMyArray): TMinMax;
    Function randperm(n: Integer): TMyArray;
    Function weightedSample(lst: TMyArray; probs: TMyArray): Double;
    Function getopt(opt: Array Of variant; field_name: Array Of Const; default_value: Double): Double;
  End;

Var
  Global            : TGlobal;

Implementation

{ TArray }
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Constructor TMyArray.create(Len: Integer);
Begin
  length := Len;
  new(Buffer);
  getmem(Buffer, length * sizeof(Double));
  //Buffer:=FastGetMem(length * sizeof(Double));
  FillZero;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Destructor TMyArray.destroy;
Begin
  If Buffer <> Nil Then
    freemem(Buffer);
  //dispose(Buffer);
  Buffer := Nil;
  Inherited destroy;
End;

Procedure TMyArray.FillZero;
Begin
  fillchar(TPArrayDouble(Buffer^), length * sizeof(Double), 0);
End;

{ vol }
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================
// Vol is the basic building block of all data in a net.
// it is essentially just a 3D volume of numbers, with a
// width (sx), height (sy), and depth (depth).
// it is used to hold data for all filters, all volumes,
// all weights, and also stores all gradients w.r.t.
// the data. c is optionally a value to initialize the volume
// with. If c is missing, fills the Vol with random numbers.

Constructor TVolume.create(_StartInitValues: Array Of Double); // overload;
Var
  scale             : Double;
  i                 : Integer;
Begin
  sx := 1;
  sy := 1;
  depth := high(_StartInitValues) + 1;
  n := round(depth);

  w := Global.Zeros(n);
  dw := Global.Zeros(n);

  // weight normalization is done to equalize the output
  // variance of every neuron, otherwise neurons with a lot
  // of incoming connections have outputs of larger variance

  For i := 0 To n - 1 Do
    TPArrayDouble(w.Buffer^)[i] := _StartInitValues[i];

End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Constructor TVolume.create(_sx, _sy, _depth: Integer; _c: Double = c_Undefined);
Var
  scale             : Double;
  i                 : Integer;
Begin

  sx := _sx;
  sy := _sy;
  depth := _depth;
  n := round(sx * sy * depth);

  w := Global.Zeros(n);
  dw := Global.Zeros(n);

  If _c = c_Undefined Then
    Begin
      // weight normalization is done to equalize the output
      // variance of every neuron, otherwise neurons with a lot
      // of incoming connections have outputs of larger variance
      scale := sqrt(1.0 / (sx * sy * depth));
      For i := 0 To n - 1 Do
        TPArrayDouble(w.Buffer^)[i] := Global.randn(0.0, scale);
    End
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Destructor TVolume.destroy;
Begin
  If assigned(w) Then
    freeandnil(w);
  If assigned(dw) Then
    freeandnil(dw);

  Inherited destroy;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TVolume.get(_x, _y, _d: Integer): Double;
Var
  ix                : Integer;
Begin
  ix := ((sx * _y) + _x) * depth + _d;
  Result := TPArrayDouble(w.Buffer^)[ix];
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TVolume.setVal(_x, _y, _d: Integer; _v: Double);
Var
  ix                : Integer;
Begin
  ix := ((sx * _y) + _x) * depth + _d;
  TPArrayDouble(w.Buffer^)[ix] := _v;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TVolume.add(_x, _y, _d: Integer; _v: Double);
Var
  ix                : Integer;
Begin
  ix := ((sx * _y) + _x) * depth + _d;
  TPArrayDouble(w.Buffer^)[ix] := TPArrayDouble(w.Buffer^)[ix] + _v;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TVolume.get_grad(_x, _y, _d: Integer): Double;
Var
  ix                : Integer;
Begin
  ix := ((sx * _y) + _x) * depth + _d;
  Result := TPArrayDouble(dw.Buffer^)[ix];
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TVolume.set_grad(_x, _y, _d: Integer; _v: Double): Double;
Var
  ix                : Integer;
Begin
  ix := ((sx * _y) + _x) * depth + _d;
  TPArrayDouble(dw.Buffer^)[ix] := _v;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TVolume.add_grad(_x, _y, _d: Integer; _v: Double);
Var
  ix                : Integer;
Begin
  ix := ((sx * _y) + _x) * depth + _d;
  TPArrayDouble(dw.Buffer^)[ix] := TPArrayDouble(dw.Buffer^)[ix] + _v;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TVolume.cloneAndZero: TVolume;
Begin
  Result := TVolume.create(sx, sy, depth, 0);
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TVolume.clone: TVolume;
Var
  v                 : TVolume;
  n, i              : Integer;
Begin
  v := TVolume.create(sx, sy, depth, 0);

  n := w.length;

  move(TPArrayDouble(w.Buffer^)[0], TPArrayDouble(v.w.Buffer^)[0], n * sizeof(Double));
  { for i := 0 to n-1 do
    v.w.Buffer^[i] := w.Buffer^[i]; }

  Result := v;
End;

Procedure TVolume.Copy(Var v: TVolume);
Var
  n, i              : Integer;
Begin
  n := w.length;

  move(TPArrayDouble(v.w.Buffer^)[0], TPArrayDouble(w.Buffer^)[0], n * sizeof(Double));

  { for i := 0 to n-1 do
    v.w.Buffer^[i] := w.Buffer^[i]; }
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TVolume.addFrom(v: TVolume);
Var
  k                 : Integer;
Begin
  For k := 0 To w.length - 1 Do
    TPArrayDouble(w.Buffer^)[k] := TPArrayDouble(w.Buffer^)[k] + TPArrayDouble(v.w.Buffer^)[k];
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TVolume.addFromScaled(v: TVolume; a: Double);
Var
  k                 : Integer;
Begin
  For k := 0 To w.length - 1 Do
    TPArrayDouble(w.Buffer^)[k] := TPArrayDouble(w.Buffer^)[k] + a * TPArrayDouble(v.w.Buffer^)[k];
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TVolume.setConst(a: Double);
Var
  k                 : Integer;
Begin
  For k := 0 To w.length - 1 Do
    TPArrayDouble(w.Buffer^)[k] := a;

End;

{ TGlobal }
// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TGlobal.gaussRandom: Double;
Var
  c, u, v, r        : Double;
Begin
  If (return_v) Then
    Begin
      return_v := false;
      Result := v_val;
    End;
  u := 2 * random - 1;
  v := 2 * random - 1;
  r := u * u + v * v;
  If (r = 0) Or (r > 1) Then
    Begin
      Result := gaussRandom();
      exit;
    End;
  c := sqrt(-2 * Log10(r) / r);
  v_val := v * c;                       // cache this
  return_v := true;
  Result := u * c;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TGlobal.randf(a, b: Double): Double;
Begin
  Result := random * (b - a) + a;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TGlobal.randi(a, b: Double): Integer;
Begin
  Result := Math.floor(random * (b - a) + a);
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TGlobal.randn(mu, std: Double): Double;
Begin
  Result := mu + gaussRandom() * std;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TGlobal.Zeros(n: Integer): TMyArray;
Var
  i                 : Integer;
  arr               : TMyArray;
Begin
  arr := TMyArray.create(n);
  arr.FillZero;
  Result := arr;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TGlobal.arrContains(arr: TMyArray; elt: Double): Boolean;
Var
  i                 : Integer;
Begin
  Result := false;
  For i := 0 To arr.length - 1 Do
    Begin
      If (TPArrayDouble(arr.Buffer^)[i] = elt) Then
        Begin
          Result := true;
          exit;
        End;
    End;

End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TGlobal.arrUnique(arr: TMyArray): TMyArray;
Var
  b                 : TMyArray;
  i, k              : Integer;
Begin
  b := Zeros(arr.length);
  k := 0;
  For i := 0 To arr.length Do
    Begin
      If (Not arrContains(b, TPArrayDouble(arr.Buffer^)[i])) Then
        Begin
          TPArrayDouble(b.Buffer^)[k] := TPArrayDouble(arr.Buffer^)[i];
          k := k + 1;
        End;
      Result := b;
    End;

End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================
// return max and min of a given non-empty array.

Function TGlobal.maxmin(w: TMyArray): TMinMax;
Var
  i                 : Integer;
Begin
  If (w.length = 0) Then
    Begin
      exit;
    End;

  Result.maxv := TPArrayDouble(w.Buffer^)[0];
  Result.minv := TPArrayDouble(w.Buffer^)[0];
  Result.maxi := 0;
  Result.mini := 0;
  For i := 1 To w.length - 1 Do
    Begin
      If (TPArrayDouble(w.Buffer^)[i] > Result.maxv) Then
        Begin
          Result.maxv := TPArrayDouble(w.Buffer^)[i];
          Result.maxi := i;
        End;
      If (TPArrayDouble(w.Buffer^)[i] < Result.minv) Then
        Begin
          Result.minv := TPArrayDouble(w.Buffer^)[i];
          Result.mini := i;
        End;
      Result.dv := Result.maxv - Result.minv;
    End;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================
// create random permutation of numbers, in range [0...n-1]

Function TGlobal.randperm(n: Integer): TMyArray;
Var
  i, j, q           : Integer;
  temp              : Double;
  arr               : TMyArray;
Begin
  i := n;
  j := 0;
  temp := 0;
  arr := TMyArray.create(0);
  For q := 0 To n - 1 Do
    TPArrayDouble(arr.Buffer^)[q] := q;

  While (i <> 0) Do
    Begin
      j := Math.floor(random * (i + 1));
      temp := TPArrayDouble(arr.Buffer^)[i];
      TPArrayDouble(arr.Buffer^)[i] := TPArrayDouble(arr.Buffer^)[j];
      TPArrayDouble(arr.Buffer^)[j] := temp;
      dec(i);
    End;
  Result := arr;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================
// sample from list lst according to probabilities in list probs
// the two lists are of same size, and probs adds up to 1

Function TGlobal.weightedSample(lst: TMyArray; probs: TMyArray): Double;
Var
  p, cumprob        : Double;
  k                 : Integer;
Begin
  p := randf(0, 1.0);
  cumprob := 0.0;
  For k := 0 To lst.length - 1 Do
    Begin
      cumprob := cumprob + TPArrayDouble(probs.Buffer^)[k];

      If (p < cumprob) Then
        Begin
          Result := TPArrayDouble(lst.Buffer^)[k];
          exit;
        End;
    End

End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TGlobal.getopt(opt: Array Of variant; field_name: Array Of Const; default_value: Double): Double;
Begin
  Result := default_value;
End;

{ TFilter }

Constructor TFilter.create(Len: Integer);
Begin
  length := Len;
  getmem(Buffer, length * sizeof(TVolume));
End;

Destructor TFilter.destroy;
Var
  i                 : Integer;
Begin
  Try
    For i := 0 To self.length - 1 Do
      Buffer^[i].Free;

  Finally
    freemem(Buffer);
  End;
  Inherited;
End;

Initialization
  randomize;
  Global := TGlobal.create;

Finalization

  Global.Free;

End.

