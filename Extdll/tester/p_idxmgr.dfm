object Form2: TForm2
  Left = 0
  Top = 0
  Caption = 'Form2'
  ClientHeight = 409
  ClientWidth = 884
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 120
    Top = 64
    Width = 105
    Height = 81
    Caption = 'Once All'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 8
    Top = 64
    Width = 75
    Height = 25
    Caption = 'load DLL'
    TabOrder = 1
    OnClick = Button2Click
  end
  object Button28: TButton
    Left = 8
    Top = 112
    Width = 75
    Height = 25
    Caption = 'Unload'
    TabOrder = 2
    OnClick = Button28Click
  end
  object Button3: TButton
    Left = 264
    Top = 64
    Width = 105
    Height = 81
    Caption = 'One by one'
    TabOrder = 3
    OnClick = Button3Click
  end
  object Memo1: TMemo
    Left = 392
    Top = 30
    Width = 484
    Height = 345
    Lines.Strings = (
      'Memo1')
    TabOrder = 4
  end
  object Edit1: TEdit
    Left = 16
    Top = 8
    Width = 370
    Height = 21
    TabOrder = 5
    Text = 'C:\Users\Chin\Desktop\20181207.00.Data.log'
  end
  object Button4: TButton
    Left = 280
    Top = 35
    Width = 75
    Height = 25
    Caption = 'LoadFile'
    TabOrder = 6
    OnClick = Button4Click
  end
  object Edit2: TEdit
    Left = 392
    Top = 8
    Width = 370
    Height = 21
    TabOrder = 7
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 100
    OnTimer = Timer1Timer
    Left = 224
    Top = 208
  end
end
