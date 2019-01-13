object frm_lscfg: Tfrm_lscfg
  Left = 0
  Top = 0
  Caption = 'frm_lscfg'
  ClientHeight = 584
  ClientWidth = 635
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 635
    Height = 584
    ActivePage = tab_filter
    Align = alClient
    TabOrder = 0
    ExplicitLeft = 184
    ExplicitTop = 72
    ExplicitWidth = 289
    ExplicitHeight = 193
    object tab_base: TTabSheet
      Caption = #22522#26412
      ExplicitWidth = 281
      ExplicitHeight = 165
    end
    object tab_filter: TTabSheet
      Caption = #36807#28388
      ImageIndex = 1
      ExplicitWidth = 281
      ExplicitHeight = 165
      object ListBox1: TListBox
        Left = 0
        Top = 41
        Width = 233
        Height = 515
        Align = alLeft
        ItemHeight = 13
        TabOrder = 0
        ExplicitLeft = 16
        ExplicitTop = 47
        ExplicitHeight = 218
      end
      object RadioGroup1: TRadioGroup
        Left = 0
        Top = 0
        Width = 627
        Height = 41
        Align = alTop
        Columns = 3
        ItemIndex = 0
        Items.Strings = (
          #20840#37096
          #25490#38500
          #21253#21547)
        TabOrder = 1
        OnClick = RadioGroup1Click
      end
      object btn_filter_add: TButton
        Left = 239
        Top = 57
        Width = 75
        Height = 25
        Caption = #26032#22686
        TabOrder = 2
        OnClick = btn_filter_addClick
      end
      object btn_filter_delete: TButton
        Left = 239
        Top = 104
        Width = 75
        Height = 25
        Caption = #21024#38500
        TabOrder = 3
      end
      object btn_refresh: TButton
        Left = 239
        Top = 152
        Width = 75
        Height = 25
        Caption = #21047#26032
        TabOrder = 4
        Visible = False
        OnClick = btn_refreshClick
      end
    end
  end
end
