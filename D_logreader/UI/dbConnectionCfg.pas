unit dbConnectionCfg;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DB, ADODB, databaseConnection, Vcl.ExtCtrls,
  Vcl.ComCtrls, LogSource, p_structDefine;

type
  Tfrm_dbConnectionCfg = class(TForm)
    pnl_ipt: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    edt_svr: TEdit;
    edt_user: TEdit;
    edt_passwd: TEdit;
    edt_DatabaseName: TComboBox;
    btn_ok: TButton;
    btn_cancel: TButton;
    pnl_checkipt: TPanel;
    Label5: TLabel;
    Label6: TLabel;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Image1: TImage;
    Image2: TImage;
    Image3: TImage;
    Label7: TLabel;
    Label8: TLabel;
    Image4: TImage;
    Label9: TLabel;
    mon_EMsg: TMemo;
    pnl_CapPoint: TPanel;
    Label10: TLabel;
    RadioButton1: TRadioButton;
    DateTimePicker1: TDateTimePicker;
    RadioButton2: TRadioButton;
    Edit1: TEdit;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    mon_eMsg2: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure edt_DatabaseNameDropDown(Sender: TObject);
    procedure btn_okClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure RadioButton2Click(Sender: TObject);
  private
    backlsn: Tlog_LSN;
    procedure checkIptCfg;
    procedure CheckPointSet;

    { Private declarations }
  public
    logsource :TLogSource;
    { Public declarations }
  end;

var
  frm_dbConnectionCfg: Tfrm_dbConnectionCfg;

implementation

uses
  dbHelper, ResHelper, sqlextendedprocHelper, MakCommonfuncs, winshellHelper,
  loglog, pMakloadingFormB;

{$R *.dfm}

procedure Tfrm_dbConnectionCfg.btn_okClick(Sender: TObject);
begin
  if edt_svr.Text = '' then
  begin
    Application.MessageBox(PChar('请填写数据库服务器'), PChar(Caption), MB_OK + MB_ICONINFORMATION);
    edt_svr.SetFocus;
    exit;
  end;
  if edt_user.Text = '' then
  begin
    Application.MessageBox(PChar('请填写数据库登录用户名'), PChar(Caption), MB_OK + MB_ICONINFORMATION);
    edt_user.SetFocus;
    exit;
  end;
  if edt_DatabaseName.Text = '' then
  begin
    Application.MessageBox(PChar('请选择数据库'), PChar(Caption), MB_OK + MB_ICONINFORMATION);
    edt_DatabaseName.SetFocus;
    exit;
  end;
  
  logsource.Fdbc.Host := edt_svr.Text;
  logsource.Fdbc.user := edt_user.Text;
  logsource.Fdbc.PassWd := edt_passwd.Text;
  logsource.Fdbc.dbName := edt_DatabaseName.Text;
  logsource.Fdbc.refreshConnection;

  if not logsource.Fdbc.CheckIsLocalHost then
  begin
    Application.MessageBox(PChar('本程序必须数据库服务器上运行'), PChar(Caption), MB_OK + MB_ICONINFORMATION);
  end
  else
  begin
    checkIptCfg;
  end;
end;


procedure Tfrm_dbConnectionCfg.Button1Click(Sender: TObject);
begin
  pnl_ipt.BringToFront;
end;

procedure Tfrm_dbConnectionCfg.Button2Click(Sender: TObject);
var
  backupTime: TDateTime;
begin
  pnl_CapPoint.BringToFront;

  RadioButton1.Enabled := True;
  RadioButton1.Checked := True;
  RadioButton2.Checked := False;
  Edit1.Enabled := False;
  Edit1.Clear;
  DateTimePicker1.Time := Now;
  DateTimePicker1.Enabled := False;
  mon_eMsg2.Hide;

  if logsource.Fdbc.GetLastBackupInfo(backlsn, backupTime) then
  begin
    DateTimePicker1.Time := backupTime;
    Edit1.Text := Format('%.8X:%.8X:%.4X', [backlsn.LSN_1, backlsn.LSN_2, backlsn.LSN_3]);
  end else begin
    ShowMessage('请对数据库进行一次备份！');
    RadioButton1.Enabled := False;
    RadioButton2.Checked := True;
  end;
end;

procedure Tfrm_dbConnectionCfg.Button3Click(Sender: TObject);
begin
  Self.ModalResult := mrCancel;
end;

procedure Tfrm_dbConnectionCfg.Button4Click(Sender: TObject);
begin
  pnl_checkipt.BringToFront;
end;

procedure Tfrm_dbConnectionCfg.Button5Click(Sender: TObject);
begin
  CheckPointSet;
end;

procedure Tfrm_dbConnectionCfg.checkIptCfg;
var
  appPath:string;
  ServiceAccount:string;
begin
  mon_EMsg.Hide;
  Application.ProcessMessages;
  pnl_checkipt.BringToFront;
  SetImgData(Image1,'img_load','IMG');
  Image2.Picture.Assign(nil);
  Application.ProcessMessages;
  //检测与数据库的连接，检测用户是否有访问此数据库的权限
  try
    logsource.Fdbc.getDb_dbInfo(False);
    if logsource.Fdbc.dbID = 0 then
    begin
      Abort;
    end;
  except
    SetImgData(Image1,'img_err','IMG');
    mon_EMsg.Text := '连接数据库失败，或读取数据库信息失败！';
    mon_EMsg.Show;
    Exit;
  end;
  SetImgData(Image1,'img_ok','IMG');
  SetImgData(Image2,'img_load','IMG');
  Application.ProcessMessages;
  //权限检测，检测是否能创建和执行扩展存储过程 (只有sysadmin组成员才能执行和创建扩展存储过程
  if not logsource.Fdbc.CheckIsSysadmin then
  begin
    //如果语句执行失败，或没有返回行,或返回值不等于1
    SetImgData(Image2,'img_err','IMG');
    mon_EMsg.Text := '当前数据库用户不是 sysadmin 成员！';
    mon_EMsg.Show;
    Exit;
  end;
  SetImgData(Image2,'img_ok','IMG');
  SetImgData(Image3,'img_load','IMG');
  Application.ProcessMessages;
  //查看数据库版本是否支持
  if getLogReader(logsource.Fdbc)=nil then
  begin
    SetImgData(Image3,'img_err','IMG');
    mon_EMsg.Text := '当前数据库不在可支持的范围内。支持的数据库版本：2000-2014';
    mon_EMsg.Show;
    Exit;
  end;
  if not checkCfgExists(logsource.Fdbc) then
  begin
    SetImgData(Image3,'img_err','IMG');
    mon_EMsg.Text := '没有当前数据库版本的有效配置！请更新配置。';
    mon_EMsg.Show;
    Exit;
  end;
  SetImgData(Image3,'img_ok','IMG');
  SetImgData(Image4,'img_load','IMG');
  Application.ProcessMessages;
  if not IsRunningAsAdmin then
  begin
    SetImgData(Image4,'img_err','IMG');
    mon_EMsg.Text := '需要管理员身份运行本程序！';
    mon_EMsg.Show;
    Exit;
  end;

  appPath := ExtractFilePath(GetModuleName(HInstance));
  if not DirectoryExists(appPath+'data') then
    ForceDirectories(appPath+'data');
  if not DirectoryExists(appPath+'cfg') then
    ForceDirectories(appPath+'cfg');
  //目录权限设置
  if logsource.Fdbc.CheckIsLocalHost then
  begin
    if LogSource.UseDBPlugs then
    begin
      ServiceAccount := logsource.Fdbc.GetServiceAccount;
      if not Check_LrExtutils_DataPath_Authentication(appPath, ServiceAccount) then
      begin
        //目录授权失败
        SetImgData(Image4,'img_err','IMG');
        mon_EMsg.Text := '目录授权失败！' + appPath;
        mon_EMsg.Show;
        Exit;
      end;
    end;
  end else begin
    //暂不支持远程连接
    SetImgData(Image4,'img_err','IMG');
    mon_EMsg.Text := '暂不支持远程连接';
    mon_EMsg.Show;
    Exit;
  end;
  SetImgData(Image4,'img_ok','IMG');
  //SetImgData(Image5,'img_load','IMG');
  Application.ProcessMessages;

  waitJobComplate(logsource.Fdbc.refreshDict);
  logsource.FisLocal := True;

  Button2.Enabled := True;
end;


procedure Tfrm_dbConnectionCfg.CheckPointSet;
var
  tmpLsn: Tlog_LSN;
  TmpLst:TStringList;
  Tmpint:Integer;
  OutBuffer: TMemory_data;
begin

  if RadioButton1.Checked then
  begin
    //根据最后一次备份来
    if backlsn.LSN_1=0 then
    begin
      mon_eMsg2.Text := '请对数据库进行一次备份后再使用此功能！';
      mon_eMsg2.Show;
      Exit;
    end;
    logsource.FProcCurLSN.LSN_1 := backlsn.LSN_1;
    logsource.FProcCurLSN.LSN_2 := backlsn.LSN_2;
    logsource.FProcCurLSN.LSN_3 := backlsn.LSN_3;
  end else begin
    //效验lsn是否有效
    TmpLst := TStringList.Create;
    try
      TmpLst.StrictDelimiter := True;
      TmpLst.Delimiter := ':';
      TmpLst.DelimitedText := Edit1.Text;
      if TmpLst.Count<>3 then
      begin
        mon_eMsg2.Text := 'LSN格式化无效！';
        mon_eMsg2.Show;
        Exit;
      end;

      if TryStrToInt('$' + TmpLst[0], Tmpint) then
      begin
        tmpLsn.LSN_1 := Tmpint;
      end else begin
        mon_eMsg2.Text := 'LSN格式化无效！1';
        mon_eMsg2.Show;
        Exit;
      end;
      if TryStrToInt('$' + TmpLst[1], Tmpint) then
      begin
        tmpLsn.LSN_2 := Tmpint;
      end else begin
        mon_eMsg2.Text := 'LSN格式化无效！2';
        mon_eMsg2.Show;
        Exit;
      end;
      if TryStrToInt('$' + TmpLst[2], Tmpint) then
      begin
        tmpLsn.LSN_3 := Tmpint;
      end else begin
        mon_eMsg2.Text := 'LSN格式化无效！3';
        mon_eMsg2.Show;
        Exit;
      end;
    finally
      TmpLst.Free;
    end;
    if (not logsource.GetRawLogByLSN(tmpLsn, OutBuffer)) or (OutBuffer.dataSize = 0) then
    begin
      mon_eMsg2.Text := 'LSN无效！未找对应数据！';
      mon_eMsg2.Show;
      Exit;
    end;
    logsource.FProcCurLSN.LSN_1 := tmpLsn.LSN_1;
    logsource.FProcCurLSN.LSN_2 := tmpLsn.LSN_2;
    logsource.FProcCurLSN.LSN_3 := tmpLsn.LSN_3;
    FreeMem(OutBuffer.data);
  end;
  Self.ModalResult := mrOk;
end;

procedure Tfrm_dbConnectionCfg.edt_DatabaseNameDropDown(Sender: TObject);
var
  dbs:TStringList;
  I: Integer;
begin
  logsource.Fdbc.Host := edt_svr.Text;
  logsource.Fdbc.user := edt_user.Text;
  logsource.Fdbc.PassWd := edt_passwd.Text;
  logsource.Fdbc.refreshConnection;
  dbs := logsource.Fdbc.getDb_AllDatabases;
  try
    for I := 0 to dbs.Count - 1 do
    begin
      edt_DatabaseName.Items.Add(dbs[i]);
    end;
  finally
    dbs.Free;
  end;
end;

procedure Tfrm_dbConnectionCfg.FormCreate(Sender: TObject);
begin
{$IFDEF DEBUG}
  edt_svr.Text := '.';
  edt_user.Text := 'sa';
  edt_passwd.Text := 'aa1234569';
{$ENDIF}
  logsource := Tlogsource.Create;
  logsource.Fdbc := TdatabaseConnection.create(logsource);

  Button2.Enabled := False;
  pnl_ipt.BringToFront;
  pnl_checkipt.SendToBack;

end;

procedure Tfrm_dbConnectionCfg.RadioButton2Click(Sender: TObject);
begin
  //DateTimePicker1.Enabled := RadioButton1.Checked;
  Edit1.Enabled := RadioButton2.Checked;
end;

end.

