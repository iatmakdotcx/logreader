unit p_main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, LogSource, Vcl.ComCtrls, System.ImageList, Vcl.ImgList;

type
  TForm1 = class(TForm)
    Button3: TButton;
    Button8: TButton;
    Button9: TButton;
    Button10: TButton;
    GroupBox1: TGroupBox;
    Button7: TButton;
    Button12: TButton;
    Button13: TButton;
    GroupBox2: TGroupBox;
    Button1: TButton;
    Button2: TButton;
    Mom_ExistsCfg: TMemo;
    ReloadList: TButton;
    ListView1: TListView;
    Button5: TButton;
    Memo1: TMemo;
    ImageList1: TImageList;
    Button4: TButton;
    Button6: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure Button12Click(Sender: TObject);
    procedure Button13Click(Sender: TObject);
    procedure Button10Click(Sender: TObject);
    procedure ReloadListClick(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
  private
    { Private declarations }
  public
    logsource: TLogSource;
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  dbConnectionCfg, databaseConnection, p_structDefine, Memory_Common, plugins,
  MakCommonfuncs, pluginlog;

{$R *.dfm}

procedure TForm1.Button10Click(Sender: TObject);
begin
  logsource.Fdbc.refreshDict;
end;

procedure TForm1.Button12Click(Sender: TObject);
begin
  logsource.saveToFile('d:\1.bin');
end;

procedure TForm1.Button13Click(Sender: TObject);
begin
  logsource.loadFromFile('d:\1.bin');
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  savePath:string;
  logsource:TLogSource;
begin
  frm_dbConnectionCfg := Tfrm_dbConnectionCfg.create(nil);
  try
    if frm_dbConnectionCfg.ShowModal = mrOk then
    begin
      logsource := frm_dbConnectionCfg.logsource;
      savePath := ExtractFilePath(GetModuleName(0)) + Format('cfg\%d.lrd',[logsource.Fdbc.dbID]);
      if logsource.saveToFile(savePath) then
      begin
        //保存配置成功才继续，否则处理失败
        LogSourceList.Add(logsource);
        Loger.Add('新增配置完成！！');
      end else begin
        logsource.Free;
        ShowMessage('配置保存失败，确认目录权限.');
      end;
    end
    else
      frm_dbConnectionCfg.logsource.Free;
  finally
    frm_dbConnectionCfg.free;
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
var
  ItemIdx:Integer;
  tlsObj:TLogSource;
begin
  if ListView1.Selected <> nil then
  begin
    ItemIdx := StrToInt(ListView1.Selected.Caption) - 1;
    tlsObj := LogSourceList.Get(ItemIdx);

  end;
end;

procedure msgOut(aMsg: string; level: Integer);
begin
  Form1.Memo1.Lines.add(FormatDateTime('yyyy-MM-dd HH:mm:ss', Now) + ' - ' + IntToStr(level) + ' >>' + aMsg);
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  loger.registerCallBack(msgOut);
  loger.Add('=================loger callback======================');
end;

procedure TForm1.Button6Click(Sender: TObject);
var
  ItemIdx:Integer;
  tlsObj:TLogSource;
  LSN: Tlog_LSN;
  OutBuffer: TMemory_data;
begin
  if ListView1.Selected <> nil then
  begin
    ItemIdx := StrToInt(ListView1.Selected.Caption) - 1;
    tlsObj := LogSourceList.Get(ItemIdx);
    LSN.LSN_1 := $200;
    LSN.LSN_2 := $478;
    LSN.LSN_3 := 1;

    if tlsObj.GetRawLogByLSN(LSN, OutBuffer) and (OutBuffer.dataSize > 0) then
    begin
      ShowMessage(bytestostr(OutBuffer.data,OutBuffer.dataSize));
      FreeMem(OutBuffer.data);
    end;
  end;
end;

procedure TForm1.Button7Click(Sender: TObject);
var
  oum: TMemory_data;
  mmp: TMemoryStream;
begin
  logsource.cpyFile(2, oum);
  mmp := TMemoryStream.Create;
  mmp.WriteBuffer(oum.data^, oum.dataSize);
  mmp.Seek(0, 0);
  mmp.SaveToFile('d:\2_log.bin');
  mmp.Free;
  FreeMem(oum.data);
end;

procedure TForm1.Button8Click(Sender: TObject);
begin
  logsource.Create_picker;
end;

procedure TForm1.Button9Click(Sender: TObject);
begin
  logsource.Stop_picker;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  logsource := TLogSource.create;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  logsource.Free;
end;

procedure TForm1.ReloadListClick(Sender: TObject);
var
  savePath:string;
  lst:TStringList;
  I: Integer;
  Tmplogsource : TLogSource;
  ItemIdx:Integer;
begin
  savePath := ExtractFilePath(GetModuleName(0)) + 'cfg\*.lrd';
  lst := searchAllFileAdv(savePath);
  for I := 0 to lst.Count - 1 do
  begin
    Mom_ExistsCfg.Lines.Add(lst[I]);
    Tmplogsource := TLogSource.Create;
    if Tmplogsource.loadFromFile(lst[I]) then
    begin
      ItemIdx := LogSourceList.Add(Tmplogsource);
      if ItemIdx = -1 then
      begin
        //已存在
        Tmplogsource.Free;
      end
      else
      begin
        Tmplogsource.Fdbc.refreshConnection;
        Tmplogsource.Fdbc.getDb_dbInfo(True);
        Tmplogsource.CreateLogReader;
      end;
    end
    else
    begin
      Tmplogsource.Free;
    end;
  end;
  lst.Free;
  ListView1.clear;
  for I := 0 to LogSourceList.Count - 1 do
  begin
    Tmplogsource := LogSourceList.Get(i);
    with ListView1.Items.Add do
    begin
      Caption := IntToStr(i + 1);
      SubItems.Add(Tmplogsource.Fdbc.Host);
      SubItems.Add(Tmplogsource.Fdbc.dbName);
      SubItems.Add(IntToStr(ord(Tmplogsource.status)));
    end;
  end;
end;

end.

