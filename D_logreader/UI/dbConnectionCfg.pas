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
  
  logsource.Fdbc.Host := edt_svr.Text;
  logsource.Fdbc.user := edt_user.Text;
  logsource.Fdbc.PassWd := edt_passwd.Text;
  logsource.Fdbc.dbName := edt_DatabaseName.Text;
  logsource.Fdbc.refreshConnection;

  if not logsource.Fdbc.CheckIsLocalHost then
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
    ShowMessage('������ݿ����һ�α��ݣ�');
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
  //��������ݿ�����ӣ�����û��Ƿ��з��ʴ����ݿ��Ȩ��
  try
    logsource.Fdbc.getDb_dbInfo(False);
    if logsource.Fdbc.dbID = 0 then
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
  if not logsource.Fdbc.CheckIsSysadmin then
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
  if getLogReader(logsource.Fdbc)=nil then
  begin
    SetImgData(Image3,'img_err','IMG');
    mon_EMsg.Text := '��ǰ���ݿⲻ�ڿ�֧�ֵķ�Χ�ڡ�֧�ֵ����ݿ�汾��2000-2014';
    mon_EMsg.Show;
    Exit;
  end;
  if LogSource.UseDBPlugs and (not checkCfgExists(logsource.Fdbc)) then
  begin
    SetImgData(Image3,'img_err','IMG');
    mon_EMsg.Text := 'û�е�ǰ���ݿ�汾����Ч���ã���������á�';
    mon_EMsg.Show;
    Exit;
  end;
  SetImgData(Image3,'img_ok','IMG');
  SetImgData(Image4,'img_load','IMG');
  Application.ProcessMessages;
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
  if not DirectoryExists(appPath+'cfg') then
    ForceDirectories(appPath+'cfg');
  //Ŀ¼Ȩ������
  if logsource.Fdbc.CheckIsLocalHost then
  begin
    if LogSource.UseDBPlugs then
    begin
      ServiceAccount := logsource.Fdbc.GetServiceAccount;
      if not Check_LrExtutils_DataPath_Authentication(appPath, ServiceAccount) then
      begin
        //Ŀ¼��Ȩʧ��
        SetImgData(Image4,'img_err','IMG');
        mon_EMsg.Text := 'Ŀ¼��Ȩʧ�ܣ�' + appPath;
        mon_EMsg.Show;
        Exit;
      end;
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
    //�������һ�α�����
    if backlsn.LSN_1=0 then
    begin
      mon_eMsg2.Text := '������ݿ����һ�α��ݺ���ʹ�ô˹��ܣ�';
      mon_eMsg2.Show;
      Exit;
    end;
    logsource.FProcCurLSN.LSN_1 := backlsn.LSN_1;
    logsource.FProcCurLSN.LSN_2 := backlsn.LSN_2;
    logsource.FProcCurLSN.LSN_3 := backlsn.LSN_3;
  end else begin
    //Ч��lsn�Ƿ���Ч
    TmpLst := TStringList.Create;
    try
      TmpLst.StrictDelimiter := True;
      TmpLst.Delimiter := ':';
      TmpLst.DelimitedText := Edit1.Text;
      if TmpLst.Count<>3 then
      begin
        mon_eMsg2.Text := 'LSN��ʽ����Ч��';
        mon_eMsg2.Show;
        Exit;
      end;

      if TryStrToInt('$' + TmpLst[0], Tmpint) then
      begin
        tmpLsn.LSN_1 := Tmpint;
      end else begin
        mon_eMsg2.Text := 'LSN��ʽ����Ч��1';
        mon_eMsg2.Show;
        Exit;
      end;
      if TryStrToInt('$' + TmpLst[1], Tmpint) then
      begin
        tmpLsn.LSN_2 := Tmpint;
      end else begin
        mon_eMsg2.Text := 'LSN��ʽ����Ч��2';
        mon_eMsg2.Show;
        Exit;
      end;
      if TryStrToInt('$' + TmpLst[2], Tmpint) then
      begin
        tmpLsn.LSN_3 := Tmpint;
      end else begin
        mon_eMsg2.Text := 'LSN��ʽ����Ч��3';
        mon_eMsg2.Show;
        Exit;
      end;
    finally
      TmpLst.Free;
    end;
    if (not logsource.GetRawLogByLSN(tmpLsn, OutBuffer)) or (OutBuffer.dataSize = 0) then
    begin
      mon_eMsg2.Text := 'LSN��Ч��δ�Ҷ�Ӧ���ݣ�';
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

