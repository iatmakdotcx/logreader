unit LogtransPkg;

interface

uses
  p_structDefine, Contnrs, Classes;

type
  TaddRawLog_STATUS = (Pkg_Ignored = 0, Pkg_OK = 1, Pkg_Err_NoBegin = $F1);

type
  TTransPkgItem = class(TObject)
    LSN: Tlog_LSN;
    Raw: TMemory_data;
    constructor Create(lsn: Tlog_LSN; Raw: TMemory_data);
    destructor Destroy; override;
  end;

type
  TTransPkg = class(TObject)
  private
    FItems: TObjectList;
  public
    Ftransid: TTrans_Id;
    constructor Create(transid: TTrans_Id);
    destructor Destroy; override;
    procedure addRawLog(log: TTransPkgItem);
    property Items:TObjectList read FItems;
  end;

  TTransPkgMgr = class(TObject)
  private
    FItems: TObjectList;
    FSubs_func:TList;
    procedure DeleteTransPkg(transid: TTrans_Id);
    function GetTransPkg(transid: TTrans_Id): TTransPkg;
    procedure NotifySubscribe(lsn: Tlog_LSN; Raw: TMemory_data);
    procedure RegLogRowRead;
  public
    constructor Create();
    destructor Destroy; override;
    /// <summary>
    ///
    /// </summary>
    /// <param name="lsn"></param>
    /// <param name="Raw"></param>
    /// <param name="ExtQuery">扩展数据，需要需通知插件</param>
    /// <returns></returns>
    function addRawLog(lsn: Tlog_LSN; Raw: TMemory_data; ExtQuery:Boolean): TaddRawLog_STATUS;
  end;

implementation

uses
  OpCode, pluginlog, plugins, Windows, Sql2014LogReader, Types;

{ TTransPkg }

procedure TTransPkg.addRawLog(log: TTransPkgItem);
begin
  FItems.Add(log);
end;

constructor TTransPkg.Create(transid: TTrans_Id);
begin
  FItems := TObjectList.Create;
  Ftransid := transid;
end;

destructor TTransPkg.Destroy;
begin
  FItems.Clear;
  FItems.Free;
  inherited;
end;

{ TTransPkgMgr }

function TTransPkgMgr.addRawLog(lsn: Tlog_LSN; Raw: TMemory_data; ExtQuery:Boolean): TaddRawLog_STATUS;
var
  RawLog: PRawLog;
  TTsPkg: TTransPkg;
begin
  if Raw.dataSize < SizeOf(TRawLog) then
  begin
    Result := Pkg_Ignored;
  end else begin
    if not ExtQuery then    
      NotifySubscribe(lsn, Raw);
    Result := Pkg_OK;
    RawLog := Raw.data;
    case RawLog.OpCode of
      LOP_FORMAT_PAGE,  //这里面保存有页的值，可以缓存以计算操作内容
      LOP_INSERT_ROWS,  //新增
      LOP_DELETE_ROWS,   //删除
      LOP_MODIFY_ROW,  //修改单个块
      LOP_MODIFY_COLUMNS: //修改多个块
        begin
          TTsPkg := GetTransPkg(RawLog.TransID);
          if TTsPkg <> nil then
          begin
            TTsPkg.addRawLog(TTransPkgItem.Create(lsn, Raw));
          end
          else
          begin
            //本地数据不全，先直接丢弃，在LOP_COMMIT_XACT的时候会单独提取
            Result := Pkg_Ignored;
          end;
        end;
      LOP_BEGIN_XACT:  //新事务开启
        begin
          TTsPkg := TTransPkg.Create(RawLog.TransID);
          TTsPkg.addRawLog(TTransPkgItem.Create(lsn, Raw));
          FItems.Add(TTsPkg);
        end;
      LOP_COMMIT_XACT:  //提交事务
        begin
          TTsPkg := GetTransPkg(RawLog.TransID);
          if TTsPkg <> nil then
          begin
            TTsPkg.addRawLog(TTransPkgItem.Create(lsn, Raw));
            //TODO 5: 这里数据应该打包发送给下一流程
            //loger.Add('pkg LOP_COMMIT_XACT...');

            FItems.OwnsObjects := False; //不释放当前元素
            try
              FItems.Remove(TTsPkg);
            finally
              FItems.OwnsObjects := True;
            end;
            TSql2014logAnalyzer.Create(TTsPkg);
          end
          else
          begin
            //本地数据不全，需要单独提取
            Result := Pkg_Err_NoBegin;
          end;
        end;
      LOP_ABORT_XACT:  //回滚事务
        begin
          DeleteTransPkg(RawLog.TransID);
          Result := Pkg_Ignored;
        end;
    else
      Result := Pkg_Ignored;
    end;
  end;
  if (Result = Pkg_Ignored)then
  begin
    FreeMem(Raw.data);
  end;
end;


constructor TTransPkgMgr.Create;
begin
  inherited;
  
  FItems := TObjectList.Create;
  FSubs_func := TList.Create;

  RegLogRowRead;
end;

procedure TTransPkgMgr.RegLogRowRead;
var
  i:Integer;
begin
  for i := 0 to PluginsMgr.Count - 1 do
  begin
    if Assigned(PluginsMgr.Items[i]._Lr_PluginRegLogRowRead) then
    begin
      FSubs_func.Add(@PluginsMgr.Items[i]._Lr_PluginRegLogRowRead);
    end;
  end;
end;


procedure TTransPkgMgr.DeleteTransPkg(transid: TTrans_Id);
var
  I: Integer;
  Tpkg: TTransPkg;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    Tpkg := FItems[I] as TTransPkg;
    if (Tpkg.Ftransid.Id1 = transid.Id1) and (Tpkg.Ftransid.Id2 = transid.Id2) then
    begin
      FItems.Delete(I);
      Break;
    end;
  end;
end;

destructor TTransPkgMgr.Destroy;
begin
  FItems.Free;
  FSubs_func.Free;
  inherited;
end;

function TTransPkgMgr.GetTransPkg(transid: TTrans_Id): TTransPkg;
var
  I: Integer;
  Tpkg: TTransPkg;
begin
  Result := nil;
  for I := 0 to FItems.Count - 1 do
  begin
    Tpkg := FItems[I] as TTransPkg;
    if (Tpkg.Ftransid.Id1 = transid.Id1) and (Tpkg.Ftransid.Id2 = transid.Id2) then
    begin
      Result := Tpkg;
      Break;
    end;
  end;
end;

procedure TTransPkgMgr.NotifySubscribe(lsn: Tlog_LSN; Raw: TMemory_data);
var
  I: Integer;
  pln:T_Lr_PluginRegLogRowRead;
begin
  for I := 0 to FSubs_func.Count - 1 do
  begin
    try
      @pln := FSubs_func[i];
      if Assigned(pln) then
      begin
        try
          pln(@lsn, @Raw);
        except
        end;
      end;
    except
    end;
  end;
end;

{ TTransPkgItem }

constructor TTransPkgItem.Create(lsn: Tlog_LSN; Raw: TMemory_data);
begin
  Self.LSN := lsn;
  Self.Raw := Raw;
end;

destructor TTransPkgItem.Destroy;
begin
  if Raw.data <> nil then
  begin
    FreeMem(Raw.data);
  end;
  inherited;
end;

end.

