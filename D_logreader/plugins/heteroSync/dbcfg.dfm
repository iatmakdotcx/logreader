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
    Left = 246
    Top = 64
    Width = 22
    Height = 13
    Caption = 'Host'
  end
  object Label2: TLabel
    Left = 247
    Top = 100
    Width = 21
    Height = 13
    Caption = 'user'
  end
  object Label3: TLabel
    Left = 222
    Top = 136
    Width = 46
    Height = 13
    Caption = 'Password'
  end
  object Label4: TLabel
    Left = 222
    Top = 174
    Width = 46
    Height = 13
    Caption = 'Database'
  end
  object Edit1: TEdit
    Left = 281
    Top = 61
    Width = 145
    Height = 21
    TabOrder = 0
  end
  object Edit2: TEdit
    Left = 281
    Top = 97
    Width = 145
    Height = 21
    TabOrder = 1
  end
  object Edit3: TEdit
    Left = 281
    Top = 133
    Width = 145
    Height = 21
    TabOrder = 2
  end
  object Button1: TButton
    Left = 192
    Top = 228
    Width = 75
    Height = 25
    Caption = #30830#23450
    TabOrder = 3
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 384
    Top = 228
    Width = 75
    Height = 25
    Caption = #36864#20986
    TabOrder = 4
    OnClick = Button2Click
  end
  object edt_DatabaseName: TComboBox
    Left = 281
    Top = 171
    Width = 145
    Height = 21
    Style = csDropDownList
    TabOrder = 5
    OnDropDown = edt_DatabaseNameDropDown
  end
  object ADOConnection1: TADOConnection
    Left = 72
    Top = 104
  end
  object ADOQuery1: TADOQuery
    Connection = ADOConnection1
    LockType = ltBatchOptimistic
    Parameters = <>
    Left = 64
    Top = 168
  end
end
