Unit uClass_Imaging;

Interface

Uses
  SysUtils,
  Types,
  Classes,
  Windows,
  Dialogs,
  Math,
  graphics,
  uClasses_Types;

Const
  c_iMaxLabels = 20;
  c_iMaxDetails = 100;
  c_MaxImagesTrain = 60000;
  c_MaxImagesTest = 1000;
  c_ImageW = 32;
  c_ImageH = 32;
  c_ImageSize = c_ImageW * c_ImageH * 3;
  c_MaxImageBlock = 5;

Type
  TCifarType = (Cifar10, Cifar100);

  TCifarImage = Record
    _Type: TCifarType;
    Group: Byte;
    Group_Name: String;
    Detail: Byte;
    Detail_Name: String;

    PicVolume: TVolume;
  End;

  TCifarImages = Array [0 .. c_MaxImagesTrain - 1] Of TCifarImage;

  // ============================================================================
  // TClass_Imaging
  // ============================================================================
  TClass_Imaging = Class
  private
    TrainStream: TFileStream;
    TestStream: TFileStream;
    TrainBuffer, TestBuffer: Pointer;

    Function GetImageVol(Buffer: Pointer; iImageCount: Integer;
      iMaxImages: Integer): TCifarImage;
    Procedure ADDImageData(Stream: TFileStream; CifarType: TCifarType;
      Var ImageData: TCifarImages; Var iImageCount: Integer);

  public
    _TrainData: TCifarImages;
    _TestData: TCifarImages;
    iImageCount_TrainData: Integer;
    iImageCount_TestData: Integer;
    bCategoriesLoaded: Boolean;

    CifarType: TCifarType;

    sLabelTexts: Array [0 .. c_iMaxLabels] Of String;
    sDetailTexts: Array [0 .. c_iMaxDetails] Of String;

    Constructor create;
    Destructor destroy; override;
    Procedure Clear;

    Procedure LoadCategories(sLabelFN: String; sDetailFN: String);
    // LoadCifar10
    // DATA: 10000 x 32x32Pixel Pictures with
    // first byte expresses the category (0..9)
    // following 3072 Bytes are raw 1024Pixel (RGB) of the picture
    // Filesize: 10000 x 3073 Bytes
    // Label: Category text 0..9
    Procedure LoadCifar_ADDTrainData(sPictureFN: String; CifarType: TCifarType);
    Procedure LoadCifar_ADDTestData(sPictureFN: String; CifarType: TCifarType);

    // LoadCifar100
    // DATA: 10000 x 32x32Pixel Pictures with
    // first byte expresses the superclass (0..19)
    // second byte expresses the class (0..99)
    // following 3072 Bytes are raw 1024Pixel (RGB) of the picture
    //
    // Label: Category text 0..9
    Procedure LoadCifar100_ADDTrainData(sPictureFN: String);
    Procedure LoadCifar100_ADDTestData(sPictureFN: String);

    Procedure StartTrainData(sPictureFN: String);
    Procedure StartTestData(sPictureFN: String);

    Function GetTrainVol(iImageCount: Integer): TCifarImage;
    Function GetTestVol(iImageCount: Integer): TCifarImage;

    Procedure EndTrainData;
    Procedure EndTestData;

    /// /////////////////////////

    Procedure vol_to_bmpCol(v: TVolume; Var bmp: TBitmap; bGrad: Boolean);
    Procedure vol_to_bmpSW(v: TVolume; Var bmp: TBitmap; bGrad: Boolean;
      iDepth: Integer);
    Procedure vol_to_bmp(v: TVolume; Var bmp: TBitmap; bGrad: Boolean);

    Function bmp_to_vol(bmp: TBitmap; convert_grayscale: Boolean): TVolume;
  End;

Implementation

// =============================================================================
//
// Method:  LoadCifar100
// Author:  Marcus Höller-Schlieper
// Date  :  21.04.2017
//
// LoadCifar10
// DATA: 10000 x 32x32Pixel Pictures with
// first byte expresses the category (0..9)
// following 3072 Bytes are raw 1024Pixel (RGB) of the picture
//
// Label: Category text 0..9
// =============================================================================

Procedure TClass_Imaging.Clear;
Var
  i: Integer;
Begin
  For i := 0 To self.iImageCount_TrainData - 1 Do
    _TrainData[i].PicVolume.Free;

  For i := 0 To self.iImageCount_TestData - 1 Do
    _TestData[i].PicVolume.Free;

  iImageCount_TrainData := 0;
  iImageCount_TestData := 0
End;

// ==============================================================================
// Method     :
// Decription :
// Autor      : Marcus Höller-Schlieper
// Date       : 22.04.2017
// ==============================================================================

Constructor TClass_Imaging.create;
Begin
  Clear;

  bCategoriesLoaded := False;
End;

// ==============================================================================
// Method     :
// Decription :
// Autor      : Marcus Höller-Schlieper
// Date       : 22.04.2017
// ==============================================================================

Destructor TClass_Imaging.destroy;
Begin
  Clear;

  EndTrainData;
  EndTestData;

  Inherited;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TClass_Imaging.ADDImageData(Stream: TFileStream;
  CifarType: TCifarType; Var ImageData: TCifarImages; Var iImageCount: Integer);
Var
  x, y: Integer;
  RawData: Array [0 .. c_ImageSize - 1] Of Byte; // the first byte is the
Begin
  Try
    If iImageCount < c_MaxImagesTrain - 1 Then
    Begin
      Repeat

        // reading then category Byte
        Stream.ReadBuffer(ImageData[iImageCount].Group, sizeof(Byte));
        // Kategorie 1
        ImageData[iImageCount].Group_Name :=
          sLabelTexts[ImageData[iImageCount].Group];

        If CifarType = Cifar100 Then // Cifar100 hat noch eine 2.Kategorie!
        Begin
          Stream.ReadBuffer(ImageData[iImageCount].Detail, sizeof(Byte));
          // Kategorie 2
          ImageData[iImageCount].Detail_Name :=
            sDetailTexts[ImageData[iImageCount].Detail];
        End;

        // reading the picture information
        Stream.ReadBuffer(RawData, c_ImageSize); // Rohdaten
        ImageData[iImageCount].PicVolume :=
          TVolume.create(c_ImageW, c_ImageH, 3);

        // BW the coloured pictrure and
        // normalize the picture information 0..1
        For x := 0 To c_ImageH - 1 Do
          For y := 0 To c_ImageW - 1 Do
          Begin
            ImageData[iImageCount].PicVolume.setVal(x, y, 0,
              (RawData[y * 32 + 0000 + x] / 255) - 0.5);
            ImageData[iImageCount].PicVolume.setVal(x, y, 1,
              (RawData[y * 32 + 1024 + x] / 255) - 0.5);
            ImageData[iImageCount].PicVolume.setVal(x, y, 2,
              (RawData[y * 32 + 2048 + x] / 255) - 0.5);
          End;

        iImageCount := iImageCount + 1;
      Until (Stream.Position >= Stream.Size) Or
        (iImageCount >= c_MaxImagesTrain - 1);
    End;
  Finally
  End;
End;

// ==============================================================================
// Method     :
// Decription :
// Autor      : Marcus Höller-Schlieper
// Date       : 22.04.2017
// ==============================================================================

Procedure TClass_Imaging.LoadCifar_ADDTrainData(sPictureFN: String;
  CifarType: TCifarType);
Var
  Stream: TFileStream;
  fn: TextFile;
  iLine: Integer;
Begin

  If Not bCategoriesLoaded Then
    Showmessage('No Ctegories loaded!!');

  self.CifarType := CifarType;

  Stream := TFileStream.create(sPictureFN, fmOpenRead);
  Try
    Stream.Seek(0, 0);
    ADDImageData(Stream, CifarType, _TrainData, iImageCount_TrainData);
  Finally
    Stream.Free;
  End;
End;

// ==============================================================================
// Method     :
// Decription :
// Autor      : Marcus Höller-Schlieper
// Date       : 22.04.2017
// ==============================================================================

Procedure TClass_Imaging.LoadCifar_ADDTestData(sPictureFN: String;
  CifarType: TCifarType);
Var
  Stream: TFileStream;
Begin
  If Not bCategoriesLoaded Then
    Showmessage('No Ctegories loaded!!');

  self.CifarType := CifarType;

  Stream := TFileStream.create(sPictureFN, fmOpenRead);
  Try
    Stream.Seek(0, 0);
    ADDImageData(Stream, CifarType, _TestData, iImageCount_TestData);
  Finally
    Stream.Free;
  End;
End;

// =============================================================================
//
// Method:  LoadCifar100
// Author:  Marcus Höller-Schlieper
// Date  :  21.04.2017
//
// DATA: 10000 x 32x32Pixel Pictures with
// first byte expresses the superclass (0..19)
// second byte expresses the class (0..99)
// following 3072 Bytes are raw 1024Pixel (RGB) of the picture
//
// Label: Category text 0..9
// =============================================================================

Procedure TClass_Imaging.LoadCifar100_ADDTrainData(sPictureFN: String);
Var
  Stream: TFileStream;
Begin
  If Not bCategoriesLoaded Then
    Showmessage('No Ctegories loaded!!');

  CifarType := Cifar100;

  Stream := TFileStream.create(sPictureFN, fmOpenRead);
  Try
    Stream.Seek(0, 0);
    ADDImageData(Stream, Cifar100, _TrainData, iImageCount_TrainData);
  Finally
    Stream.Free;
  End;

End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TClass_Imaging.LoadCifar100_ADDTestData(sPictureFN: String);
Var
  Stream: TFileStream;
  fn: TextFile;
  iLine: Integer;
Begin
  If Not bCategoriesLoaded Then
    Showmessage('No Ctegories loaded!!');

  CifarType := Cifar100;

  Stream := TFileStream.create(sPictureFN, fmOpenRead);
  Try
    Stream.Seek(0, 0);
    ADDImageData(Stream, Cifar100, _TestData, iImageCount_TestData);
  Finally
    Stream.Free;
  End;

End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Function TClass_Imaging.bmp_to_vol(bmp: TBitmap;
  convert_grayscale: Boolean): TVolume;
Var
  x, x1: TVolume;
  w, h, i, j: Integer;
  p: TByteArray;
Begin
  {
    // prepare the input: get pixels and normalize them
    w := bmp.width;
    h := bmp.height;

    if (convert_grayscale) then
    x := TVolume.create(w, h, 1, 0.0)
    else
    x := TVolume.create(w, h, 4, 0.0); // input volume (image)

    for i := 0 to bmp.width * bmp.height - 1 do
    begin
    if (convert_grayscale) then
    begin
    // Grauwertumwandlung....
    x.w[i * 4 + 0] :=
    (
    TByteArray(p.Data^)[i * p.BytesPerPixel + 0] * 0.299 + // R
    TByteArray(p.Data^)[i * p.BytesPerPixel + 1] * 0.587 + // G
    TByteArray(p.Data^)[i * p.BytesPerPixel + 2] * 0.114 // B
    ) / 255.0 - 0.5; // normalisiere die Pixel auf [-0.5, 0.5]
    end
    else
    begin
    x.w[i * 4 + 0] := (TByteArray(p.Data^)[i * p.BytesPerPixel + 0] / 255.0 - 0.5); // R normalize image pixels to [-0.5, 0.5]
    x.w[i * 4 + 1] := (TByteArray(p.Data^)[i * p.BytesPerPixel + 1] / 255.0 - 0.5); // G normalize image pixels to [-0.5, 0.5]
    x.w[i * 4 + 2] := (TByteArray(p.Data^)[i * p.BytesPerPixel + 2] / 255.0 - 0.5); // B normalize image pixels to [-0.5, 0.5]
    x.w[i * 4 + 3] := (TByteArray(p.Data^)[i * p.BytesPerPixel + 3] / 255.0 - 0.5); // A normalize image pixels to [-0.5, 0.5]
    end;
    end;

    result := x; }
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TClass_Imaging.vol_to_bmp(v: TVolume; Var bmp: TBitmap;
  bGrad: Boolean);
Var
  x, ix, y: Integer;
  w, h, i, j, d: Integer;
  p: ^TByteArray;
  dMin, dMax, dValue: Double;
  bVal: Byte;
  mm: TMinMax;

Begin
  Try
    bmp.width := v.sx;
    bmp.height := v.sy;
    bmp.PixelFormat := pf32Bit;

    If bGrad Then
      mm := Global.maxmin(v.dw)
    Else
      mm := Global.maxmin(v.w);

    If mm.dv <> 0 Then

      For y := 0 To v.sy - 1 Do
      Begin
        p := bmp.ScanLine[y];
        For x := 0 To v.sx - 1 Do
        Begin
          For d := 0 To 2 Do
          Begin
            If bGrad Then
              p[x * 4 + 2 - d] :=
                Byte(round(((v.get_Grad(x, y, d) - mm.minv) / mm.dv) * 255))
            Else
              p[x * 4 + 2 - d] :=
                Byte(round(((v.get(x, y, d) - mm.minv) / mm.dv) * 255));
          End;
          p[x * 4 + 3] := 0;

        End
      End
    else
    begin
      bmp.Canvas.Brush.Color := clblack;
      bmp.Canvas.FillRect(Rect(0, 0, bmp.width, bmp.height))
    end;
  Except

  End;
  bmp.Modified := True;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TClass_Imaging.vol_to_bmpCol(v: TVolume; Var bmp: TBitmap;
  bGrad: Boolean);
Var
  x, ix, y: Integer;
  w, h, i, j, d: Integer;
  p: ^TByteArray;
  dMin, dMax, dValue: Double;
  bVal: Byte;
  mm: TMinMax;
Begin
  bmp.width := v.sx;
  bmp.height := v.sy;
  bmp.PixelFormat := pf32Bit;

  If bGrad Then
    mm := Global.maxmin(v.dw)
  Else
    mm := Global.maxmin(v.w);

  If mm.dv <> 0 Then

    For y := 0 To v.sy - 1 Do
    Begin
      p := bmp.ScanLine[y];
      For x := 0 To v.sx - 1 Do
      Begin
        For d := 0 To 2 Do
        Begin
          If bGrad Then
            p[x * 4 + 2 - d] :=
              Byte(min(255, max(0, round((v.get_Grad(x, y, d) - mm.minv) /
              mm.dv * 255))))
          Else
            p[x * 4 + 2 - d] :=
              Byte(min(255, max(0, round((v.get(x, y, d) - mm.minv) / mm.dv
              * 255))));
        End;
        p[x * 4 + 3] := 0;
      End
    End
  else
  begin
    bmp.Canvas.Brush.Color := clblack;
    bmp.Canvas.FillRect(Rect(0, 0, bmp.width, bmp.height));
  end;

  bmp.Modified := True;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TClass_Imaging.vol_to_bmpSW(v: TVolume; Var bmp: TBitmap;
  bGrad: Boolean; iDepth: Integer);
Var
  x, ix, y: Integer;
  w, h, i, j, d: Integer;
  p: ^TByteArray;
  dValue: Double;
  bVal: Byte;
  mm: TMinMax;
Begin
  bmp.width := v.sx;
  bmp.height := v.sy;
  bmp.PixelFormat := pf32Bit;

  If bGrad Then
    mm := Global.maxmin(v.dw)
  Else
    mm := Global.maxmin(v.w);

  If mm.dv <> 0 Then
    For y := 0 To v.sy - 1 Do
    Begin
      p := bmp.ScanLine[y];
      For x := 0 To v.sx - 1 Do
      Begin
        If bGrad Then
          bVal := Byte
            (min(255, max(0, round(((v.get_Grad(x, y, iDepth) - mm.minv) /
            mm.dv) * 255))))
        Else
          bVal := Byte
            (min(255, max(0, round(((v.get(x, y, iDepth) - mm.minv) / mm.dv)
            * 255))));

        p[x * 4 + 0] := bVal;
        p[x * 4 + 1] := bVal;
        p[x * 4 + 2] := bVal;
        p[x * 4 + 3] := 255;

      End
    End
  else
  begin
    bmp.Canvas.Brush.Color := clblack;
    bmp.Canvas.FillRect(Rect(0, 0, bmp.width, bmp.height));
  end;

  bmp.Modified := True;
End;

// ==============================================================================
// Methode:
// Datum  : 07.07.2017
// Autor  : M.Höller-Schlieper
//
// ==============================================================================

Procedure TClass_Imaging.LoadCategories(sLabelFN, sDetailFN: String);
Var
  fn: TextFile;
  iLine: Integer;
Begin

  If fileexists(sLabelFN) Then
  Begin
    AssignFile(fn, sLabelFN);
    Reset(fn);
    iLine := 0;
    While Not eof(fn) Do
    Begin
      readln(fn, sLabelTexts[iLine]);
      iLine := iLine + 1;
    End;
    closeFile(fn);

    bCategoriesLoaded := True;
  End;

  If fileexists(sDetailFN) Then
  Begin
    AssignFile(fn, sDetailFN);
    Reset(fn);
    iLine := 0;
    While Not eof(fn) Do
    Begin
      readln(fn, sDetailTexts[iLine]);
      iLine := iLine + 1;
    End;
    closeFile(fn);

    bCategoriesLoaded := True;
  End;

End;

Procedure TClass_Imaging.StartTrainData(sPictureFN: String);
Var
  Stream: TFileStream;
Begin
  If Not bCategoriesLoaded Then
    Showmessage('No Ctegories loaded!!');

  TrainStream := TFileStream.create(sPictureFN, fmOpenRead);
  iImageCount_TrainData := TrainStream.Size Div (c_ImageSize + 2);

  Getmem(TrainBuffer, TrainStream.Size);
  TrainStream.read(TrainBuffer^, TrainStream.Size);

  FreeandNil(TrainStream);

End;

Procedure TClass_Imaging.StartTestData(sPictureFN: String);
Var
  Stream: TFileStream;
Begin
  If Not bCategoriesLoaded Then
    Showmessage('No Ctegories loaded!!');

  TestStream := TFileStream.create(sPictureFN, fmOpenRead);

  Getmem(TestBuffer, TestStream.Size);
  TestStream.read(TestBuffer^, TestStream.Size);

  FreeandNil(TestStream);

End;

Procedure TClass_Imaging.EndTestData;
Begin
  // FreeandNil(TestStream);
  Freemem(TestBuffer);
End;

Procedure TClass_Imaging.EndTrainData;
Begin
  // FreeandNil(TrainStream);

  Freemem(TrainBuffer);
End;

Function TClass_Imaging.GetImageVol(Buffer: Pointer; iImageCount: Integer;
  iMaxImages: Integer): TCifarImage;
Var
  x, y: Integer;
  RawData: Array [0 .. c_ImageSize - 1 + 2] Of Byte; // the first byte is the

  ptr: Pointer;
Begin
  If Not bCategoriesLoaded Then
    Showmessage('No Ctegories loaded!!');

  Try
    If iImageCount < iMaxImages - 1 Then
    Begin

      If CifarType = Cifar100 Then // Cifar100 hat noch eine 2.Kategorie!
      begin
        // Kat 1
        ptr := Pointer(Integer(Buffer) + (c_ImageSize + 2) * iImageCount);
        move(ptr^, RawData[0], c_ImageSize + 2);

        Result.Group := RawData[0];
        Result.Group_Name := sLabelTexts[Result.Group];

        // Kat 2

        Result.Detail := RawData[1]; // Kategorie 2
        Result.Detail_Name := sDetailTexts[Result.Detail];
      end
      else
      begin
        // Kat 1
        ptr := Pointer(Integer(Buffer) + (c_ImageSize + 1) * iImageCount);
        move(ptr^, RawData[0], c_ImageSize + 1);

        Result.Group := RawData[0];
        Result.Group_Name := sLabelTexts[Result.Group];

        // Kat 2
        Result.Detail := RawData[0]; // Kategorie 2
        Result.Detail_Name := sLabelTexts[Result.Group];
      end;

      // Buffer
      // reading the picture information
      Result.PicVolume := TVolume.create(c_ImageW, c_ImageH, 3);

      // BW the coloured pictrure and
      // normalize the picture information 0..1
      For x := 0 To c_ImageH - 1 Do
        For y := 0 To c_ImageW - 1 Do
        Begin
          Result.PicVolume.setVal(x, y, 0,
            (RawData[y * 32 + 0000 + x + 2] / 255) - 0.5);
          Result.PicVolume.setVal(x, y, 1,
            (RawData[y * 32 + 1024 + x + 2] / 255) - 0.5);
          Result.PicVolume.setVal(x, y, 2,
            (RawData[y * 32 + 2048 + x + 2] / 255) - 0.5);
        End;
    End;
  Finally
  End;
End;

Function TClass_Imaging.GetTestVol(iImageCount: Integer): TCifarImage;
Begin
  Result := GetImageVol(TestBuffer, iImageCount, c_MaxImagesTest)
End;

Function TClass_Imaging.GetTrainVol(iImageCount: Integer): TCifarImage;
Begin
  Result := GetImageVol(TrainBuffer, iImageCount, c_MaxImagesTrain)
End;

End.
