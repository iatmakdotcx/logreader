object frm_TblFieldsDisp: Tfrm_TblFieldsDisp
  Left = 180
  Top = 249
  BorderIcons = [biSystemMenu]
  Caption = #23383#27573'&'#21442#25968
  ClientHeight = 574
  ClientWidth = 251
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  Position = poDesigned
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ListView1: TListView
    Left = 0
    Top = 54
    Width = 251
    Height = 520
    Align = alClient
    Columns = <
      item
        Caption = #23383#27573
        Width = 124
      end
      item
        Caption = #21442#25968
        Width = 123
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnDblClick = ListView1DblClick
  end
  object pnl1: TPanel
    Left = 0
    Top = 0
    Width = 251
    Height = 33
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object CheckBox1: TCheckBox
      Left = 24
      Top = 9
      Width = 97
      Height = 17
      Hint = #26174#31034'Update'#21069#30340#21442#25968
      Caption = 'Update'#21069
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      OnClick = CheckBox1Click
    end
  end
  object edt_filter: TEdit
    Left = 0
    Top = 33
    Width = 251
    Height = 21
    Align = alTop
    TabOrder = 2
    Text = 'edt_filter'
    OnKeyUp = edt_filterKeyUp
  end
  object ADOQuery1: TADOQuery
    LockType = ltReadOnly
    Parameters = <>
    Left = 16
    Top = 80
  end
end
