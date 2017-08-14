object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 436
  ClientWidth = 767
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
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 144
    Top = 24
    Width = 75
    Height = 25
    Caption = 'Button2'
    TabOrder = 1
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 240
    Top = 24
    Width = 75
    Height = 25
    Caption = 'DBConnectionCfg'
    TabOrder = 2
    OnClick = Button3Click
  end
  object Button4: TButton
    Left = 441
    Top = 24
    Width = 75
    Height = 25
    Caption = 'Button4'
    TabOrder = 3
    OnClick = Button4Click
  end
  object Button5: TButton
    Left = 344
    Top = 24
    Width = 75
    Height = 25
    Caption = 'listVlfs'
    TabOrder = 4
    OnClick = Button5Click
  end
  object Button6: TButton
    Left = 536
    Top = 24
    Width = 75
    Height = 25
    Caption = 'Button6'
    TabOrder = 5
    OnClick = Button6Click
  end
  object Memo1: TMemo
    Left = 34
    Top = 64
    Width = 551
    Height = 337
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
end
