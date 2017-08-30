object frm_logdisplay: Tfrm_logdisplay
  Left = 0
  Top = 0
  Caption = 'frm_logdisplay'
  ClientHeight = 606
  ClientWidth = 984
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object cxGrid1: TcxGrid
    Left = 8
    Top = 24
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
        Width = 39
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
    object cxGrid1Level1: TcxGridLevel
      GridView = cxGrid1TableView1
    end
  end
end
