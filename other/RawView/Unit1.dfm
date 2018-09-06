object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 668
  ClientWidth = 522
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object ListView1: TListView
    Left = 8
    Top = 8
    Width = 401
    Height = 419
    Columns = <
      item
        Caption = 'id'
      end
      item
        Caption = 'SeqNo'
        Width = 80
      end
      item
        Caption = 'RawNo'
        Width = 60
      end
      item
        Caption = 'Offset'
        Width = 80
      end
      item
        Caption = 'Size'
        Width = 100
      end>
    TabOrder = 0
    ViewStyle = vsReport
  end
  object Button1: TButton
    Left = 423
    Top = 16
    Width = 75
    Height = 25
    Caption = 'listAll'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 423
    Top = 120
    Width = 75
    Height = 25
    Caption = 'check'
    TabOrder = 2
    OnClick = Button2Click
  end
  object Memo1: TMemo
    Left = 8
    Top = 433
    Width = 425
    Height = 145
    Lines.Strings = (
      'Memo1')
    TabOrder = 3
  end
end
