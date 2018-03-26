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
    Application.MessageBox(PChar('����д���ݿ������'), PChar(Caption), MB_OK + MB_ICONINFORMATION);
    edt_svr.SetFocus;
    exit;
  end;
  if edt_user.Text = '' then
  begin
    Application.MessageBox(PChar('����д���ݿ��¼�û���'), PChar(Caption), MB_OK + MB_ICONINFORMATION);
    edt_user.SetFocus;
    exit;
  end;
  if edt_DatabaseName.Text = '' then
  begin
    Application.MessageBox(PChar('��ѡ�����ݿ�'), PChar(Caption), MB_OK + MB_ICONINFORMATION);
    edt_DatabaseName.SetFocus;
    exit;
  end;
  
  databaseConnection.Host := edt_svr.Text;
  databaseConnection.user := edt_user.Text;
  databaseConnection.PassWd := edt_passwd.Text;
  databaseConnection.dbName := edt_DatabaseName.Text;
  
  if not databaseConnection.CheckIsLocalHost then
  begin
    Application.MessageBox(PChar('������������ݿ������������'), PChar(Caption), MB_OK + MB_ICONINFORMATION);
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
  //��������ݿ�����ӣ�����û��Ƿ��з��ʴ����ݿ��Ȩ��
  try
    databaseConnection.getDb_dbInfo;
    if databaseConnection.dbID = 0 then
    begin
      Abort;
    end;
  except
    SetImgData(Image1,'img_err','IMG');
    mon_EMsg.Text := '�������ݿ�ʧ�ܣ����ȡ���ݿ���Ϣʧ�ܣ�';
    mon_EMsg.Show;
    Exit;
  end;
  SetImgData(Image1,'img_ok','IMG');
  SetImgData(Image2,'img_load','IMG');
  Application.ProcessMessages;
  //Ȩ�޼�⣬����Ƿ��ܴ�����ִ����չ�洢���� (ֻ��sysadmin���Ա����ִ�кʹ�����չ�洢����
  if not databaseConnection.CheckIsSysadmin then
  begin
    //������ִ��ʧ�ܣ���û�з�����,�򷵻�ֵ������1
    SetImgData(Image2,'img_err','IMG');
    mon_EMsg.Text := '��ǰ���ݿ��û����� sysadmin ��Ա��';
    mon_EMsg.Show;
    Exit;
  end;
  SetImgData(Image2,'img_ok','IMG');
  SetImgData(Image3,'img_load','IMG');
  Application.ProcessMessages;
  //�鿴���ݿ�汾�Ƿ�֧��
  if (databaseConnection.dbVer_Major < 8) or (databaseConnection.dbVer_Major > 12) then
  begin
    SetImgData(Image3,'img_err','IMG');
    mon_EMsg.Text := '��ǰ���ݿⲻ�ڿ�֧�ֵķ�Χ�ڡ�֧�ֵ����ݿ�汾��2000-2014';
    mon_EMsg.Show;
    Exit;
  end;
  if not checkCfgExists(databaseConnection) then
  begin
    SetImgData(Image3,'img_err','IMG');
    mon_EMsg.Text := 'û�е�ǰ���ݿ�汾����Ч���ã���������á�';
    mon_EMsg.Show;
    Exit;
  end;
  SetImgData(Image3,'img_ok','IMG');
  SetImgData(Image4,'img_load','IMG');
  Application.ProcessMessages;
  //Ŀ¼Ȩ������
  if databaseConnection.CheckIsLocalHost then
  begin
    if not IsRunningAsAdmin then
    begin
      SetImgData(Image4,'img_err','IMG');
      mon_EMsg.Text := '��Ҫ����Ա������б�����';
      mon_EMsg.Show;
      Exit;
    end;

    appPath := ExtractFilePath(GetModuleName(HInstance));
    if not DirectoryExists(appPath+'data') then
      ForceDirectories(appPath+'data');
    if not Check_LrExtutils_DataPath_Authentication(appPath+'data') then
    begin
      //Ŀ¼��Ȩʧ��
      SetImgData(Image4,'img_err','IMG');
      mon_EMsg.Text := 'Ŀ¼��Ȩʧ�ܣ�' + appPath + 'data';
      mon_EMsg.Show;
      Exit;
    end;
  end else begin
    //�ݲ�֧��Զ������
    SetImgData(Image4,'img_err','IMG');
    mon_EMsg.Text := '�ݲ�֧��Զ������';
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

