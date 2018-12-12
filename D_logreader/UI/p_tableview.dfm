object frm_tableview: Tfrm_tableview
  Left = 0
  Top = 0
  Caption = 'frm_tableview'
  ClientHeight = 388
  ClientWidth = 826
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
  object cxGrid1: TcxGrid
    Left = 0
    Top = 0
    Width = 826
    Height = 388
    Align = alClient
    TabOrder = 0
    object cxGrid1TableView1: TcxGridTableView
      PopupMenu = PopupMenu1
      Navigator.Buttons.CustomButtons = <>
      DataController.Summary.DefaultGroupSummaryItems = <>
      DataController.Summary.FooterSummaryItems = <>
      DataController.Summary.SummaryGroups = <>
      DataController.OnDetailExpanding = cxGrid1TableView1DataControllerDetailExpanding
      OptionsData.Deleting = False
      OptionsData.Editing = False
      OptionsData.Inserting = False
      object cxGrid1TableView1Column1: TcxGridColumn
        Caption = 'No'
      end
      object cxGrid1TableView1Column2: TcxGridColumn
        Caption = 'Id'
      end
      object cxGrid1TableView1Column3: TcxGridColumn
        Caption = 'Owner'
      end
      object cxGrid1TableView1Column4: TcxGridColumn
        Caption = 'Name'
        Width = 165
      end
      object cxGrid1TableView1Column6: TcxGridColumn
        Caption = 'hasIdentity'
        PropertiesClassName = 'TcxCheckBoxProperties'
      end
      object cxGrid1TableView1Column7: TcxGridColumn
        Caption = 'Uck'
        Width = 80
      end
    end
    object cxGrid1TableView2: TcxGridTableView
      Navigator.Buttons.CustomButtons = <>
      DataController.Summary.DefaultGroupSummaryItems = <>
      DataController.Summary.FooterSummaryItems = <>
      DataController.Summary.SummaryGroups = <>
      OptionsData.Deleting = False
      OptionsData.Editing = False
      OptionsData.Inserting = False
      OptionsView.GroupByBox = False
      object cxGrid1TableView2Column1: TcxGridColumn
        Caption = 'ColId'
      end
      object cxGrid1TableView2Column2: TcxGridColumn
        Caption = 'ColName'
        Width = 100
      end
      object cxGrid1TableView2Column3: TcxGridColumn
        Caption = 'Type'
        Width = 100
      end
      object cxGrid1TableView2Column4: TcxGridColumn
        Caption = 'nullable'
        PropertiesClassName = 'TcxCheckBoxProperties'
      end
    end
    object cxGrid1Level1: TcxGridLevel
      GridView = cxGrid1TableView1
      object cxGrid1Level2: TcxGridLevel
        GridView = cxGrid1TableView2
      end
    end
  end
  object PopupMenu1: TPopupMenu
    Left = 432
    Top = 136
    object ExportXml1: TMenuItem
      Caption = 'Export2Xml...'
      OnClick = ExportXml1Click
    end
  end
end
