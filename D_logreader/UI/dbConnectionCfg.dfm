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
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 639
    Height = 335
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitLeft = 41
    ExplicitTop = 22
    ExplicitWidth = 545
    ExplicitHeight = 273
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
      TabOrder = 3
      OnDropDown = edt_DatabaseNameDropDown
    end
    object btn_ok: TButton
      Left = 400
      Top = 248
      Width = 75
      Height = 25
      Caption = 'OK'
      TabOrder = 4
      OnClick = btn_okClick
    end
    object btn_cancel: TButton
      Left = 502
      Top = 248
      Width = 75
      Height = 25
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 5
    end
  end
  object pnl_checkipt: TPanel
    Left = 0
    Top = 0
    Width = 639
    Height = 335
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitLeft = -176
    ExplicitTop = -25
    object Label5: TLabel
      Left = 40
      Top = 40
      Width = 132
      Height = 13
      Caption = #27491#22312#27979#35797#36755#20837#37197#32622#12290#12290#12290
    end
    object Label6: TLabel
      Left = 104
      Top = 80
      Width = 60
      Height = 13
      Caption = #25968#25454#24211#36830#25509
    end
    object Image1: TImage
      Left = 64
      Top = 76
      Width = 24
      Height = 24
    end
    object Image2: TImage
      Left = 64
      Top = 114
      Width = 24
      Height = 24
    end
    object Image3: TImage
      Left = 64
      Top = 151
      Width = 24
      Height = 24
    end
    object Label7: TLabel
      Left = 104
      Top = 118
      Width = 48
      Height = 13
      Caption = #29992#25143#26435#38480
    end
    object Label8: TLabel
      Left = 104
      Top = 156
      Width = 84
      Height = 13
      Caption = #25968#25454#24211#29256#26412#25903#25345
    end
    object Image4: TImage
      Left = 64
      Top = 188
      Width = 24
      Height = 24
    end
    object Label9: TLabel
      Left = 104
      Top = 193
      Width = 72
      Height = 13
      Caption = #21019#24314#23384#20648#36807#31243
    end
    object Image5: TImage
      Left = 64
      Top = 226
      Width = 24
      Height = 24
    end
    object Label10: TLabel
      Left = 104
      Top = 231
      Width = 72
      Height = 13
      Caption = #39564#35777#23384#20648#36807#31243
    end
    object Image6: TImage
      Left = 64
      Top = 262
      Width = 24
      Height = 24
    end
    object Label11: TLabel
      Left = 104
      Top = 267
      Width = 72
      Height = 13
      Caption = #35774#32622#30446#24405#26435#38480
    end
    object Button1: TButton
      Left = 323
      Top = 275
      Width = 75
      Height = 25
      Caption = #19978#19968#27493
      TabOrder = 0
    end
    object Button2: TButton
      Left = 427
      Top = 275
      Width = 75
      Height = 25
      Caption = #23436#25104
      TabOrder = 1
    end
    object Button3: TButton
      Left = 523
      Top = 275
      Width = 75
      Height = 25
      Caption = #20851#38381
      TabOrder = 2
    end
  end
end
