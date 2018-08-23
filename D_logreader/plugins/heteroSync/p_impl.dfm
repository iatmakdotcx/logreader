object frm_impl: Tfrm_impl
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = #36873#25321#23454#20363
  ClientHeight = 310
  ClientWidth = 424
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object GroupBox1: TGroupBox
    Left = 0
    Top = 0
    Width = 289
    Height = 310
    Align = alLeft
    Caption = #23454#20363#21015#34920
    TabOrder = 0
    object ListView1: TListView
      Left = 2
      Top = 15
      Width = 285
      Height = 293
      Align = alClient
      Columns = <
        item
          Caption = 'DataSource'
          Width = 200
        end
        item
          Caption = 'State'
        end>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnDblClick = ListView1DblClick
      OnSelectItem = ListView1SelectItem
    end
  end
  object btn_add: TButton
    Left = 317
    Top = 24
    Width = 75
    Height = 25
    Caption = #26032#22686
    TabOrder = 1
    OnClick = btn_addClick
  end
  object btn_enable: TButton
    Left = 317
    Top = 109
    Width = 75
    Height = 25
    Caption = #20572#29992
    Enabled = False
    TabOrder = 2
    OnClick = btn_enableClick
  end
  object btn_del: TButton
    Left = 317
    Top = 152
    Width = 75
    Height = 25
    Caption = #21024#38500
    Enabled = False
    TabOrder = 3
    OnClick = btn_delClick
  end
  object btn_cfg: TButton
    Left = 317
    Top = 67
    Width = 75
    Height = 25
    Caption = #37197#32622
    Enabled = False
    TabOrder = 4
    OnClick = btn_cfgClick
  end
  object Button1: TButton
    Left = 341
    Top = 277
    Width = 75
    Height = 25
    Caption = 'Button1'
    TabOrder = 5
    OnClick = Button1Click
  end
end
