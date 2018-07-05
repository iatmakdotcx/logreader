unit LidxMgr;

interface

uses
  Winapi.Windows, System.Classes, System.SyncObjs;


type
  TLSNBuffer = packed record
    lsn_3: WORD;
    Offset: DWORD;
  end;


  PdictItem = ^TdictItem;

  TdictItem = packed record
    type_: Byte;
    lsn2: DWORD;
    Offset: DWord;
  end;

type
  //内存目录，避免插入数据时过多io
  TmemoIdx = class(TList)
  private
    type
      PItem = ^TItem;
      TItem = record
        lsn2: DWORD;
        Offset: DWORD;
      end;
    var
      FCs: TCriticalSection;
      FmaxItemCnt: Integer; //超出此数量时，删除最早的
    procedure checkOverFlow;
  public
    constructor Create(maxItemCnt: Integer = 100);
    destructor Destroy; override;
    procedure Append(lsn2: DWORD; Offset: DWORD);
    procedure Insert(lsn2: DWORD; Offset: DWORD; dataSize:Cardinal);
  end;


  TLidxMgr = class(TObject)
  private
    const
      IdxFileHeader: array[0..$F] of AnsiChar = ('L', 'R', 'I', 'D', 'X', 'P', 'K', 'G', #0, #0, #0, #0, #0, #0, #0, #0);
      IdxFileHeader_Version: DWORD = 1;
    var
      _optCnt:Integer;
      _FileHandle: THandle;
      dl1: TList;
      dictPnt:Pointer;
      memoIdx:TmemoIdx;
      MaxItem: Pointer;     //最大的项目
      MaxItemOffset: Dword; //最大项目的offset

      MaxItemCs: TCriticalSection;
      dl1Cs: TCriticalSection;
    function writeRow_replaceIn(Offset: DWORD; logs: TList; lsize: LARGE_INTEGER): Boolean;
    function writeRow_Insert(Offset: DWORD; Lsn2: DWORD; logs: TList; lsize: LARGE_INTEGER): Boolean;
    procedure dict_load;
    procedure dict_save;
    procedure getapplypointer(lsn2: DWORD; logs: TList; lsize: LARGE_INTEGER);
  public
    constructor Create(IdxFileHandle: THandle);
    destructor Destroy; override;
    function initCheck: Boolean;
    function writeRow(lsn2: DWORD; logs: TList; lsize: LARGE_INTEGER): Boolean;
    function findRow(lsn2: DWORD; lsn3: WORD; out dOffset:UInt64): Boolean;
  end;


implementation

uses
  loglog, System.SysUtils;


{ T3LidxMgr }

constructor TLidxMgr.Create(IdxFileHandle: THandle);
begin
  _FileHandle := IdxFileHandle;
  dl1 := TList.Create;
  memoIdx:=TmemoIdx.Create(100);

  MaxItem := AllocMem($2000);
  MaxItemOffset := 0;
  dictPnt := AllocMem($2000);
  _optCnt := 0;
  MaxItemCs := TCriticalSection.Create;
  dl1Cs := TCriticalSection.Create;
end;

destructor TLidxMgr.Destroy;
begin
  FreeMem(MaxItem);
  FreeMem(dictPnt);
  memoIdx.Free;
  dl1.Free;
  MaxItemCs.Free;
  dl1Cs.Free;
  inherited;
end;

function TLidxMgr.initCheck: Boolean;
var
  buf: Pointer;
  Rsize, nsize: Cardinal;
  tmpDictItem: PdictItem;
  filesize_L,filesize_H:Cardinal;
  lsdata:Pointer;
  Posi:Cardinal;
  tmpLsn2: DWORD;
  tmplsn3Cnt: Word;
  iLen:Cardinal;
begin
  Result := False;
  Rsize := $4000;
  //0..1k header
  //1k..2k log
  //2k..4k directory
  buf := GetMemory(Rsize);
  SetFilePointer(_FileHandle, 0, nil, soFromBeginning);
  if not ReadFile(_FileHandle, buf^, Rsize, nsize, nil) then
  begin
    Loger.add('无法读取索引文件：' + SysErrorMessage(GetLastError), LOG_ERROR);
    Exit;
  end;
  if (nsize = 0) then
  begin
    //new File
    SetFilePointer(_FileHandle, 0, nil, soFromBeginning);
    WriteFile(_FileHandle, IdxFileHeader[0], Length(IdxFileHeader), nsize, nil);

    ZeroMemory(MaxItem, $20);
    ZeroMemory(dictPnt, $100);

    tmpDictItem := dictPnt;
    tmpDictItem.type_ := 1;
    tmpDictItem.lsn2 := 0;
    tmpDictItem.Offset := $4000;
    SetFilePointer(_FileHandle, $2000, nil, soFromBeginning);
    WriteFile(_FileHandle, tmpDictItem.type_, SizeOf(TdictItem), nsize, nil);

    SetFilePointer(_FileHandle, $3FFF, nil, soFromBeginning);
    WriteFile(_FileHandle, nsize, 1, nsize, nil);

    dl1.Add(dictPnt);
  end
  else
  begin
    //效验头
    if not CompareMem(buf,@IdxFileHeader[0],$10) then
    begin
      Loger.add('索引文件格式效验无效！', LOG_ERROR);
      Exit;
    end;

    Move(Pointer(UIntPtr(buf) + $2000)^, dictPnt^, $2000);
    dict_load;
    //取最后一个目录
    tmpDictItem := dl1.Last;

    filesize_L := GetFileSize(_FileHandle, @filesize_H);
    Rsize := filesize_L - tmpDictItem.Offset;

    //搜索，最后一个项目
    if Rsize<10*1024*1024 then
    begin
      //最后一个索引之后的数据小于10Mb(一次全部读取出来
      lsdata := GetMemory(Rsize);
      SetFilePointer(_FileHandle, tmpDictItem.Offset, nil, soFromBeginning);
      ReadFile(_FileHandle, lsdata^, Rsize, nsize, nil);

      Posi := 0;
      while (Posi + 12)<=nsize do
      begin
        tmpLsn2 := PDWORD(UIntPtr(lsdata) + Posi)^;
        tmplsn3Cnt := PWord(UIntPtr(lsdata) + Posi + 4)^;
        if tmpLsn2 and $80000000 > 0 then
        begin
          iLen := 6 + tmplsn3Cnt * 10;
        end
        else
        begin
          iLen := 6 + tmplsn3Cnt * 6;
        end;
        if posi + iLen >= nSize then
        begin
          MaxItemOffset := tmpDictItem.Offset + Posi;
          Move(Pointer(UIntPtr(lsdata) + Posi)^, MaxItem^, iLen);
          Break;
        end;
        Posi := Posi + iLen;
      end;
      FreeMem(lsdata);
    end else begin
      //TODO: 循环读；新思路->逆向搜索
      Loger.AddException('索引大于10MB');
    end;
  end;
  FreeMem(buf);
  Result := True;
end;

procedure TLidxMgr.dict_load;
var
  TmpdItem:PdictItem;
begin
  TmpdItem := dictPnt;
  dl1Cs.Enter;
  try
    dl1.Clear;
    while Uintptr(TmpdItem) < (Uintptr(dictPnt) + $2000) do
    begin
      if TmpdItem.type_ = 1 then
      begin
        dl1.Add(TmpdItem);
      end
      else
      begin
        Break;
      end;
      Inc(TmpdItem);
    end;
  finally
    dl1Cs.Leave;
  end;
end;

procedure TLidxMgr.dict_save;
var
  TmpdItem:PdictItem;
  wSize, nSize:Cardinal;
begin
  if dl1.Count>0 then
  begin
    TmpdItem := dl1[dl1.Count - 1];
    if TmpdItem.Offset <> MaxItemOffset then
    begin
      TmpdItem := dictPnt;
      Inc(TmpdItem, dl1.Count);
      TmpdItem.type_ := 1;
      TmpdItem.lsn2 := PDWOrd(MaxItem)^;
      TmpdItem.Offset := MaxItemOffset;
      if dl1.Count > $380 then
      begin
        //删除第二个，依次前移
        Move(Pointer(Uintptr(dictPnt) + 2 * SizeOf(TdictItem))^, Pointer(Uintptr(dictPnt) + SizeOf(TdictItem))^, SizeOf(TdictItem) * (dl1.Count + 1));
      end else begin
        //后面追加

      end;
      wSize := $2000;
      SetFilePointer(_FileHandle, wSize, nil, soFromBeginning);
      ReadFile(_FileHandle, dictPnt^, wSize, nSize, nil);
      dict_load;
    end;
  end;

end;

function TLidxMgr.findRow(lsn2: DWORD; lsn3: WORD; out dOffset: UInt64): Boolean;
var
  tmpLsn2:Dword;
  tmpLsn3Cnt:Word;
  I, J: Integer;
  tptp:TmemoIdx.PItem;
  tmpDictItem: PdictItem;
  BlockSize:Cardinal;
  dlEPosi:Cardinal;   //记录mmoidx的开始位置，之后查找索引就到这个位置结束即可。
  buf:Pointer;
  nSize:Cardinal;
  posi:Cardinal;
  isX64Addr:Boolean;
begin
  Result := False;
  MaxItemCs.Enter;
  try
    tmpLsn2 := PDWORD(MaxItem)^;
  except
    MaxItemCs.Leave;
    Exit;
  end;
  tmpLsn2 := tmpLsn2 and $7FFFFFFF;
  if lsn2 = tmpLsn2 then
  begin
    try
      tmpLsn3Cnt := PWORD(UIntPtr(MaxItem)+4)^;
      for I := 0 to tmpLsn3Cnt-1 do
      begin
        if PWORD(UIntPtr(MaxItem) + 6 + I * 2)^ = lsn3 then
        begin
          if (tmpLsn2 and $80000000) > 0 then
          begin
            //x64
            dOffset := PUint64(UIntPtr(MaxItem) + 6 + tmpLsn3Cnt * 2 + I * 8)^
          end else begin
            //x86
            dOffset := PDword(UIntPtr(MaxItem) + 6 + tmpLsn3Cnt * 2 + I * 4)^
          end;
          Result := True;
        end;
      end;
    finally
      MaxItemCs.Leave;
    end;
    Exit;
  end
  else if lsn2 < tmpLsn2 then
  begin
    MaxItemCs.Leave;
    dlEPosi := 0;
    //search memoIdx
    memoIdx.FCs.Enter;
    try
      if memoIdx.Count > 0 then
      begin
        tptp := TmemoIdx.PItem(memoIdx.Get(0));
        dlEPosi := tptp.Offset;
        if lsn2 > tptp.lsn2 then
        begin
          for I := memoIdx.Count - 1 downto 0 do
          begin
            tptp := TmemoIdx.PItem(memoIdx.Get(i));
            if lsn2 = tptp.lsn2 then
            begin
              dOffset := tptp.Offset;
              Result := True;
              Exit;
            end;
          end;
        end;
      end;
    finally
      memoIdx.FCs.Leave;
    end;

    //search
    dl1Cs.Enter;
    try

      for I := dl1.Count-1 Downto 0 do
      begin
        tmpDictItem := dl1[i];
        if lsn2 >= tmpDictItem.lsn2 then
        begin
          if i = dl1.Count-1 then
          begin
            BlockSize := 0;
            if dlEPosi=0 then
            begin
              //没有mmoidx，直接取文件末尾
              dlEPosi := GetFileSize(_FileHandle, nil);
            end;
            if dlEPosi < tmpDictItem.Offset then
            begin
              Loger.Add('TLidxMgr.findRow[dlEPosi < tmpDictItem.Offset] 畸形索引文件', LOG_ERROR);
              Exit;
            end;
            BlockSize := dlEPosi - tmpDictItem.Offset;
          end else begin
            BlockSize := PdictItem(dl1[i+1])^.Offset - tmpDictItem.Offset;
          end;
          if BlockSize> 100*1024*1024 then
          begin
            Loger.Add('TLidxMgr.findRow[BlockSize > 100MB] 畸形索引文件', LOG_ERROR);
            Exit;
          end;

          buf := GetMemory(BlockSize);
          try
            SetFilePointer(_FileHandle, tmpDictItem.Offset, nil, soFromBeginning);
            if ReadFile(_FileHandle, buf^, BlockSize, nSize, nil) and (nSize>0) then
            begin
              posi := 0;
              while posi + 12 < nSize do
              begin
                tmpLsn2 := PDWord(UINT_PTR(buf) + posi)^;
                tmplsn3Cnt := PWord(UINT_PTR(buf) + 4 + posi)^;
                isX64Addr := (tmpLsn2 and $80000000) > 0;
                if isX64Addr then
                  tmpLsn2 := tmpLsn2 and $7FFFFFFF;
                if tmpLsn2 = lsn2 then
                begin
                  for J := 0 to tmpLsn3Cnt-1 do
                  begin
                    if PWORD(UINT_PTR(buf) + posi + 6 + J * 2)^ = lsn3 then
                    begin
                      if isX64Addr then
                      begin
                        //x64
                        dOffset := PUint64(UINT_PTR(buf) + posi + 6 + tmpLsn3Cnt * 2 + J * 8)^
                      end else begin
                        //x86
                        dOffset := PDword(UINT_PTR(buf) + posi + 6 + tmpLsn3Cnt * 2 + J * 4)^
                      end;
                      Result := True;
                    end;
                  end;
                  exit;
                end else if tmpLsn2 > lsn2 then
                begin
                  //未找到
                  Loger.Add('TLidxMgr.findRow 未找到', LOG_WARNING);
                  Exit;
                end else begin
                  //继续查找下一个
                end;
                if isX64Addr then
                begin
                  posi := posi + 6 + tmpLsn3Cnt * (2 + 8);
                end
                else
                begin
                  posi := posi + 6 + tmpLsn3Cnt * (2 + 4);
                end;
              end;
            end;
          finally
            FreeMemory(buf);
          end;
          Exit;
        end;
      end;
    finally
      dl1Cs.Leave;
    end;
  end
  else
  begin
    MaxItemCs.Leave;
    //大于MaxItem的，肯定是空的
  end;
end;

function TLidxMgr.writeRow_replaceIn(Offset: DWORD; logs: TList; lsize: LARGE_INTEGER): Boolean;
var
  lastCnt: Cardinal;
  tmpLsn2: DWORD;
  tmplsn3Cnt: Word;
  FileLen: Cardinal;
  newBlockSize: Cardinal;
  newBlockData: Pointer;
  newlsn3Cnt: Cardinal;
  oldBlockSize: Cardinal;
  oldlsn3s: array of Word;
  oldOffset: array of UInt64;
  I: Integer;
  tmpLsn: ^TLSNBuffer;
  nSize: Cardinal;
  buf:Pointer;
begin
  FileLen := GetFileSize(_FileHandle, nil);
  lastCnt := FileLen - Offset;
  //读老数据
  buf := GetMemory(lastCnt);
  if Offset = MaxItemOffset then
  begin
    Move(maxitem^, buf^, lastCnt);
  end else begin
    SetFilePointer(_FileHandle, Offset, nil, soFromBeginning);
    ReadFile(_FileHandle, buf^, lastCnt, nSize, nil);
  end;
  tmpLsn2 := PDWord(buf)^;
  tmplsn3Cnt := PWord(UINT_PTR(buf) + 4)^;
  SetLength(oldlsn3s, tmplsn3Cnt);
  for I := 0 to tmplsn3Cnt - 1 do
  begin
    oldlsn3s[I] := PWord(UINT_PTR(buf) + 6 + I * 2)^;
  end;
  SetLength(oldOffset, tmplsn3Cnt);
  if (tmpLsn2 and $80000000 > 0) then
  begin
    oldBlockSize := 4 + 2 + tmplsn3Cnt * (2 + 8);
    for I := 0 to tmplsn3Cnt - 1 do
    begin
      oldOffset[I] := PUint64(UINT_PTR(buf) + 6 + tmplsn3Cnt * 2 + I * 8)^;
    end;
  end
  else
  begin
    oldBlockSize := 4 + 2 + tmplsn3Cnt * (2 + 4);
    for I := 0 to tmplsn3Cnt - 1 do
    begin
      oldOffset[I] := PDWord(UINT_PTR(buf) + 6 + tmplsn3Cnt * 2 + I * 4)^;
    end;
  end;
  //准备新数据
  newlsn3Cnt := tmplsn3Cnt + logs.Count;

  SetLength(oldlsn3s, newlsn3Cnt);
  SetLength(oldOffset, newlsn3Cnt);
  for I := 0 to logs.Count - 1 do
  begin
    tmpLsn := logs[I];
    oldlsn3s[tmplsn3Cnt + I] := tmpLsn.lsn_3;
    oldOffset[tmplsn3Cnt + I] := tmpLsn.Offset + lsize.QuadPart;
  end;
  //减自身节点长度
  lastCnt := lastCnt - oldBlockSize;
  if (tmpLsn2 and $80000000 > 0) or (lsize.HighPart > 0) then
  begin
    //is 64bit addr
    newBlockSize := 4 + 2 + newlsn3Cnt * (2 + 8);
    newBlockData := GetMemory(newBlockSize + lastCnt);
    PDWORD(newBlockData)^ := tmpLsn2 or $80000000;
    PWORD(UINT_PTR(newBlockData) + 4)^ := newlsn3Cnt;
    for I := 0 to newlsn3Cnt - 1 do
    begin
      PWORD(UINT_PTR(newBlockData) + 6 + I * 2)^ := oldlsn3s[I];
    end;
    for I := 0 to newlsn3Cnt - 1 do
    begin
      Puint64(UINT_PTR(newBlockData) + 6 + newlsn3Cnt * 2 + I * 8)^ := oldOffset[I];
    end;
  end
  else
  begin
    newBlockSize := 4 + 2 + newlsn3Cnt * (2 + 4);
    newBlockData := GetMemory(newBlockSize + lastCnt);
    PDWORD(newBlockData)^ := tmpLsn2;
    PWORD(UINT_PTR(newBlockData) + 4)^ := newlsn3Cnt;
    for I := 0 to newlsn3Cnt - 1 do
    begin
      PWORD(UINT_PTR(newBlockData) + 6 + I * 2)^ := oldlsn3s[I];
    end;
    for I := 0 to newlsn3Cnt - 1 do
    begin
      PDWORD(UINT_PTR(newBlockData) + 6 + newlsn3Cnt * 2 + I * 4)^ := oldOffset[I];
    end;
  end;
  //数据后移
  //之后的全部读出来，再写回去
  if lastCnt > 0 then
  begin
    Move(Pointer(UINT_PTR(buf) + oldBlockSize)^, Pointer(UINT_PTR(newBlockData) + newBlockSize)^, lastCnt);
  end;

  SetFilePointer(_FileHandle, Offset, nil, soFromBeginning);
  WriteFile(_FileHandle, newBlockData^, newBlockSize + lastCnt, nSize, nil);

  if MaxItemOffset = Offset then
  begin
    //修改了最后一个
    //更新 MaxItem
    MaxItemcs.Enter;
    try
      Move(newBlockData^, MaxItem^, newBlockSize);
    finally
      MaxItemcs.Leave;
    end;
  end else begin
    MaxItemOffset := MaxItemOffset + (newBlockSize - oldBlockSize);
    memoIdx.Insert(tmpLsn2, Offset,newBlockSize - oldBlockSize);
  end;
  FreeMem(newBlockData);
  FreeMem(buf);
  Result := True;
end;

function TLidxMgr.writeRow_Insert(Offset: DWORD; Lsn2: DWORD; logs: TList; lsize: LARGE_INTEGER): Boolean;
var
  lastCnt: Cardinal;
  FileLen: Cardinal;
  newBlockSize: Cardinal;
  newBlockData: Pointer;
  I: Integer;
  tmpLsn: ^TLSNBuffer;
  nSize: Cardinal;
begin
  FileLen := GetFileSize(_FileHandle, nil);
  lastCnt := FileLen - Offset;
  //准备数据
  if lsize.HighPart > 0 then
  begin
    //is 64bit addr
    newBlockSize := 4 + 2 + logs.Count * (2 + 8);
    newBlockData := GetMemory(newBlockSize + lastCnt);
    PDWORD(newBlockData)^ := Lsn2 or $80000000;
    PWORD(UINT_PTR(newBlockData) + 4)^ := logs.Count;
    for I := 0 to logs.Count - 1 do
    begin
      tmpLsn := logs[I];
      PWORD(UINT_PTR(newBlockData) + 6 + I * 2)^ := tmpLsn.lsn_3;
    end;
    for I := 0 to logs.Count - 1 do
    begin
      tmpLsn := logs[I];
      Puint64(UINT_PTR(newBlockData) + 6 + logs.Count * 2 + I * 8)^ := lsize.QuadPart + tmpLsn.Offset;
    end;
  end
  else
  begin
    newBlockSize := 4 + 2 + logs.Count * (2 + 4);
    newBlockData := GetMemory (newBlockSize + lastCnt);
    PDWORD(newBlockData)^ := Lsn2;
    PWORD(UINT_PTR(newBlockData) + 4)^ := logs.Count;
    for I := 0 to logs.Count - 1 do
    begin
      tmpLsn := logs[I];
      PWORD(UINT_PTR(newBlockData) + 6 + I * 2)^ := tmpLsn.lsn_3;
    end;
    for I := 0 to logs.Count - 1 do
    begin
      tmpLsn := logs[I];
      PDWORD(UINT_PTR(newBlockData) + 6 + logs.Count * 2 + I * 4)^ := lsize.LowPart + tmpLsn.Offset;
    end;
  end;
  //数据后移
  //之后的全部读出来，再写回去
  SetFilePointer(_FileHandle, Offset, nil, soFromBeginning);
  ReadFile(_FileHandle, Pointer(UINT_PTR(newBlockData) + newBlockSize)^, lastCnt, nSize, nil);

  SetFilePointer(_FileHandle, Offset, nil, soFromBeginning);
  WriteFile(_FileHandle, newBlockData^, newBlockSize + lastCnt, nSize, nil);

  MaxItemOffset := MaxItemOffset + newBlockSize;
  memoIdx.Insert(Lsn2, Offset, newBlockSize);
  FreeMem(newBlockData);
  Result := True;
end;

function TLidxMgr.writeRow(lsn2: DWORD; logs: TList; lsize: LARGE_INTEGER): Boolean;
var
  oSize, nSize: Cardinal;
  tmpLsn: ^TLSNBuffer;
  buf: Pointer;
  J: Integer;
  MaxLsn2: DWORD;
begin
  Result := False;
  if (logs.Count = 0) then
    Exit;

  MaxLsn2 := PDWORD(MaxItem)^ and $7FFFFFFF;
  if lsn2 > MaxLsn2 then
  begin
    //append
    if lsize.HighPart > 0 then
    begin
      //64位地址 （文件大于4GB
      oSize := SizeOf(DWORD) + SizeOf(WORD) + logs.Count * SizeOf(WORD) + logs.Count * SizeOf(uint64);
      buf := AllocMem(oSize + 10);
      PDWORD(buf)^ := lsn2 or $80000000;
      PWORD(UINT_PTR(buf) + 4)^ := logs.Count;
      for J := 0 to logs.Count - 1 do
      begin
        tmpLsn := logs[J];
        PWORD(UINT_PTR(buf) + 6 + UINT_PTR(J * 2))^ := tmpLsn.lsn_3;
        PUINT64(UINT_PTR(buf) + 6 + logs.Count * 2 + UINT_PTR(J * 8))^ := lsize.QuadPart + tmpLsn.Offset;
      end;
    end
    else
    begin
      oSize := SizeOf(DWORD) + SizeOf(WORD) + logs.Count * SizeOf(WORD) + logs.Count * SizeOf(DWORD);
      buf := AllocMem(oSize + 10);
      PDWORD(buf)^ := lsn2;
      PWORD(UINT_PTR(buf) + 4)^ := logs.Count;
      for J := 0 to logs.Count - 1 do
      begin
        tmpLsn := logs[J];
        PWORD(UINT_PTR(buf) + 6 + UINT_PTR(J * 2))^ := tmpLsn.lsn_3;
        PDWORD(UINT_PTR(buf) + 6 + logs.Count * 2 + UINT_PTR(J * 4))^ := lsize.LowPart + tmpLsn.Offset;
      end;
    end;
    MaxItemOffset := SetFilePointer(_FileHandle, 0, nil, soFromEnd);
    WriteFile(_FileHandle, buf^, oSize, nSize, nil);

    MaxItemcs.Enter;
    try
      Move(buf^, MaxItem^, oSize);
    finally
      MaxItemcs.Leave;
    end;
    memoIdx.Append(lsn2, MaxItemOffset);
    FreeMem(buf);
    Result := True;
  end
  else if lsn2 = MaxLsn2 then
  begin
    //replace last
    writeRow_replaceIn(MaxItemOffset, logs, lsize);
  end
  else
  begin
    //insert
    getapplypointer(lsn2, logs, lsize);
  end;
  Inc(_optCnt);
  if _optCnt>100 then
  begin
    _optCnt :=0;
    dict_save;
  end;
end;

procedure TLidxMgr.getapplypointer(lsn2:DWORD; logs: TList; lsize: LARGE_INTEGER);
var
  I: Integer;
  TmpdItem:PdictItem;
  Rsize, nsize: Cardinal;
  filesize_L,filesize_H:Cardinal;
  lsdata:Pointer;
  Posi:Cardinal;
  tmpLsn2: DWORD;
  tmplsn3Cnt: Word;
  iLen:Cardinal;
  tmpitem:TmemoIdx.PItem;
begin
  memoIdx.FCs.Enter;
  try
    for I := memoIdx.Count - 1 downto 0 do
    begin
      tmpitem := TmemoIdx.PItem(memoIdx.Items[I]);
      if tmpitem.lsn2 = lsn2 then
      begin
        writeRow_replaceIn(tmpitem.Offset, logs, lsize);
        Exit;
      end else if tmpitem.lsn2 < lsn2 then
      begin
        writeRow_Insert(TmemoIdx.PItem(memoIdx.Items[I+1]).Offset, lsn2, logs, lsize);
        Exit;
      end;
    end;
  finally
    memoIdx.FCs.Leave;
  end;

  for I := dl1.Count-1 downto 0 do
  begin
    TmpdItem := dl1[i];
    if TmpdItem.lsn2=lsn2 then
    begin
      writeRow_replaceIn(TmpdItem.Offset, logs, lsize);
      Exit;
    end else if TmpdItem.lsn2 < lsn2 then begin
      //块后
      filesize_L := GetFileSize(_FileHandle, @filesize_H);
      Rsize := filesize_L - TmpdItem.Offset;

      if Rsize<10*1024*1024 then
      begin
        //索引之后的数据小于10Mb(一次全部读取出来
        lsdata := GetMemory(Rsize);
        SetFilePointer(_FileHandle, TmpdItem.Offset, nil, soFromBeginning);
        ReadFile(_FileHandle, lsdata^, Rsize, nsize, nil);

        Posi := 0;
        while (Posi + 12)<nsize do
        begin
          tmpLsn2 := PDWORD(UIntPtr(lsdata) + Posi)^;
          tmplsn3Cnt := PWord(UIntPtr(lsdata) + Posi + 4)^;
          if tmpLsn2 and $80000000 > 0 then
          begin
            iLen := 6 + tmplsn3Cnt * 10;
          end
          else
          begin
            iLen := 6 + tmplsn3Cnt * 6;
          end;
          if posi + iLen > nSize then
          begin
            //no more data
            Break;
          end;

          tmpLsn2 := tmpLsn2 and $7FFFFFFF;
          if tmpLsn2 = lsn2 then
          begin
            writeRow_replaceIn(TmpdItem.Offset + Posi, logs, lsize);
            Break;
          end else if tmpLsn2 > lsn2 then
          begin
            writeRow_Insert(TmpdItem.Offset + Posi, lsn2, logs, lsize);
            Break;
          end;
          Posi := Posi + iLen;
        end;
        FreeMem(lsdata);
      end else begin
        //TODO: 循环读
        Loger.AddException('索引分页大于10MB');
      end;
      Exit;
    end else begin
      //块前
    end;
  end;

end;


{ TmemoIdx }
procedure TmemoIdx.Append(lsn2, Offset: DWORD);
var
  tmpitem:PItem;
begin
  FCs.Enter;
  try
    New(tmpitem);
    tmpitem.lsn2 := lsn2;
    tmpitem.Offset := Offset;
    Add(tmpitem);
    checkOverFlow;
  finally
    FCs.Leave;
  end;
end;

procedure TmemoIdx.checkOverFlow;
begin
  if Count > FmaxItemCnt then
  begin
    Dispose(Items[0]);
    Delete(0);
  end;
end;

constructor TmemoIdx.Create(maxItemCnt: Integer);
begin
  FmaxItemCnt := maxItemCnt;
  FCs := TCriticalSection.Create;
end;

destructor TmemoIdx.Destroy;
begin
  FCs.Free;
  inherited;
end;

procedure TmemoIdx.Insert(lsn2, Offset: DWORD; dataSize: Cardinal);
var
  tmpitem,tmp:PItem;
  I: Integer;
begin
  FCs.Enter;
  try
    for I := Count - 1 downto 0 do
    begin
      tmp := PItem(Items[i]);
      if tmp.lsn2 = lsn2 then
      begin
        Break;
      end else if tmp.lsn2 > lsn2 then begin
        //继续向前查找，因为是insert到前面的，Offset要后移
        tmp.Offset := tmp.Offset + dataSize;
      end else if tmp.lsn2 < lsn2 then begin
        New(tmpitem);
        tmpitem.lsn2 := lsn2;
        tmpitem.Offset := Offset;
        inherited Insert(I+1, tmpitem);
        Break;
      end;
    end;
    checkOverFlow;
  finally
    FCs.Leave;
  end;
end;

end.
