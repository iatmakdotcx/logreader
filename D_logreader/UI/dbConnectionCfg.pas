unit dbConnectionCfg;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DB, ADODB, databaseConnection, Vcl.ExtCtrls, Vcl.Imaging.GIFImg;

type
  Tfrm_dbConnectionCfg = class(TForm)
    Panel1: TPanel;
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
    Image5: TImage;
    Label10: TLabel;
    Image6: TImage;
    Label11: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure edt_DatabaseNameDropDown(Sender: TObject);
    procedure btn_okClick(Sender: TObject);
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
  dbHelper, ResHelper;

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


procedure Tfrm_dbConnectionCfg.checkIptCfg;
begin
  pnl_checkipt.BringToFront;

  SetImgData(Image1,'img_load','IMG');
  Image2.Picture.Assign(nil);
  Application.ProcessMessages;


  try
    databaseConnection.getDb_dbInfo;
  except
    SetImgData(Image1,'img_err','IMG');
    Exit;
  end;
  SetImgData(Image1,'img_ok','IMG');
  Application.ProcessMessages;





  Self.ModalResult := mrOk;
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

//  SetImgData(Image1,'img_load','IMG');
//  SetImgData(Image2,'img_ok','IMG');
//  SetImgData(Image3,'img_err','IMG');
end;

end.

