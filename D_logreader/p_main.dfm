object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 436
  ClientWidth = 770
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 32
    Top = 24
    Width = 75
    Height = 25
    Caption = 'ldf'
    TabOrder = 0
  end
  object Button2: TButton
    Left = 144
    Top = 24
    Width = 75
    Height = 25
    Caption = 'Button2'
    TabOrder = 1
  end
  object Button3: TButton
    Left = 591
    Top = 24
    Width = 75
    Height = 25
    Caption = 'DBConnectionCfg'
    TabOrder = 2
    OnClick = Button3Click
  end
  object Button4: TButton
    Left = 329
    Top = 24
    Width = 75
    Height = 25
    Caption = 'listLogBlock'
    TabOrder = 3
  end
  object Button5: TButton
    Left = 248
    Top = 24
    Width = 75
    Height = 25
    Caption = 'listVlfs'
    TabOrder = 4
  end
  object Button6: TButton
    Left = 410
    Top = 24
    Width = 113
    Height = 25
    Caption = 'Get row log by lsn'
    TabOrder = 5
  end
  object Memo1: TMemo
    Left = 34
    Top = 55
    Width = 551
    Height = 218
    Lines.Strings = (
      'Memo1')
    TabOrder = 6
  end
  object Button7: TButton
    Left = 591
    Top = 62
    Width = 75
    Height = 25
    Caption = 'copyFile'
    TabOrder = 7
    OnClick = Button7Click
  end
  object Button8: TButton
    Left = 591
    Top = 104
    Width = 75
    Height = 25
    Caption = 'C_picker'
    TabOrder = 8
    OnClick = Button8Click
  end
  object Button9: TButton
    Left = 591
    Top = 135
    Width = 75
    Height = 25
    Caption = 'S_Picker'
    TabOrder = 9
    OnClick = Button9Click
  end
  object Button10: TButton
    Left = 687
    Top = 24
    Width = 75
    Height = 25
    Caption = 'RefreshDict'
    TabOrder = 10
    OnClick = Button10Click
  end
  object Button11: TButton
    Left = 520
    Top = 376
    Width = 75
    Height = 25
    Caption = 'Button11'
    TabOrder = 11
    OnClick = Button11Click
  end
  object Button12: TButton
    Left = 687
    Top = 55
    Width = 75
    Height = 25
    Caption = 'save'
    TabOrder = 12
    OnClick = Button12Click
  end
  object Button13: TButton
    Left = 687
    Top = 86
    Width = 75
    Height = 25
    Caption = 'load'
    TabOrder = 13
    OnClick = Button13Click
  end
  object Button14: TButton
    Left = 664
    Top = 376
    Width = 75
    Height = 25
    Caption = 'Button14'
    TabOrder = 14
  end
end
