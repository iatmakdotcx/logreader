object frm_dbcfg: Tfrm_dbcfg
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = #25968#25454#24211#37197#32622
  ClientHeight = 310
  ClientWidth = 645
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 252
    Top = 78
    Width = 22
    Height = 13
    Caption = 'Host'
  end
  object Label2: TLabel
    Left = 253
    Top = 114
    Width = 21
    Height = 13
    Caption = 'user'
  end
  object Label3: TLabel
    Left = 228
    Top = 150
    Width = 46
    Height = 13
    Caption = 'Password'
  end
  object Edit1: TEdit
    Left = 287
    Top = 75
    Width = 121
    Height = 21
    TabOrder = 0
  end
  object Edit2: TEdit
    Left = 287
    Top = 111
    Width = 121
    Height = 21
    TabOrder = 1
  end
  object Edit3: TEdit
    Left = 287
    Top = 147
    Width = 121
    Height = 21
    TabOrder = 2
  end
  object Button1: TButton
    Left = 192
    Top = 216
    Width = 75
    Height = 25
    Caption = #30830#23450
    TabOrder = 3
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 384
    Top = 216
    Width = 75
    Height = 25
    Caption = #36864#20986
    TabOrder = 4
    OnClick = Button2Click
  end
  object ADOConnection1: TADOConnection
    Left = 200
    Top = 152
  end
end
