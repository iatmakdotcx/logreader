object frm_logdisplay: Tfrm_logdisplay
  Left = 0
  Top = 0
  Caption = 'frm_logdisplay'
  ClientHeight = 586
  ClientWidth = 985
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object StringGrid1: TStringGrid
    Left = 24
    Top = 8
    Width = 937
    Height = 497
    Color = clMenuHighlight
    ColCount = 20
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goEditing, goAlwaysShowEditor]
    TabOrder = 1
    ColWidths = (
      64
      140
      99
      64
      64
      64
      64
      64
      64
      64
      64
      64
      64
      64
      64
      64
      64
      64
      64
      64)
    RowHeights = (
      24
      24)
  end
  object cxGrid1: TcxGrid
    Left = 9
    Top = 8
    Width = 968
    Height = 574
    TabOrder = 0
    object cxGrid1TableView1: TcxGridTableView
      Navigator.Buttons.CustomButtons = <>
      DataController.Summary.DefaultGroupSummaryItems = <>
      DataController.Summary.FooterSummaryItems = <>
      DataController.Summary.SummaryGroups = <>
      OptionsCustomize.ColumnFiltering = False
      OptionsCustomize.ColumnMoving = False
      OptionsData.Deleting = False
      OptionsData.Editing = False
      OptionsData.Inserting = False
      OptionsSelection.CellSelect = False
      OptionsView.GroupByBox = False
      object cxGrid1TableView1Column1: TcxGridColumn
        Caption = 'lsn'
        Width = 156
      end
      object cxGrid1TableView1Column2: TcxGridColumn
        Caption = 'Operation'
        Width = 120
      end
      object cxGrid1TableView1Column3: TcxGridColumn
        Caption = 'Context'
        Width = 129
      end
      object cxGrid1TableView1Column4: TcxGridColumn
        Caption = 'TranId'
        Width = 146
      end
      object cxGrid1TableView1Column5: TcxGridColumn
        Caption = 'FixLen'
        Width = 74
      end
      object cxGrid1TableView1Column6: TcxGridColumn
        Caption = 'RecordLen'
        Width = 57
      end
      object cxGrid1TableView1Column7: TcxGridColumn
        Caption = 'previousLSN'
        Width = 165
      end
      object cxGrid1TableView1Column8: TcxGridColumn
        Caption = 'flagBits'
      end
      object cxGrid1TableView1Column9: TcxGridColumn
        Caption = 'AllocUnitId'
      end
      object cxGrid1TableView1Column10: TcxGridColumn
        Caption = 'PageId'
      end
      object cxGrid1TableView1Column11: TcxGridColumn
        Caption = 'slot'
      end
      object cxGrid1TableView1Column12: TcxGridColumn
      end
      object cxGrid1TableView1Column13: TcxGridColumn
      end
      object cxGrid1TableView1Column14: TcxGridColumn
      end
      object cxGrid1TableView1Column15: TcxGridColumn
      end
    end
    object cxGrid1CardView1: TcxGridCardView
      Navigator.Buttons.CustomButtons = <>
      DataController.Summary.DefaultGroupSummaryItems = <>
      DataController.Summary.FooterSummaryItems = <>
      DataController.Summary.SummaryGroups = <>
      OptionsView.CardIndent = 7
      object cxGrid1CardView1Row1: TcxGridCardViewRow
        Position.BeginsLayer = True
      end
      object cxGrid1CardView1Row2: TcxGridCardViewRow
        Position.BeginsLayer = True
      end
      object cxGrid1CardView1Row3: TcxGridCardViewRow
        Position.BeginsLayer = True
      end
      object cxGrid1CardView1Row4: TcxGridCardViewRow
        Position.BeginsLayer = True
      end
      object cxGrid1CardView1Row5: TcxGridCardViewRow
        Position.BeginsLayer = True
      end
      object cxGrid1CardView1Row6: TcxGridCardViewRow
        Position.BeginsLayer = True
      end
    end
    object cxGrid1Level1: TcxGridLevel
      GridView = cxGrid1TableView1
    end
  end
end
