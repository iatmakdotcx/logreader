unit logRecdItemReader;

interface

uses
  Winapi.Windows, MsOdsApi;

/// <summary>
/// ����lsn1��ȡ�������ȫ��lsn
/// </summary>
/// <param name="dbid"></param>
/// <param name="Lsn1"></param>
/// <returns></returns>
function Read_logAll(dbid: Byte; Lsn1: Dword):string;

/// <summary>
///  ����һ��lsn��ȡ��Ӧ��RawData
/// </summary>
/// <param name="dbid"></param>
/// <param name="Lsn1"></param>
/// <param name="Lsn2"></param>
/// <param name="Lsn3"></param>
/// <returns></returns>
function Read_log_One(dbid: Byte; Lsn1: Dword; Lsn2: Dword; Lsn3: word):string;stdcall;

/// <summary>
/// �� xml��ʽ�����ݼ�����TableResults���
/// </summary>
/// <param name="pSrvProc"></param>
/// <param name="Lsn1"></param>
/// <param name="xmlData"></param>
procedure Read_logXmlToTableResults(pSrvProc: SRV_PROC; Lsn1:DWORD; xmlData :String);


implementation

uses
  System.SysUtils, System.Classes, Memory_Common, pluginlog, XMLDoc,XMLIntf, SqlSvrHelper;

procedure Read_logXmlToTableResults(pSrvProc: SRV_PROC; Lsn1:DWORD; xmlData :String);
var
  lsnVal:PAnsiChar;
  Xml: IXMLDocument;
  Rootnode : IXMLNode;
  I: Integer;
  //
  TmpStr:string;
  lsn2:DWORD;
  lsn3:Word;
  RawData:string;
  RawDataPointer:TBytes;
begin
  srv_describe(pSrvProc, 1, 'LSN', SRV_NULLTERM, SRVCHAR, 22, SRVCHAR, 22, nil);
  srv_describe(pSrvProc, 2, 'data', SRV_NULLTERM, SRV_TDS_IMAGE, 0, SRVBIGVARCHAR, 0, nil);

  Xml:=TXMLDocument.create(nil);
  try
    try
      Xml.LoadFromXML(xmlData);
      xml.Active := True;
      Rootnode := Xml.DocumentElement;
      for I := 0 to Rootnode.ChildNodes.Count-1 do
      begin
        if Rootnode.ChildNodes[I].NodeName='row' then
        begin
          TmpStr := Rootnode.ChildNodes[I].ChildNodes.FindNode('LSN2').Text;
          lsn2 := StrToInt(TmpStr);
          TmpStr := Rootnode.ChildNodes[I].ChildNodes.FindNode('LSN3').Text;
          lsn3 := StrToInt(TmpStr);
          rawData := Rootnode.ChildNodes[I].ChildNodes.FindNode('rawData').Text;

          lsnVal := PAnsiChar(AnsiString(Format('%.8x:%.8x:%.4x',[Lsn1,lsn2,lsn3])));

          RawDataPointer := strToBytes(AnsiString(rawData));

          srv_setcoldata(pSrvProc, 1, lsnVal);
          srv_setcoldata(pSrvProc, 2, @RawDataPointer[0]);
          srv_setcollen(pSrvProc, 2, Length(RawDataPointer));
          srv_sendrow(pSrvProc);

          SetLength(RawDataPointer, 0);
        end;
      end;
    except
      on ee:Exception do
      begin
        SqlSvr_SendMsg(pSrvProc, ee.Message);
      end;
    end;
  finally
    Xml := nil;
  end;

end;

function Read_logAll(dbid: Byte; Lsn1: Dword):string;
var
  idxHandle, dataHandle: THandle;
  path: string;
  IdxBuf: Pointer;
  rSize,dSize: Cardinal;
  Glo_idx :Uint64;      //ȫ��λ��
  position:Cardinal;    //������λ��
  //idx�ļ�
  lsn2:DWORD;
  lsn3Cont:Word;
  lsn3Val:array of Word;
  lsn3Offset:array of UInt64;
  is64Offset:Boolean;
  I: Integer;
  //data�ļ�
  dataFilePosition:TLargeInteger;
  rowLen:DWORD;
  dataBuf:Pointer;
  TmpStr:string;
  outPutStr:string;
begin
  outPutStr := '';
  Result := '<root></root>';
  path := ExtractFilePath(GetModuleName(HInstance)) + Format('data\%d\%d\', [dbid, Lsn1]);

  idxHandle := CreateFile(PChar(path + '1.idx'), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if idxHandle = INVALID_HANDLE_VALUE then
  begin
    Exit;
  end;

  dataHandle := CreateFile(PChar(path + '1.data'), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if dataHandle = INVALID_HANDLE_VALUE then
  begin
    CloseHandle(idxHandle);
    Exit;
  end;
  outPutStr := '<root>';
  Glo_idx := 0;
  IdxBuf := AllocMem($2000);
  try
    SetFilePointer(idxHandle, Glo_idx, nil, soFromBeginning);
    while ReadFile(idxHandle, IdxBuf^, $2000, rSize, nil) do
    begin
      if rSize = 0 then
      begin
        Exit;
      end;
      position := 0;

      while (position + 12) <= rSize do
      begin
        //�жϵ�ǰ��Ŀ�Ƿ�����
        lsn3Cont := PWORD(UINT_PTR(IdxBuf) + position + 4)^;
        if position + 6 + (lsn3Cont * 6) > rSize then
        begin
          //������
          Break;
        end;
        lsn2 := PDWORD(UINT_PTR(IdxBuf) + position)^;
        position := position + 4;
        lsn3Cont := PWORD(UINT_PTR(IdxBuf) + position)^;
        position := position + 2;
        SetLength(lsn3Val, lsn3Cont);
        for I := 0 to lsn3Cont -1 do
        begin
          lsn3Val[i] := PWORD(UINT_PTR(IdxBuf) + position)^;
          position := position + 2;
        end;
        SetLength(lsn3Offset, lsn3Cont);

        is64Offset := (lsn2 and $80000000) > 0;
        if is64Offset then
        begin
          //lsn2���λ��ʾoffsetֵ�Ƿ�Ϊ64λ����־�ļ�����4GBʱʹ��
          lsn2 := lsn2 and $7FFFFFFF;
          for I := 0 to lsn3Cont - 1 do
          begin
            lsn3Offset[I] := PUint64(UINT_PTR(IdxBuf) + position)^;
            position := position + 8;
          end;
        end
        else
        begin
          for I := 0 to lsn3Cont - 1 do
          begin
            lsn3Offset[I] := PDWORD(UINT_PTR(IdxBuf) + position)^;
            position := position + 4;
          end;
        end;
        for I := 0 to lsn3Cont - 1 do
        begin
          dataFilePosition := lsn3Offset[I];
          if SetFilePointerEx(dataHandle, dataFilePosition, @dataFilePosition, soFromBeginning) then
          begin
            if ReadFile(dataHandle, rowLen, 4, dSize, nil) and (dSize = 4) then
            begin
              //���ȶ�ȡ�ɹ�
              if rowLen > $2000 then
              begin
                //ERROR�������쳣
                //sqlserverһҳ�����$2000, (image,text,ntext���ֶ�δ��ȡ
                loger.Add(Format('Read_logAll data�����쳣>$2000 :data\%d\%d\%d', [dbid, Lsn1, dataFilePosition]), LOG_ERROR or LOG_IMPORTANT);
                Exit;
              end;
              dataBuf := AllocMem(rowLen);

              if ReadFile(dataHandle, dataBuf^, rowLen, dSize, nil) then
              begin
                if rowLen <> dSize then
                begin
                  //ERROR��δ��ȡ��ĩβ�����ݳ����쳣
                  loger.Add(Format('Read_logAll dataδ��ȡ��ĩβ�����ݳ����쳣 :data\%d\%d\%d', [dbid, Lsn1, dataFilePosition]), LOG_ERROR or LOG_IMPORTANT);
                  Exit;
                end;
                TmpStr := bytestostr(dataBuf, rowLen, $FFFFFFFF, False, False);
                TmpStr := StringReplace(TmpStr, ' ', '', [rfReplaceAll]);
                //builder row
                outPutStr := outPutStr + '<row>';
                outPutStr := outPutStr + Format('<LSN2>%d</LSN2>',[lsn2]);
                outPutStr := outPutStr + Format('<LSN3>%d</LSN3>',[lsn3Val[i]]);
                outPutStr := outPutStr + Format('<rawData>%s</rawData>',[TmpStr]);
                outPutStr := outPutStr + '</row>';
              end;
              Dispose(dataBuf);
            end
            else
            begin
              loger.Add(Format('Read_logAll data��ȡraw����ʧ�� :data\%d\%d\%d', [dbid, Lsn1, dataFilePosition]), LOG_ERROR or LOG_IMPORTANT);
              Exit;
              //��ȡraw����ʧ�ܣ���
            end;

          end;
        end;
      end;

      Glo_idx := Glo_idx + position;
      SetFilePointer(idxHandle, Glo_idx, nil, soFromBeginning);
    end;

  finally
    CloseHandle(idxHandle);
    CloseHandle(dataHandle);
    FreeMem(IdxBuf);
    Result := outPutStr+'</root>';
  end;
end;

//TODO���������ȡ
function Read_log_Trans(dbid: Byte; Lsn1: Dword; Lsn2: Dword):string;
begin

end;

function Read_log_One(dbid: Byte; Lsn1: Dword; Lsn2: Dword; Lsn3: word):string;
var
  idxHandle, dataHandle: THandle;
  path: string;
  IdxBuf: Pointer;
  rSize,dSize: Cardinal;
  Glo_idx :Uint64;      //ȫ��λ��
  position:Cardinal;    //������λ��
  //idx�ļ�
  Readlsn2:DWORD;
  lsn3Cont:Word;
  Readlsn3:Word;
  is64Offset:Boolean;
  I: Integer;
  //data�ļ�
  dataFilePosition:TLargeInteger;
  rowLen:DWORD;
  dataBuf:Pointer;
  TmpStr:string;
  outPutStr:string;
begin
  outPutStr := '';
  Result := '<root></root>';
  path := ExtractFilePath(GetModuleName(HInstance)) + Format('data\%d\%d\', [dbid, Lsn1]);

  idxHandle := CreateFile(PChar(path + '1.idx'), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if idxHandle = INVALID_HANDLE_VALUE then
  begin
    Exit;
  end;

  dataHandle := CreateFile(PChar(path + '1.data'), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if dataHandle = INVALID_HANDLE_VALUE then
  begin
    CloseHandle(idxHandle);
    Exit;
  end;
  outPutStr := '<root>';
  Glo_idx := 0;
  IdxBuf := AllocMem($2000);
  try
    SetFilePointer(idxHandle, Glo_idx, nil, soFromBeginning);
    while ReadFile(idxHandle, IdxBuf^, $2000, rSize, nil) do
    begin
      if rSize = 0 then
      begin
        Exit;
      end;
      position := 0;

      while (position + 12) <= rSize do
      begin
        //�жϵ�ǰ��Ŀ�Ƿ�����
        lsn3Cont := PWORD(UINT_PTR(IdxBuf) + position + 4)^;
        if position + 6 + (lsn3Cont * 6) > rSize then
        begin
          //������
          Break;
        end;
        Readlsn2 := PDWORD(UINT_PTR(IdxBuf) + position)^;
        position := position + 4;
        lsn3Cont := PWORD(UINT_PTR(IdxBuf) + position)^;
        position := position + 2;
        is64Offset := (Readlsn2 and $80000000) > 0;
        if is64Offset then
        begin
          Readlsn2 := Readlsn2 and $7FFFFFFF;
        end;
        if Readlsn2=Lsn2 then
        begin

          dataFilePosition := -1;
          for I := 0 to lsn3Cont -1 do
          begin
            Readlsn3 := PWORD(UINT_PTR(IdxBuf) + position + I * 2)^;
            if Readlsn3 = Lsn3 then
            begin
              position := position + lsn3Cont * 2;
              if is64Offset then
              begin
                dataFilePosition := position + Dword(i * 8);
                dataFilePosition := PuINT64(UINT_PTR(IdxBuf) + dataFilePosition)^;
              end else begin
                dataFilePosition := position + Dword(i * 4);
                dataFilePosition := PDword(UINT_PTR(IdxBuf) + dataFilePosition)^;
              end;

            end;
          end;
          if dataFilePosition <> -1 then
          begin
            if SetFilePointerEx(dataHandle, dataFilePosition, @dataFilePosition, soFromBeginning) then
            begin
              if ReadFile(dataHandle, rowLen, 4, dSize, nil) and (dSize = 4) then
              begin
                //���ȶ�ȡ�ɹ�
                if rowLen > $2000 then
                begin
                  //sqlserverһҳ�����$2000, (image,text,ntext���ֶ�δ��ȡ
                  loger.Add(Format('Read_logAll data�����쳣>$2000 :data\%d\%d\%d', [dbid, Lsn1, dataFilePosition]), LOG_ERROR or LOG_IMPORTANT);
                  Exit;
                end;
                dataBuf := AllocMem(rowLen);

                if ReadFile(dataHandle, dataBuf^, rowLen, dSize, nil) then
                begin
                  if rowLen <> dSize then
                  begin
                    loger.Add(Format('Read_logAll dataδ��ȡ��ĩβ�����ݳ����쳣 :data\%d\%d\%d', [dbid, Lsn1, dataFilePosition]), LOG_ERROR or LOG_IMPORTANT);
                    Exit;
                  end;
                  TmpStr := bytestostr(dataBuf, rowLen, $FFFFFFFF, False, False);
                  TmpStr := StringReplace(TmpStr, ' ', '', [rfReplaceAll]);
                  //builder row
                  outPutStr := outPutStr + '<row>';
                  outPutStr := outPutStr + Format('<LSN2>%d</LSN2>',[lsn2]);
                  outPutStr := outPutStr + Format('<LSN3>%d</LSN3>',[lsn3]);
                  outPutStr := outPutStr + Format('<rawData>%s</rawData>',[TmpStr]);
                  outPutStr := outPutStr + '</row>';
                end;
                Dispose(dataBuf);
              end
              else
              begin
                loger.Add(Format('Read_logAll data��ȡraw����ʧ�� :data\%d\%d\%d', [dbid, Lsn1, dataFilePosition]), LOG_ERROR or LOG_IMPORTANT);
                Exit;
              end;
            end;
          end;
          Exit;
        end else begin
          if is64Offset then
          begin
            position := position + lsn3Cont * (2 + 8);
          end
          else
          begin
            position := position + lsn3Cont * (2 + 4);
          end;
        end;
      end;
      Glo_idx := Glo_idx + position;
      SetFilePointer(idxHandle, Glo_idx, nil, soFromBeginning);
    end;
  finally
    CloseHandle(idxHandle);
    CloseHandle(dataHandle);
    FreeMem(IdxBuf);
    Result := outPutStr+'</root>';
  end;
end;


end.

