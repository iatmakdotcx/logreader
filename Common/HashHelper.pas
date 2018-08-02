unit HashHelper;

interface

function GetStrHashMD5(Str: string): string;

function GetStrHashSHA1(Str: string): string;

function GetStrHashSHA224(Str: string): string;

function GetStrHashSHA256(Str: string): string;

function GetStrHashSHA384(Str: string): string;

function GetStrHashSHA512(Str: string): string;

function GetStrHashSHA512_224(Str: string): string;

function GetStrHashSHA512_256(Str: string): string;

function GetStrHashBobJenkins(Str: string): string;

function GetFileHashMD5(FileName: WideString): string;

function GetFileHashSHA1(FileName: WideString): string;

function GetFileHashSHA224(FileName: WideString): string;

function GetFileHashSHA256(FileName: WideString): string;

function GetFileHashSHA384(FileName: WideString): string;

function GetFileHashSHA512(FileName: WideString): string;

function GetFileHashSHA512_224(FileName: WideString): string;

function GetFileHashSHA512_256(FileName: WideString): string;

function GetFileHashBobJenkins(FileName: WideString): string;

implementation

uses
  System.Hash, System.Classes, System.SysUtils;

function GetStrHashMD5(Str: string): string;
var
  HashMD5: THashMD5;
begin
  HashMD5 := THashMD5.Create;
  HashMD5.GetHashString(Str);
  result := HashMD5.GetHashString(Str);
end;

function GetStrHashSHA1(Str: string): string;
var
  HashSHA: THashSHA1;
begin
  HashSHA := THashSHA1.Create;
  HashSHA.GetHashString(Str);
  result := HashSHA.GetHashString(Str);
end;

function GetStrHashSHA224(Str: string): string;
var
  HashSHA: THashSHA2;
begin
  HashSHA := THashSHA2.Create;
  HashSHA.GetHashString(Str);
  result := HashSHA.GetHashString(Str, SHA224);
end;

function GetStrHashSHA256(Str: string): string;
var
  HashSHA: THashSHA2;
begin
  HashSHA := THashSHA2.Create;
  HashSHA.GetHashString(Str);
  result := HashSHA.GetHashString(Str, SHA256);
end;

function GetStrHashSHA384(Str: string): string;
var
  HashSHA: THashSHA2;
begin
  HashSHA := THashSHA2.Create;
  HashSHA.GetHashString(Str);
  result := HashSHA.GetHashString(Str, SHA384);
end;

function GetStrHashSHA512(Str: string): string;
var
  HashSHA: THashSHA2;
begin
  HashSHA := THashSHA2.Create;
  HashSHA.GetHashString(Str);
  Result := HashSHA.GetHashString(Str, SHA512);
end;

function GetStrHashSHA512_224(Str: string): string;
var
  HashSHA: THashSHA2;
begin
  HashSHA := THashSHA2.Create;
  HashSHA.GetHashString(Str);
  Result := HashSHA.GetHashString(Str, SHA512_224);
end;

function GetStrHashSHA512_256(Str: string): string;
var
  HashSHA: THashSHA2;
begin
  HashSHA := THashSHA2.Create;
  HashSHA.GetHashString(Str);
  Result := HashSHA.GetHashString(Str, SHA512_256);
end;

function GetStrHashBobJenkins(Str: string): string;
var
  Hash: THashBobJenkins;
begin
  Hash := THashBobJenkins.Create;
  Hash.GetHashString(Str);
  Result := Hash.GetHashString(Str);
end;

function GetFileHashMD5(FileName: WideString): string;
var
  HashMD5: THashMD5;
  Stream: TStream;
  Readed: Integer;
  Buffer: PByte;
  BufLen: Integer;
begin
  HashMD5 := THashMD5.Create;
  BufLen := 16 * 1024;
  Buffer := AllocMem(BufLen);
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      while Stream.Position < Stream.Size do
      begin
        Readed := Stream.Read(Buffer^, BufLen);
        if Readed > 0 then
        begin
          HashMD5.update(Buffer^, Readed);
        end;
      end;
    finally
      Stream.Free;
    end;
  finally
    FreeMem(Buffer)
  end;
  result := HashMD5.HashAsString;
end;

function GetFileHashSHA1(FileName: WideString): string;
var
  HashSHA: THashSHA1;
  Stream: TStream;
  Readed: Integer;
  Buffer: PByte;
  BufLen: Integer;
begin
  HashSHA := THashSHA1.Create;
  BufLen := 16 * 1024;
  Buffer := AllocMem(BufLen);
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      while Stream.Position < Stream.Size do
      begin
        Readed := Stream.Read(Buffer^, BufLen);
        if Readed > 0 then
        begin
          HashSHA.update(Buffer^, Readed);
        end;
      end;
    finally
      Stream.Free;
    end;
  finally
    FreeMem(Buffer)
  end;
  result := HashSHA.HashAsString;
end;

function GetFileHashSHA224(FileName: WideString): string;
var
  HashSHA: THashSHA2;
  Stream: TStream;
  Readed: Integer;
  Buffer: PByte;
  BufLen: Integer;
begin
  HashSHA := THashSHA2.Create(SHA224);
  BufLen := 16 * 1024;
  Buffer := AllocMem(BufLen);
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      while Stream.Position < Stream.Size do
      begin
        Readed := Stream.Read(Buffer^, BufLen);
        if Readed > 0 then
        begin
          HashSHA.update(Buffer^, Readed);
        end;
      end;
    finally
      Stream.Free;
    end;
  finally
    FreeMem(Buffer)
  end;
  result := HashSHA.HashAsString;
end;

function GetFileHashSHA256(FileName: WideString): string;
var
  HashSHA: THashSHA2;
  Stream: TStream;
  Readed: Integer;
  Buffer: PByte;
  BufLen: Integer;
begin
  HashSHA := THashSHA2.Create(SHA256);
  BufLen := 16 * 1024;
  Buffer := AllocMem(BufLen);
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      while Stream.Position < Stream.Size do
      begin
        Readed := Stream.Read(Buffer^, BufLen);
        if Readed > 0 then
        begin
          HashSHA.update(Buffer^, Readed);
        end;
      end;
    finally
      Stream.Free;
    end;
  finally
    FreeMem(Buffer)
  end;
  result := HashSHA.HashAsString;
end;

function GetFileHashSHA384(FileName: WideString): string;
var
  HashSHA: THashSHA2;
  Stream: TStream;
  Readed: Integer;
  Buffer: PByte;
  BufLen: Integer;
begin
  HashSHA := THashSHA2.Create(SHA384);
  BufLen := 16 * 1024;
  Buffer := AllocMem(BufLen);
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      while Stream.Position < Stream.Size do
      begin
        Readed := Stream.Read(Buffer^, BufLen);
        if Readed > 0 then
        begin
          HashSHA.update(Buffer^, Readed);
        end;
      end;
    finally
      Stream.Free;
    end;
  finally
    FreeMem(Buffer)
  end;
  result := HashSHA.HashAsString;
end;

function GetFileHashSHA512(FileName: WideString): string;
var
  HashSHA: THashSHA2;
  Stream: TStream;
  Readed: Integer;
  Buffer: PByte;
  BufLen: Integer;
begin
  HashSHA := THashSHA2.Create(SHA512);
  BufLen := 16 * 1024;
  Buffer := AllocMem(BufLen);
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      while Stream.Position < Stream.Size do
      begin
        Readed := Stream.Read(Buffer^, BufLen);
        if Readed > 0 then
        begin
          HashSHA.update(Buffer^, Readed);
        end;
      end;
    finally
      Stream.Free;
    end;
  finally
    FreeMem(Buffer)
  end;
  result := HashSHA.HashAsString;
end;

function GetFileHashSHA512_224(FileName: WideString): string;
var
  HashSHA: THashSHA2;
  Stream: TStream;
  Readed: Integer;
  Buffer: PByte;
  BufLen: Integer;
begin
  HashSHA := THashSHA2.Create(SHA512_224);
  BufLen := 16 * 1024;
  Buffer := AllocMem(BufLen);
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      while Stream.Position < Stream.Size do
      begin
        Readed := Stream.Read(Buffer^, BufLen);
        if Readed > 0 then
        begin
          HashSHA.update(Buffer^, Readed);
        end;
      end;
    finally
      Stream.Free;
    end;
  finally
    FreeMem(Buffer)
  end;
  result := HashSHA.HashAsString;
end;

function GetFileHashSHA512_256(FileName: WideString): string;
var
  HashSHA: THashSHA2;
  Stream: TStream;
  Readed: Integer;
  Buffer: PByte;
  BufLen: Integer;
begin
  HashSHA := THashSHA2.Create(SHA512_256);
  BufLen := 16 * 1024;
  Buffer := AllocMem(BufLen);
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      while Stream.Position < Stream.Size do
      begin
        Readed := Stream.Read(Buffer^, BufLen);
        if Readed > 0 then
        begin
          HashSHA.update(Buffer^, Readed);
        end;
      end;
    finally
      Stream.Free;
    end;
  finally
    FreeMem(Buffer)
  end;
  result := HashSHA.HashAsString;
end;

function GetFileHashBobJenkins(FileName: WideString): string;
var
  Hash: THashBobJenkins;
  Stream: TStream;
  Readed: Integer;
  Buffer: PByte;
  BufLen: Integer;
begin
  Hash := THashBobJenkins.Create;
  BufLen := 16 * 1024;
  Buffer := AllocMem(BufLen);
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      while Stream.Position < Stream.Size do
      begin
        Readed := Stream.Read(Buffer^, BufLen);
        if Readed > 0 then
        begin
          Hash.update(Buffer^, Readed);
        end;
      end;
    finally
      Stream.Free;
    end;
  finally
    FreeMem(Buffer)
  end;
  result := Hash.HashAsString;
end;

end.

