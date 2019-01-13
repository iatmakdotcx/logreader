object frm_lscfgFilteritem: Tfrm_lscfgFilteritem
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #34920#21517#36807#28388
  ClientHeight = 129
  ClientWidth = 508
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
  object Label1: TLabel
    Left = 12
    Top = 72
    Width = 16
    Height = 13
    Caption = #20363':'
  end
  object Label2: TLabel
    Left = 34
    Top = 72
    Width = 88
    Height = 13
    Caption = '[dbo].[tablename]'
  end
  object Label3: TLabel
    Left = 34
    Top = 91
    Width = 81
    Height = 13
    Caption = '[dbo].[tablestart'
  end
  object Label4: TLabel
    Left = 34
    Top = 110
    Width = 42
    Height = 13
    Caption = 'endwith]'
  end
  object RadioGroup1: TRadioGroup
    Left = 0
    Top = 0
    Width = 508
    Height = 33
    Align = alTop
    Columns = 4
    ItemIndex = 0
    Items.Strings = (
      #31561#20110
      #24320#22836#26159
      #32467#23614#26159
      #21253#21547#23383#31526)
    TabOrder = 0
    ExplicitWidth = 548
  end
  object Edit1: TEdit
    Left = 8
    Top = 44
    Width = 409
    Height = 21
    TabOrder = 1
  end
  object Button1: TButton
    Left = 423
    Top = 42
    Width = 75
    Height = 25
    Caption = #30830#23450
    TabOrder = 2
    OnClick = Button1Click
  end
end
