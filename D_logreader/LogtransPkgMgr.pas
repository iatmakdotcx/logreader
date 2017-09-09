unit LogtransPkgMgr;

interface

uses
  System.Contnrs, System.Classes, p_structDefine, LogtransPkg, Types;

type
  TaddRawLog_STATUS = (Pkg_Ignored = 0, Pkg_OK = 1, Pkg_Err_NoBegin = $F1);
  TOnTransPkgOk = procedure(pkg:TTransPkg) of object;

type
  TTransPkgMgr = class(TObject)
  private
    FItems: TObjectList;
    FSubs_func:TList;
    procedure DeleteTransPkg(transid: TTrans_Id);
    function GetTransPkg(transid: TTrans_Id): TTransPkg;
    procedure NotifySubscribe(lsn: Tlog_LSN; Raw: TMemory_data);
    procedure RegLogRowRead;
  public
    FOnTransPkgOk:TOnTransPkgOk;
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///
    /// </summary>
    /// <param name="lsn"></param>
    /// <param name="Raw"></param>
    /// <param name="ExtQuery">��չ���ݣ�����Ҫ֪ͨ���</param>
    /// <returns></returns>
    function addRawLog(lsn: Tlog_LSN; Raw: TMemory_data; ExtQuery:Boolean): TaddRawLog_STATUS;
  end;

implementation

uses
  OpCode, plugins;

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
      LOP_FORMAT_PAGE,  //�����汣����ҳ��ֵ�����Ի����Լ����������
      LOP_INSERT_ROWS,  //����
      LOP_DELETE_ROWS,   //ɾ��
      LOP_MODIFY_ROW,  //�޸ĵ�����
      LOP_MODIFY_COLUMNS: //�޸Ķ����
        begin
          TTsPkg := GetTransPkg(RawLog.TransID);
          if TTsPkg <> nil then
          begin
            TTsPkg.addRawLog(TTransPkgItem.Create(lsn, Raw));
          end
          else
          begin
            //�������ݲ�ȫ����ֱ�Ӷ�������LOP_COMMIT_XACT��ʱ��ᵥ����ȡ
            Result := Pkg_Ignored;
          end;
        end;
      LOP_BEGIN_XACT:  //��������
        begin
          TTsPkg := TTransPkg.Create(RawLog.TransID);
          TTsPkg.addRawLog(TTransPkgItem.Create(lsn, Raw));
          FItems.Add(TTsPkg);
        end;
      LOP_COMMIT_XACT:  //�ύ����
        begin
          TTsPkg := GetTransPkg(RawLog.TransID);
          if TTsPkg <> nil then
          begin
            TTsPkg.addRawLog(TTransPkgItem.Create(lsn, Raw));
            //TODO 5: ��������Ӧ�ô�����͸���һ����
            //loger.Add('pkg LOP_COMMIT_XACT...');

            if TTsPkg.Items.Count < 3 then
            begin
              //�����������ݲ�����Ч����
              FItems.Remove(TTsPkg);
            end else begin
              FItems.OwnsObjects := False; //���ͷŵ�ǰԪ��
              try
                FItems.Remove(TTsPkg);
              finally
                FItems.OwnsObjects := True;
              end;
              if Assigned(FOnTransPkgOk) then
                FOnTransPkgOk(TTsPkg);
            end;
          end
          else
          begin
            //�������ݲ�ȫ����Ҫ������ȡ
            Result := Pkg_Err_NoBegin;
          end;
        end;
      LOP_ABORT_XACT:  //�ع�����
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
  inherited create;

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
        pln(@lsn, @Raw);
      end;
    except
    end;
  end;
end;


end.
