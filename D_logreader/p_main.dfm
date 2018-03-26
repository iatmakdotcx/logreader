object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 349
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
  object Button3: TButton
    Left = 375
    Top = 23
    Width = 75
    Height = 25
    Caption = 'DBConnectionCfg'
    TabOrder = 0
    OnClick = Button3Click
  end
  object Button8: TButton
    Left = 656
    Top = 52
    Width = 75
    Height = 25
    Caption = 'C_picker'
    TabOrder = 1
    OnClick = Button8Click
  end
  object Button9: TButton
    Left = 656
    Top = 83
    Width = 75
    Height = 25
    Caption = 'S_Picker'
    TabOrder = 2
    OnClick = Button9Click
  end
  object Button10: TButton
    Left = 656
    Top = 8
    Width = 75
    Height = 25
    Caption = 'RefreshDict'
    TabOrder = 3
    OnClick = Button10Click
  end
  object GroupBox1: TGroupBox
    Left = 567
    Top = 131
    Width = 176
    Height = 153
    Caption = 'Test'
    TabOrder = 4
    object Button7: TButton
      Left = 3
      Top = 16
      Width = 75
      Height = 25
      Caption = 'copyFile'
      TabOrder = 0
      OnClick = Button7Click
    end
    object Button12: TButton
      Left = 3
      Top = 88
      Width = 75
      Height = 25
      Caption = 'save'
      TabOrder = 1
      OnClick = Button12Click
    end
    object Button13: TButton
      Left = 84
      Top = 88
      Width = 75
      Height = 25
      Caption = 'load'
      TabOrder = 2
      OnClick = Button13Click
    end
  end
  object GroupBox2: TGroupBox
    Left = 8
    Top = 23
    Width = 361
    Height = 285
    Caption = #21152#36733#24050#23384#22312
    TabOrder = 5
    object Button1: TButton
      Left = 15
      Top = 18
      Width = 122
      Height = 47
      Caption = #24320#22987#25235#26085#24535
      TabOrder = 0
      OnClick = Button1Click
    end
    object Button2: TButton
      Left = 143
      Top = 18
      Width = 122
      Height = 47
      Caption = #20572#27490#35299#26512#26085#24535
      TabOrder = 1
    end
    object Mom_ExistsCfg: TMemo
      Left = 15
      Top = 71
      Width = 330
      Height = 89
      Lines.Strings = (
        'Mom_ExistsCfg')
      ScrollBars = ssBoth
      TabOrder = 2
      WordWrap = False
    end
  end
  object Button4: TButton
    Left = 464
    Top = 296
    Width = 75
    Height = 25
    Caption = 'Button4'
    TabOrder = 6
    OnClick = Button4Click
  end
end
