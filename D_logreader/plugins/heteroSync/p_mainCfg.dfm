object frm_mainCfg: Tfrm_mainCfg
  Left = 0
  Top = 0
  Caption = #23454#20363#35774#32622
  ClientHeight = 515
  ClientWidth = 844
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 844
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lbl_TransInfo: TLabel
      Left = 110
      Top = 15
      Width = 63
      Height = 13
      Caption = 'lbl_TransInfo'
    end
    object Button1: TButton
      Left = 24
      Top = 10
      Width = 75
      Height = 25
      Caption = 'RefreshTable'
      TabOrder = 0
      Visible = False
      OnClick = Button1Click
    end
  end
  object GroupBox1: TGroupBox
    Left = 0
    Top = 41
    Width = 185
    Height = 474
    Align = alLeft
    Caption = 'Tables'
    TabOrder = 1
    object edt_filter: TEdit
      Left = 2
      Top = 15
      Width = 181
      Height = 21
      Align = alTop
      TabOrder = 0
      OnKeyUp = edt_filterKeyUp
    end
    object ListView1: TListView
      Left = 2
      Top = 36
      Width = 181
      Height = 436
      Align = alClient
      BevelInner = bvNone
      BevelOuter = bvNone
      Columns = <
        item
          Caption = 'Name'
          Width = 120
        end
        item
          Caption = 'flag'
        end>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      PopupMenu = PopupMenu1
      TabOrder = 1
      ViewStyle = vsReport
      OnSelectItem = ListView1SelectItem
    end
  end
  object pnl_opts: TPanel
    Left = 185
    Top = 41
    Width = 659
    Height = 474
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    OnResize = pnl_optsResize
    object Splitter1: TSplitter
      Left = 0
      Top = 170
      Width = 659
      Height = 5
      Cursor = crVSplit
      Align = alTop
      ExplicitTop = 105
    end
    object Splitter2: TSplitter
      Left = 0
      Top = 314
      Width = 659
      Height = 5
      Cursor = crVSplit
      Align = alTop
      ExplicitTop = 215
    end
    object gb_Insert: TGroupBox
      Left = 0
      Top = 33
      Width = 659
      Height = 137
      Align = alTop
      Caption = 'Insert'
      TabOrder = 0
      object Memo_Insert: TMemo
        Left = 2
        Top = 15
        Width = 655
        Height = 120
        Align = alClient
        Lines.Strings = (
          'Memo_Insert')
        TabOrder = 0
      end
    end
    object gb_Delete: TGroupBox
      Left = 0
      Top = 175
      Width = 659
      Height = 139
      Align = alTop
      Caption = 'Delete'
      TabOrder = 1
      object Memo_Delete: TMemo
        Left = 2
        Top = 15
        Width = 655
        Height = 122
        Align = alClient
        Lines.Strings = (
          'Memo_Delete')
        TabOrder = 0
      end
    end
    object gb_Update: TGroupBox
      Left = 0
      Top = 319
      Width = 659
      Height = 155
      Align = alClient
      Caption = 'Update'
      TabOrder = 2
      object Memo_Update: TMemo
        Left = 2
        Top = 15
        Width = 655
        Height = 138
        Align = alClient
        Lines.Strings = (
          'Memo_Update')
        TabOrder = 0
      end
    end
    object Panel2: TPanel
      Left = 0
      Top = 0
      Width = 659
      Height = 33
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 3
      DesignSize = (
        659
        33)
      object lbl_tblName: TLabel
        Left = 40
        Top = 16
        Width = 55
        Height = 13
        Caption = 'lbl_tblName'
      end
      object Button2: TButton
        Left = 542
        Top = 4
        Width = 75
        Height = 25
        Anchors = [akTop, akRight]
        Caption = #20445#23384
        TabOrder = 0
        OnClick = Button2Click
      end
    end
  end
  object ADOQuery1: TADOQuery
    Parameters = <>
    Left = 32
    Top = 128
  end
  object PopupMenu1: TPopupMenu
    Left = 88
    Top = 256
    object N1: TMenuItem
      Caption = #21047#26032
      OnClick = N1Click
    end
  end
end
