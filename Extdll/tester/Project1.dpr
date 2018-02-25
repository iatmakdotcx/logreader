program Project1;

uses
  FastMM4 in 'H:\Delphi\FastMMnew\FastMM4.pas',
  FastMM4Messages in 'H:\Delphi\FastMMnew\FastMM4Messages.pas',
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  Winapi.Windows {Form1};

{$R *.res}

type
  TLSN = packed record
    lsn_1: DWORD;
    lsn_2: DWORD;
    lsn_3: WORD;
  end;

  PlogRecdItem = ^TlogRecdItem;

  TlogRecdItem = packed record
    n: PlogRecdItem;
    TranID_1: DWORD;
    TranID_2: WORD;
    lsn: TLSN;
    length: DWORD;
    dbId: Word;
    val: Pointer;
  end;

function _Lc_Get_PaddingData: Pointer; stdcall;
var
  rspp: PlogRecdItem;
  bb2: PlogRecdItem;
begin
  New(rspp);
  rspp.TranID_1 := $1;
  rspp.TranID_2 := $2;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $A2;
  rspp.lsn.lsn_3 := $01;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PChar('1234567890');

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $A1;
  bb2.lsn.lsn_2 := $A2;
  bb2.lsn.lsn_3 := $02;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PChar('abcdefghij');

  bb2.n := nil;

  Result := rspp;
end;

function _Lc_Get_PaddingDataCnt: Int64; stdcall;
begin
  Result := 10;
end;

procedure _Lc_Free_PaddingData(Pnt: Pointer); stdcall;
begin
  Dispose(Pnt);
end;

exports
  _Lc_Get_PaddingData,
  _Lc_Free_PaddingData,
  _Lc_Get_PaddingDataCnt;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

