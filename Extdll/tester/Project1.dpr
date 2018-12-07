program Project1;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  Winapi.Windows {Form1},
  logCreatehelper in 'logCreatehelper.pas',
  MakCommonfuncs in 'H:\Delphi\通用的自定义单元\MakCommonfuncs.pas',
  Memory_Common in 'H:\Delphi\通用的自定义单元\Memory_Common.pas',
  p_idxmgr in 'p_idxmgr.pas' {Form2},
  blockReader in 'blockReader.pas';

{$R *.res}

function _Lc_HasBeenHooked: UINT_PTR; stdcall;
begin
  Result := $01010101;
end;

function _Lc_Get_PaddingData: Pointer; stdcall;
begin
  Result := ____PaddingData;
end;

function _Lc_Get_PaddingDataCnt: Int64; stdcall;
begin
  Result := 10;
end;

procedure _Lc_Free_PaddingData(Pnt: Pointer); stdcall;
begin
 // Dispose(Pnt);
end;

exports
  _Lc_HasBeenHooked,
  _Lc_Get_PaddingData,
  _Lc_Free_PaddingData,
  _Lc_Get_PaddingDataCnt;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.

