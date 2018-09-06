unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls;

type
  PLidxItem = ^TLidxItem;

  TLidxItem = packed record
    case Integer of
      0:
        (Lsn3: Word;
        ReqNo: DWORD;
        Reserve: Word;
        DataOffset: DWORD;
        DataOffsetH: WORD;
        LogSize: WORD;);
      1:
        (HHH: Uint64;
        LLL: Uint64);
  end;


type
  TForm1 = class(TForm)
    ListView1: TListView;
    Button1: TButton;
    Button2: TButton;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    bblst:TList;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  IdxFileHeader: array[0..$F] of AnsiChar = ('L', 'R', 'I', 'D', 'X', 'P', 'K', 'G', #0, #0, #0, #0, #0, #0, #0, #2);

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
var
  idxF:Thandle;
  Buf:Pointer;
  BufIdx:Cardinal;
  fsize,rrSize:Cardinal;
  pli:PLidxItem;
  id:Integer;
begin
  idxF := CreateFile(PChar(ExtractFilePath(Application.ExeName) + '1.idx'), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if idxF = INVALID_HANDLE_VALUE then
  begin
    ShowMessage(SysErrorMessage(GetLastError));
    exit;
  end;

  fsize := GetFileSize(idxF, nil);
  Buf := GetMemory(fsize);
  ReadFile(idxF, Buf^, fsize,rrSize,nil);
  if not CompareMem(Buf,@IdxFileHeader[0],$E) then
  begin
    ShowMessage('文件头效验失败！');
    CloseHandle(idxF);
    exit;
  end;
  pli := Pointer(Uint_ptr(Buf) + $100);
  id := 0;
  while Uint_ptr(pli) < (Uint_ptr(Buf) + fsize) do
  begin
    bblst.Add(pli);
    with ListView1.Items.Add do
    begin
      Caption := Format('%d', [id]);
      SubItems.Add(Format('%.8X', [pli.ReqNo]));
      SubItems.Add(Format('%.4X', [pli.Lsn3]));
      SubItems.Add(Format('%.8X', [pli.DataOffset]));
      SubItems.Add(Format('%.4X', [pli.LogSize]));
    end;
    Inc(id);
    inc(pli);
  end;
  CloseHandle(idxF);
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  I,J: Integer;
  p1,p2:PLidxItem;
begin
  for I := 0 to bblst.Count-1 do
  begin
    p1 := bblst[i];
    for J := 0 to bblst.Count-1 do
    begin
      p2 := bblst[j];
      if p1<>p2 then
      begin
        if (p1.DataOffset >= p2.DataOffset) and (p1.DataOffset<P2.DataOffset+p2.LogSize) then
        begin
          memo1.Lines.Add(Format('%.8X:%.4X', [p1.ReqNo, p1.Lsn3]));
        end;
      end;
    end;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  bblst := TList.Create;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  bblst.Free;
end;

end.
