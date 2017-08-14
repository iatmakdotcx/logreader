object frm_dbConnectionCfg: Tfrm_dbConnectionCfg
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Database Connection'
  ClientHeight = 335
  ClientWidth = 639
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 214
    Top = 82
    Width = 32
    Height = 13
    Caption = 'Server'
  end
  object Label2: TLabel
    Left = 224
    Top = 109
    Width = 22
    Height = 13
    Caption = 'User'
  end
  object Label3: TLabel
    Left = 200
    Top = 136
    Width = 46
    Height = 13
    Caption = 'Password'
  end
  object Label4: TLabel
    Left = 200
    Top = 168
    Width = 46
    Height = 13
    Caption = 'Database'
  end
  object edt_svr: TEdit
    Left = 251
    Top = 79
    Width = 145
    Height = 21
    TabOrder = 0
  end
  object edt_user: TEdit
    Left = 251
    Top = 106
    Width = 145
    Height = 21
    TabOrder = 1
  end
  object edt_passwd: TEdit
    Left = 251
    Top = 133
    Width = 145
    Height = 21
    PasswordChar = '*'
    TabOrder = 2
  end
  object edt_DatabaseName: TComboBox
    Left = 251
    Top = 165
    Width = 145
    Height = 21
    Style = csDropDownList
    ItemHeight = 0
    TabOrder = 3
    OnDropDown = edt_DatabaseNameDropDown
  end
  object btn_ok: TButton
    Left = 400
    Top = 256
    Width = 75
    Height = 25
    Caption = 'OK'
    TabOrder = 4
    OnClick = btn_okClick
  end
  object btn_cancel: TButton
    Left = 496
    Top = 256
    Width = 75
    Height = 25
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 5
  end
end
