object frm_paramStyleHelp: Tfrm_paramStyleHelp
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #21442#25968#24110#21161
  ClientHeight = 294
  ClientWidth = 570
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object GroupBox1: TGroupBox
    Left = 24
    Top = 152
    Width = 521
    Height = 121
    Caption = #21442#25968#26367#25442#20026#20540
    TabOrder = 0
    object Memo2: TMemo
      Left = 2
      Top = 15
      Width = 517
      Height = 104
      Align = alClient
      BevelInner = bvNone
      BevelOuter = bvNone
      BorderStyle = bsNone
      Enabled = False
      Lines.Strings = (
        'delete [table] where id=@id'
        '=>'
        'delete [table] where id=100')
      TabOrder = 0
      ExplicitLeft = 4
      ExplicitTop = 17
    end
  end
  object GroupBox2: TGroupBox
    Left = 24
    Top = 8
    Width = 521
    Height = 121
    Caption = #40664#35748
    TabOrder = 1
    object Memo1: TMemo
      Left = 2
      Top = 15
      Width = 517
      Height = 104
      Align = alClient
      BevelInner = bvNone
      BevelOuter = bvNone
      BorderStyle = bsNone
      Enabled = False
      Lines.Strings = (
        'delete [table] where id=@id'
        '=>'
        'declare @id int;'
        'set @id=100'
        'delete [table] where id=@id')
      TabOrder = 0
      ExplicitLeft = 3
      ExplicitTop = 14
    end
  end
end
