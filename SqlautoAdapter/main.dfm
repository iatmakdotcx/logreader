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
    ExplicitHeight = 441
  end
  object Panel1: TPanel
    Left = 0
    Top = 454
    Width = 901
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitTop = 447
    object Button2: TButton
      Left = 342
      Top = 6
      Width = 75
      Height = 25
      Caption = 'Button2'
      TabOrder = 0
      OnClick = Button2Click
    end
    object Button3: TButton
      Left = 24
      Top = 6
      Width = 75
      Height = 25
      Caption = 'start'
      TabOrder = 1
      OnClick = Button3Click
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
    ExplicitTop = 24
  end
  object ADOQuery1: TADOQuery
    LockType = ltReadOnly
    Parameters = <>
    Left = 112
    Top = 240
  end
end
