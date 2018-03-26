unit dbConnectionCfg;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DB, ADODB, databaseConnection, Vcl.ExtCtrls, Vcl.Imaging.GIFImg;

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
    procedure FormCreate(Sender: TObject);
    procedure edt_DatabaseNameDropDown(Sender: TObject);
    procedure btn_okClick(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    procedure checkIptCfg;

    { Private declarations }
  public
    databaseConnection:TdatabaseConnection;
    { Public declarations }
  end;

var
  frm_dbConnectionCfg: Tfrm_dbConnectionCfg;

implementation

uses
  dbHelper, ResHelper, sqlextendedprocHelper, MakCommonfuncs, winshellHelper;

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
  
  databaseConnection.Host := edt_svr.Text;
  databaseConnection.user := edt_user.Text;
  databaseConnection.PassWd := edt_passwd.Text;
  databaseConnection.dbName := edt_DatabaseName.Text;
  
  if not databaseConnection.CheckIsLocalHost then
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
  pnl_checkipt.SendToBack;
end;

procedure Tfrm_dbConnectionCfg.Button2Click(Sender: TObject);
begin
  Self.ModalResult := mrOk;
end;

procedure Tfrm_dbConnectionCfg.Button3Click(Sender: TObject);
begin
  Self.ModalResult := mrCancel;
end;

procedure Tfrm_dbConnectionCfg.checkIptCfg;
var
  appPath:string;
begin
  mon_EMsg.Hide;
  Application.ProcessMessages;
  pnl_checkipt.BringToFront;

  SetImgData(Image1,'img_load','IMG');
  Image2.Picture.Assign(nil);
  Application.ProcessMessages;
  //检测与数据库的连接，检测用户是否有访问此数据库的权限
  try
    databaseConnection.getDb_dbInfo;
    if databaseConnection.dbID = 0 then
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
  if not databaseConnection.CheckIsSysadmin then
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
  if (databaseConnection.dbVer_Major < 8) or (databaseConnection.dbVer_Major > 12) then
  begin
    SetImgData(Image3,'img_err','IMG');
    mon_EMsg.Text := '当前数据库不在可支持的范围内。支持的数据库版本：2000-2014';
    mon_EMsg.Show;
    Exit;
  end;
  if not checkCfgExists(databaseConnection) then
  begin
    SetImgData(Image3,'img_err','IMG');
    mon_EMsg.Text := '没有当前数据库版本的有效配置！请更新配置。';
    mon_EMsg.Show;
    Exit;
  end;
  SetImgData(Image3,'img_ok','IMG');
  SetImgData(Image4,'img_load','IMG');
  Application.ProcessMessages;
  //目录权限设置
  if databaseConnection.CheckIsLocalHost then
  begin
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
    if not Check_LrExtutils_DataPath_Authentication(appPath+'data') then
    begin
      //目录授权失败
      SetImgData(Image4,'img_err','IMG');
      mon_EMsg.Text := '目录授权失败！' + appPath + 'data';
      mon_EMsg.Show;
      Exit;
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
  Button2.Enabled := True;
end;


procedure Tfrm_dbConnectionCfg.edt_DatabaseNameDropDown(Sender: TObject);
var
  dbs:TStringList;
  I: Integer;
begin
  databaseConnection.Host := edt_svr.Text;
  databaseConnection.user := edt_user.Text;
  databaseConnection.PassWd := edt_passwd.Text;
  databaseConnection.dbName := 'master';
  databaseConnection.refreshConnection;
  dbs := databaseConnection.getDb_AllDatabases;
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

  databaseConnection := TdatabaseConnection.create;

  Button2.Enabled := False;
  pnl_ipt.BringToFront;
  pnl_checkipt.SendToBack;
end;

end.

