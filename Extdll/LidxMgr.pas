unit LidxMgr;

interface

uses
  Winapi.Windows, System.Classes;


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
  TLidxMgr = class(TObject)
  private
    const
      IdxFileHeader: array[0..$F] of AnsiChar = ('L', 'R', 'I', 'D', 'X', 'P', 'K', 'G', #0, #0, #0, #0, #0, #0, #0, #0);
      IdxFileHeader_Version: DWORD = 1;
    var
      _FileHandle: THandle;
      dl1: TList;
      dictPnt:Pointer;
      MaxItem: Pointer;     //最大的项目
      MaxItemOffset: Dword; //最大项目的offset
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
  end;


implementation

uses
  pluginlog, System.SysUtils;


{ T3LidxMgr }

constructor TLidxMgr.Create(IdxFileHandle: THandle);
begin
  _FileHandle := IdxFileHandle;
  dl1 := TList.Create;
  MaxItem := AllocMem($2000);
  MaxItemOffset := 0;
  dictPnt := AllocMem($2000);
end;

destructor TLidxMgr.Destroy;
begin
  dl1.Free;
  FreeMem(MaxItem);
  FreeMem(dictPnt);
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

    dl1.Add(dictPnt);

    MaxItemOffset := $4000;
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
end;

procedure TLidxMgr.dict_load;
var
  TmpdItem:PdictItem;
begin
  TmpdItem := dictPnt;
  while Uintptr(TmpdItem) < (Uintptr(dictPnt) + $2000) do
  begin
    if TmpdItem.type_=1 then
    begin
      dl1.Add(TmpdItem);
    end else begin
      Break;
    end;
//    TmpdItem := Pointer(Uintptr(TmpdItem)+SizeOf(TdictItem));
    Inc(TmpdItem);
  end;
end;

procedure TLidxMgr.dict_save;
begin


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
  if Offset=MaxItemOffset then
  begin
    Move(maxitem^, buf^, lastCnt);
  end else begin
    SetFilePointer(_FileHandle, Offset, nil, soFromBeginning);
    ReadFile(_FileHandle, buf^, lastCnt, nsize, nil);
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
    SetFilePointer(_FileHandle, Offset + oldBlockSize, nil, soFromBeginning);
    ReadFile(_FileHandle, Pointer(UINT_PTR(newBlockData) + newBlockSize)^, lastCnt, nSize, nil);
  end;

  SetFilePointer(_FileHandle, Offset, nil, soFromBeginning);
  WriteFile(_FileHandle, newBlockData^, newBlockSize + lastCnt, nSize, nil);

  if MaxItemOffset=Offset then
  begin
    //更新 MaxItem
    Move(newBlockData^, MaxItem^, newBlockSize);
  end else begin
    MaxItemOffset := MaxItemOffset+(newBlockSize-oldBlockSize);
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
  tmpLsn := logs[0];

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
    MaxItemOffset := SetFilePointer(_FileHandle, MaxItemOffset, nil, soFromBeginning);
    WriteFile(_FileHandle, buf^, oSize, nSize, nil);

    Move(buf^, MaxItem^, oSize);
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
begin
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


end.
