object FRMMain: TFRMMain
  Left = 207
  Top = 22
  Caption = 'CNN - M.H'#246'ller-Schlieper 2017'
  ClientHeight = 739
  ClientWidth = 1276
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object imgDebug: TImage
    Left = 857
    Top = 41
    Width = 419
    Height = 679
    Align = alClient
    ExplicitWidth = 427
    ExplicitHeight = 687
  end
  object Panel3: TPanel
    Left = 0
    Top = 0
    Width = 1276
    Height = 41
    Align = alTop
    TabOrder = 0
    object lblRuns: TLabel
      Left = 145
      Top = 8
      Width = 64
      Height = 13
      Caption = 'press start...'
      Color = clBtnFace
      ParentColor = False
    end
    object lblLoss: TLabel
      Left = 145
      Top = 23
      Width = 28
      Height = 13
      Caption = 'lblloss'
      Color = clBtnFace
      ParentColor = False
    end
    object btnStart: TButton
      Left = 8
      Top = 3
      Width = 113
      Height = 33
      Caption = 'Start learning'
      TabOrder = 0
      OnClick = btnStartClick
    end
    object cbDebug: TCheckBox
      Left = 856
      Top = 7
      Width = 51
      Height = 19
      Caption = 'Debug'
      Checked = True
      State = cbChecked
      TabOrder = 1
      OnClick = cbDebugClick
    end
    object cbUseChunk: TCheckBox
      Left = 737
      Top = 7
      Width = 97
      Height = 17
      Caption = 'Use Chunk'
      Checked = True
      State = cbChecked
      TabOrder = 2
      OnClick = cbUseChunkClick
    end
    object cbShowWeights: TCheckBox
      Left = 928
      Top = 7
      Width = 185
      Height = 19
      Caption = 'show weights'
      Checked = True
      State = cbChecked
      TabOrder = 3
      OnClick = cbDebugClick
    end
  end
  object Panel1: TPanel
    Left = 0
    Top = 41
    Width = 857
    Height = 679
    Align = alLeft
    TabOrder = 1
    object Panel2: TPanel
      Left = 1
      Top = 1
      Width = 855
      Height = 677
      Align = alClient
      Color = clMaroon
      ParentBackground = False
      TabOrder = 0
      DesignSize = (
        855
        677)
      object panButtons: TPanel
        Left = 663
        Top = 1
        Width = 191
        Height = 675
        Align = alRight
        BevelOuter = bvNone
        Color = cl3DDkShadow
        ParentBackground = False
        TabOrder = 0
      end
      object btnPrev: TButton
        Left = 216
        Top = 4
        Width = 75
        Height = 25
        Caption = '<'
        TabOrder = 1
        OnClick = btnPrevClick
      end
      object btnNext: TButton
        Left = 296
        Top = 4
        Width = 75
        Height = 25
        Caption = '>'
        TabOrder = 2
        OnClick = btnNextClick
      end
      object btnTest: TButton
        Left = 8
        Top = 4
        Width = 75
        Height = 25
        Caption = 'Test'
        TabOrder = 3
        OnClick = btnTestClick
      end
      object Chart1: TChart
        Left = 7
        Top = 467
        Width = 650
        Height = 201
        BackWall.Brush.Style = bsClear
        Foot.Brush.Color = clBtnFace
        Foot.Color = clBtnFace
        Foot.Font.Color = clBlue
        Title.Brush.Color = clBtnFace
        Title.Color = clBtnFace
        Title.Text.Strings = (
          'LOSS')
        View3D = False
        View3DWalls = False
        TabOrder = 4
        Anchors = [akLeft, akTop, akRight, akBottom]
        DefaultCanvas = 'TGDIPlusCanvas'
        ColorPaletteIndex = 13
      end
      object ScrollBox1: TScrollBox
        Left = 8
        Top = 35
        Width = 649
        Height = 426
        VertScrollBar.Tracking = True
        TabOrder = 5
        object imgPrediction: TImage
          Left = 0
          Top = 0
          Width = 628
          Height = 1600
          Align = alTop
        end
      end
    end
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 720
    Width = 1276
    Height = 19
    Panels = <>
  end
  object MainMenu1: TMainMenu
    Left = 592
    Top = 65
    object File1: TMenuItem
      Caption = 'File'
      object Load1: TMenuItem
        Caption = 'Load'
        OnClick = Load1Click
      end
      object Store1: TMenuItem
        Caption = 'Store'
        OnClick = Store1Click
      end
      object N1: TMenuItem
        Caption = '-'
      end
      object Close1: TMenuItem
        Caption = 'Close'
      end
    end
  end
end
