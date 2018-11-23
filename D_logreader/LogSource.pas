unit LogSource;

interface

uses
  I_LogProvider, databaseConnection, p_structDefine, Types,
  System.Classes, System.SyncObjs, System.Contnrs, loglog, I_LogSource;

type
   TLogPicker = class(TThread)

   public
     procedure Start;virtual;abstract;
     function GetRawLogByLSN(LSN: Tlog_LSN; var OutBuffer: TMemory_data): Boolean;virtual;abstract;
     function state:LS_STATUE;virtual;abstract;
   end;

type
  TLogSource = class(TLogSourceBase)
  private
    FCfgFilePath:string;
    FRunCs: TCriticalSection;
    FmsgCs:TCriticalSection;
    procedure ClrLogSource;
    procedure ReSetLoger;
  public
    uid:string;
    FFmsg: TStringList;
    FProcCurLSN: Tlog_LSN;  //当前处理的位置

    Fdbc: TdatabaseConnection;
    FLogPicker:TLogPicker;
    FisLocal:Boolean;
    FFFFIsDebug:Boolean;
    pageDatalist:TObjectList;
    MainMSGDISPLAY:TMsgCallBack;
    constructor Create;
    destructor Destroy; override;
    function GetVlf_SeqNo(SeqNo:DWORD): PVLF_Info;
    function GetRawLogByLSN(LSN: Tlog_LSN;var OutBuffer: TMemory_data): Boolean;
    function Create_picker(AutoRun:Boolean):Boolean;
    procedure Stop_picker;
    function status:LS_STATUE;

    function loadFromFile(aPath: string):Boolean;
    function saveToFile(aPath: string = ''):Boolean;
    procedure loadFromFile_LSN;
    procedure saveToFile_LSN;

    /// <summary>
    /// 从数据库对比字典差异
    /// </summary>
    /// <returns></returns>
    function CompareDict:string;
    procedure AddFmsg(aMsg: string; level: Integer);
  end;

  TLogSourceList = class(TObject)
  private
    ObjList:TList;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(Item: TLogSource): Integer;
    function Get(Index: Integer): TLogSource;
    function Count: Integer;
    procedure Delete(Index: Integer);
    function Exists(Item: TLogSource):Boolean;
  end;


function getLogReader(Fdbc: TdatabaseConnection):TClass;

var
  LogSourceList:TLogSourceList;

implementation

uses
  MakCommonfuncs, Windows, SysUtils, Xml.XMLDoc, Xml.XMLIntf,
  Sql2014LogReader, sqlextendedprocHelper;


function getLogReader(Fdbc: TdatabaseConnection):TClass;
begin
  Result := nil;
  if Fdbc.CheckIsLocalHost then
  begin
    if (Fdbc.dbVer_Major > 10) and (Fdbc.dbVer_Major <= 12) then
    begin
      //2008之后的版本都用这个读取方式
      Result := TSql2014LogPicker;
    end;
  end;
end;
{ TLogSource }

procedure TLogSource.AddFmsg(aMsg: string; level: Integer);
begin
  FmsgCs.Enter;
  try
    FFmsg.Add(FormatDateTime('yyyy-MM-dd HH:nn:ss.zzz', Now) + IntToStr(level) + ' >> ' + aMsg);
    if FFmsg.Count >= 100 then
    begin
      FFmsg.Delete(0);
    end;
  finally
    FmsgCs.Leave
  end;
  if Assigned(MainMSGDISPLAY) then
    MainMSGDISPLAY(aMsg, level);
end;

procedure TLogSource.ClrLogSource;
begin
  Stop_picker;
  if Fdbc <> nil then
    FreeAndNil(Fdbc);
end;

function TLogSource.CompareDict: string;
begin
  Result := Fdbc.CompareDict;
end;

constructor TLogSource.Create;
var
  Guid: TGUID;
begin
  FmsgCs:=TCriticalSection.Create;
  MainMSGDISPLAY := nil;
  inherited;
  FLoger := DefLoger;
  FProcCurLSN.LSN_1 := 0;
  FProcCurLSN.LSN_2 := 0;
  FProcCurLSN.LSN_3 := 0;
  FisLocal := True;
  Fdbc := nil;
  FLogPicker := nil;
  FRunCs:=TCriticalSection.Create;
  FFFFIsDebug := False;
  pageDatalist := nil;

  FFmsg := TStringList.Create;
  if CreateGUID(Guid) <> S_OK then
    uid := FormatDateTime('yyyymmddHHnnsszzz',Now)
  else
    uid := GUIDToString(Guid);
end;

function TLogSource.Create_picker(AutoRun:Boolean): Boolean;
var
  logreaderClass:TClass;
begin
  Result := False;
  setDbOn(Fdbc);
  FRunCs.Enter;
  try
    if FLogPicker = nil then
    begin
      logreaderClass := getLogReader(Fdbc);
      if logreaderClass<>nil then
      begin
        //2008之后的版本都用这个读取方式
        FLogPicker := TSql2014LogPicker.Create(AutoRun, Self);
        Result := True;
      end;
    end else begin
      FLogPicker.Start;
    end;
  finally
    FRunCs.Leave;
  end;
end;

destructor TLogSource.Destroy;
begin
  ClrLogSource;
  FRunCs.Free;
  pageDatalist.Free;
  if FLoger = DefLoger then
  begin
    Loger.removeCallBack(Self, AddFmsg);
  end else begin
    FLoger.Free;
  end;
  FFmsg.Free;
  FmsgCs.Free;
  inherited;
end;

function TLogSource.GetVlf_SeqNo(SeqNo:DWORD): PVLF_Info;
var
  I: Integer;
begin
  if Length(Fdbc.FVLF_List) = 0 then
    Fdbc.getDb_VLFs;

  Result := nil;
  for I := 0 to Length(Fdbc.FVLF_List) - 1 do
  begin
    if Fdbc.FVLF_List[I].SeqNo = SeqNo then
    begin
      new(Result);
      Result^ := Fdbc.FVLF_List[I];
      Break;
    end;
  end;
end;

function TLogSource.GetRawLogByLSN(LSN: Tlog_LSN;var OutBuffer: TMemory_data): Boolean;
begin
  if FLogPicker=nil then
    Create_picker(False);
  Result := FLogPicker.GetRawLogByLSN(LSN, OutBuffer);
end;

function TLogSource.status: LS_STATUE;
begin
  if Fdbc = nil then
  begin
    Result := tLS_NotConfig;
  end else if FLogPicker = nil then
  begin
    Result := tLS_stopped;
  end else
  begin
    Result := FLogPicker.state;
  end;
end;

procedure TLogSource.ReSetLoger;
var
  newLog:String;
begin
  if Fdbc <> nil then
  begin
    if FLoger = DefLoger then
    begin
      Loger.removeCallBack(Self, AddFmsg);
    end else begin
      FLoger.Free;
    end;
    newLog := Fdbc.dbName + '_' + Uid;
    Loger.Add('Log redirect ==> ' + newLog);
    FLoger := TeventRecorder.Create(newLog);
    Loger.registerCallBack(Self, AddFmsg);
  end;
end;

procedure TLogSource.Stop_picker;
begin
  if FLogPicker <> nil then
  begin
    FLogPicker.Terminate;
    FLogPicker.WaitFor;
    FLogPicker.Free;
    FLogPicker := nil;
  end;
end;

function TLogSource.loadFromFile(aPath: string): Boolean;
function ReadXmlAttr(xmlNode:IXMLNode;attrName:string):string;
begin
  if not xmlNode.HasAttribute(attrName) then
  begin
    raise Exception.Create('LogSource/XML/DBC.'+attrName);
  end;
  Result := xmlNode.Attributes[attrName];
end;
var
  mmo: TMemoryStream;
  xmlDoc:IXMLDocument;
  RootNode,xmlNode:IXMLNode;
begin
  Result := False;
  ClrLogSource;
  mmo := TMemoryStream.Create;
  try
    try
      FCfgFilePath := aPath;
      mmo.LoadFromFile(aPath);

      xmlDoc := TXMLDocument.Create(nil);
      mmo.Seek(0, 0);
      xmlDoc.LoadFromStream(mmo);
      xmlDoc.Active := True;
      RootNode := xmlDoc.DocumentElement;
      if RootNode.NodeName<>'LogSource' then
      begin
        raise Exception.Create('Xml格式异常');
      end;
      if RootNode.HasAttribute('uid') then
        uid := RootNode.Attributes['uid'];
      FProcCurLSN := Str2LSN(RootNode.ChildValues['LSN']);
      loadFromFile_LSN;
      xmlNode := RootNode.ChildNodes['DBC'];
      Fdbc := TdatabaseConnection.create(Self);
      Fdbc.Host := ReadXmlAttr(xmlNode, 'Host');
      Fdbc.user := ReadXmlAttr(xmlNode, 'user');
      Fdbc.PassWd := ReadXmlAttr(xmlNode, 'PassWd');
      Fdbc.dbName := ReadXmlAttr(xmlNode, 'dbName');
      Fdbc.dbID := StrToInt(ReadXmlAttr(xmlNode, 'dbID'));
      Fdbc.dbVer_Major := StrToInt(ReadXmlAttr(xmlNode, 'dbV1'));
      Fdbc.dbVer_Minor := StrToInt(ReadXmlAttr(xmlNode, 'dbV2'));
      Fdbc.dbVer_BuildNumber := StrToInt(ReadXmlAttr(xmlNode, 'dbV3'));
      xmlNode := RootNode.ChildNodes['tables'];
      Fdbc.dict.fromXml(xmlNode);

      Result := True;
      ReSetLoger;
    except
      on EE: Exception do
      begin
        Loger.Add('配置文件读取失败:' + aPath + ' >>' + EE.Message);
      end;
    end;
  finally
    mmo.Free;
  end;
end;

procedure TLogSource.loadFromFile_LSN;
var
  Fhandle:THandle;
  nrsize:Cardinal;
  LsnLSTdata:array[0..64] of AnsiChar;
  lsns:TStringList;
  I: Integer;

  Tmplsm:Tlog_LSN;
begin
  Fhandle := CreateFile(PChar(FCfgFilePath + '.lsn'), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if Fhandle = INVALID_HANDLE_VALUE then
  begin
    RaiseLastOSError;
  end;
  
  SetFilePointer(Fhandle, -52, nil, soFromEnd);
  if not ReadFile(Fhandle, LsnLSTdata[0], 52, nrsize, nil) then
  begin
    CloseHandle(Fhandle);
    raise Exception.Create('读取LSN出错：' + SysErrorMessage(GetLastError));
  end;
  CloseHandle(Fhandle);
    
  lsns := TStringList.Create;
  lsns.Text := string(LsnLSTdata);
  for I := lsns.Count-1 downto 0 do
  begin
    if (Length(lsns[i]) = 24) and lsns[i].StartsWith('0x') then
    begin
      Tmplsm := Str2LSN(lsns[i]);
      if (Tmplsm.LSN_1 <> 0) and (Tmplsm.LSN_2 <> 0) and (Tmplsm.LSN_3 <> 0) then
      begin
        FProcCurLSN := Tmplsm;
        lsns.Text := lsns[i];
        lsns.SaveToFile(FCfgFilePath + '.lsn');
        Break;
      end;
    end;
  end;
  lsns.Free; 
end;

function TLogSource.saveToFile(aPath: string): Boolean;
var
  xmlDoc:IXMLDocument;
  RootNode,xmlNode:IXMLNode;
  pathName:string;
begin
  Result := False;
  if aPath = '' then
    aPath := FCfgFilePath;
  if FCfgFilePath = '' then
    FCfgFilePath := aPath;
  if aPath <> '' then
  begin
    xmlDoc := TXMLDocument.Create(nil);
    xmlDoc.Active := True;
    xmlDoc.Encoding := 'utf-8';
    RootNode := xmlDoc.AddChild('LogSource');
    RootNode.Attributes['Cdate'] := FormatDateTime('yyyy-MM-dd HH:nn:ss.zzz', Now);
    RootNode.Attributes['uid'] := uid;
    RootNode.AddChild('LSN').Text := LSN2Str(FProcCurLSN);

    xmlNode := RootNode.AddChild('DBC');
    xmlNode.Attributes['Host'] := Fdbc.Host;
    xmlNode.Attributes['user'] := Fdbc.user;
    xmlNode.Attributes['PassWd'] := Fdbc.PassWd;
    xmlNode.Attributes['dbName'] := Fdbc.dbName;
    xmlNode.Attributes['dbID'] := Fdbc.dbID;
    xmlNode.Attributes['dbV1'] := Fdbc.dbVer_Major;
    xmlNode.Attributes['dbV2'] := Fdbc.dbVer_Minor;
    xmlNode.Attributes['dbV3'] := Fdbc.dbVer_BuildNumber;
    xmlNode := RootNode.AddChild('tables');
    Fdbc.dict.toXml(xmlNode);
    pathName := ExtractFilePath(aPath);
    if not DirectoryExists(pathName) then
    begin
      Loger.Add('目录创建:' + BoolToStr(ForceDirectories(pathName), true) + ':' + pathName);
    end;
    try
      saveToFile_LSN;
      xmlDoc.SaveToFile(aPath);
      Result := True;
    except
      on ee: Exception do
      begin
        Loger.Add('LogSource.saveToFile 配置保存失败！' + ee.message);
      end;
    end;
  end;
end;

procedure TLogSource.saveToFile_LSN;
var
  F: TextFile;
begin
  //append的方式按行存储
  AssignFile(F, FCfgFilePath + '.lsn');
  try
    if FileExists(FCfgFilePath + '.lsn') then
    begin
      Append(F);
    end
    else
    begin
      Rewrite(F);
    end;
    Writeln(F, LSN2Str(FProcCurLSN));
  finally
    CloseFile(F);
  end;
end;

{ TLogSourceList }

function TLogSourceList.Exists(Item: TLogSource): Boolean;
var
  I:Integer;
begin
  for I := 0 to ObjList.Count - 1 do
  begin
    if (Get(I).Fdbc.Host = Item.Fdbc.Host) and
       (Get(I).Fdbc.dbName = Item.Fdbc.dbName) then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

function TLogSourceList.Add(Item: TLogSource): Integer;
begin
  if not Exists(Item) then
  begin
    Result := ObjList.Add(Item);
  end else
    Result := -1;
end;

function TLogSourceList.Count: Integer;
begin
  Result := ObjList.Count;
end;

constructor TLogSourceList.Create;
begin
  ObjList := TList.Create;
end;

procedure TLogSourceList.Delete(Index: Integer);
begin
  ObjList.Delete(Index);
end;

destructor TLogSourceList.Destroy;
var
  I: Integer;
begin
  for I := 0 to ObjList.Count - 1 do
  begin
    TLogSource(ObjList[i]).free;
  end;
  ObjList.Free;
  inherited;
end;


function TLogSourceList.Get(Index: Integer): TLogSource;
begin
  Result := ObjList[Index];
end;

initialization
  LogSourceList := TLogSourceList.Create;

finalization
  LogSourceList.Free;

end.

