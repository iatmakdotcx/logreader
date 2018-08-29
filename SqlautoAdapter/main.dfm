object frm_main: Tfrm_main
  Left = 0
  Top = 0
  Caption = 'frm_main'
  ClientHeight = 495
  ClientWidth = 901
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Memo1: TMemo
    Left = 0
    Top = 0
    Width = 901
    Height = 437
    Align = alClient
    BevelInner = bvNone
    BevelOuter = bvNone
    Lines.Strings = (
      'Memo1')
    ScrollBars = ssBoth
    TabOrder = 0
    WordWrap = False
  end
  object Panel1: TPanel
    Left = 0
    Top = 454
    Width = 901
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitLeft = -8
    ExplicitTop = 443
    object btn_Analysis: TButton
      Left = 24
      Top = 6
      Width = 75
      Height = 25
      Caption = 'Analysis'
      TabOrder = 0
      OnClick = btn_AnalysisClick
    end
    object btn_test: TButton
      Left = 164
      Top = 6
      Width = 75
      Height = 25
      Caption = 'AutoTest'
      Enabled = False
      TabOrder = 1
      Visible = False
      OnClick = btn_testClick
    end
    object btn_clear: TButton
      Left = 304
      Top = 6
      Width = 75
      Height = 25
      Caption = 'Clear'
      Enabled = False
      TabOrder = 2
      OnClick = btn_clearClick
    end
  end
  object ProgressBar1: TProgressBar
    Left = 0
    Top = 437
    Width = 901
    Height = 17
    Align = alBottom
    TabOrder = 2
    Visible = False
  end
  object ADOQuery1: TADOQuery
    LockType = ltReadOnly
    Parameters = <>
    Left = 112
    Top = 240
  end
  object Timer1: TTimer
    Interval = 100
    OnTimer = Timer1Timer
    Left = 448
    Top = 224
  end
end
