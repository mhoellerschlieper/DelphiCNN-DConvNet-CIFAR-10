object FRMMain: TFRMMain
  Left = 22
  Top = 48
  Width = 1493
  Height = 784
  Caption = 'CNN - M.H'#246'ller-Schlieper 2017'
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
  PixelsPerInch = 96
  TextHeight = 13
  object Image1: TImage
    Left = 857
    Top = 41
    Width = 628
    Height = 673
    Align = alClient
  end
  object Panel3: TPanel
    Left = 0
    Top = 0
    Width = 1485
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
      Width = 64
      Height = 13
      Caption = 'press start...'
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
      Left = 864
      Top = 11
      Width = 273
      Height = 19
      Caption = 'Debug and show details'
      Checked = True
      State = cbChecked
      TabOrder = 1
      OnClick = cbDebugClick
    end
  end
  object Panel1: TPanel
    Left = 0
    Top = 41
    Width = 857
    Height = 673
    Align = alLeft
    TabOrder = 1
    object imgPrediction: TImage
      Left = 8
      Top = 32
      Width = 649
      Height = 429
    end
    object panButtons: TPanel
      Left = 664
      Top = 7
      Width = 169
      Height = 458
      TabOrder = 0
    end
    object Chart1: TChart
      Left = 1
      Top = 480
      Width = 855
      Height = 192
      BackWall.Brush.Color = clWhite
      BackWall.Brush.Style = bsClear
      Foot.Brush.Color = clBtnFace
      Foot.Color = clBtnFace
      Foot.Font.Charset = DEFAULT_CHARSET
      Foot.Font.Color = clBlue
      Foot.Font.Height = -11
      Foot.Font.Name = 'Arial'
      Foot.Font.Style = [fsItalic]
      Title.Brush.Color = clBtnFace
      Title.Color = clBtnFace
      Title.Text.Strings = (
        'LOSS')
      View3D = False
      View3DWalls = False
      Align = alBottom
      TabOrder = 1
    end
    object btnNext: TButton
      Left = 296
      Top = 4
      Width = 209
      Height = 25
      Caption = '> test next images'
      TabOrder = 2
      OnClick = btnNextClick
    end
    object btnPrev: TButton
      Left = 112
      Top = 4
      Width = 179
      Height = 25
      Caption = '< test prev images'
      TabOrder = 3
      OnClick = btnPrevClick
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 714
    Width = 1485
    Height = 19
    Panels = <>
  end
  object MainMenu1: TMainMenu
    Left = 592
    Top = 65
    object File1: TMenuItem
      Caption = 'File'
      object Laod1: TMenuItem
        Caption = 'Load'
        OnClick = Laod1Click
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
