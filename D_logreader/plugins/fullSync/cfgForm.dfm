object frm_cfg: Tfrm_cfg
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = #37197#32622#36830#25509
  ClientHeight = 154
  ClientWidth = 246
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
  object CheckBox1: TCheckBox
    Left = 16
    Top = 8
    Width = 97
    Height = 17
    Caption = #21551#29992
    TabOrder = 0
    OnClick = CheckBox1Click
  end
  object GroupBox1: TGroupBox
    Left = 8
    Top = 31
    Width = 217
    Height = 74
    Caption = 'GroupBox1'
    TabOrder = 1
    object Edit1: TEdit
      Left = 8
      Top = 17
      Width = 121
      Height = 21
      Enabled = False
      TabOrder = 0
    end
    object Edit2: TEdit
      Left = 8
      Top = 45
      Width = 121
      Height = 21
      Enabled = False
      TabOrder = 1
    end
    object Button1: TButton
      Left = 135
      Top = 15
      Width = 75
      Height = 25
      Caption = #37197#32622
      TabOrder = 2
      OnClick = Button1Click
    end
  end
  object Button2: TButton
    Left = 85
    Top = 120
    Width = 75
    Height = 25
    Caption = #20445#23384
    TabOrder = 2
    OnClick = Button2Click
  end
end
