unit p_idxmgr;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TForm2 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button28: TButton;
    Button3: TButton;
    Memo1: TMemo;
    Edit1: TEdit;
    Button4: TButton;
    Edit2: TEdit;
    Timer1: TTimer;
    procedure Button2Click(Sender: TObject);
    procedure Button28Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;


var
  Form2: TForm2;

implementation

uses
  System.Math, logCreatehelper,Xml.XMLDoc,Xml.XMLIntf, Memory_Common;

{$R *.dfm}
var
  hh: THandle;
  Lr_clearCache: function(pSrvProc: Pointer): Integer;
  savePageLog2: function : Boolean;
  Read_logAllWithTableResults: function(pSrvProc: Pointer; dbid: Byte; Lsn1: Dword): Integer; stdcall;
  Read_log_One: function(dbid: Byte; Lsn1: Dword; Lsn2: Dword; Lsn3: word): PAnsiChar; stdcall;
  aaaaaa: function: PansiChar; stdcall;
  Lr_doo_test : procedure;stdcall;
  exitAllThread:procedure;

  data:TStringList;

procedure TForm2.Button1Click(Sender: TObject);
var
  I: Integer;
  sj:string;
  rspp,bb,bb2: PlogRecdItem;
  xml:iXMLDocument;
  RootNode:IXMLNode;
  tmpBytes:TBytes;
begin
  data:=TStringList.Create;
  data.LoadFromFile(Edit1.Text);

  ____PaddingData := nil;
  rspp := nil;
  bb := nil;
  for I := 0 to data.Count-1 do
  begin
    xml:=TXMLDocument.Create(nil);
    xml.Active := True;
    try
      sj := data[I].Substring(52,length(data[I])-58);
      xml.LoadFromXML(sj);
      RootNode := xml.DocumentElement;
      new(bb2);
      bb2.dbId := RootNode.Attributes['dbid'];
      bb2.lsn := Str2LSN(RootNode.Attributes['lsn']);
      tmpBytes := strToBytes(RootNode.Text);
      bb2.length := Length(tmpBytes);
      bb2.val := GetMemory(bb2.length);
      bb2.n := nil;
      Move(tmpBytes[0], bb2.val^, bb2.length);
      if bb = nil then
      begin
        bb := bb2;
        rspp := bb;
      end
      else begin
        bb.n := bb2;
        bb := bb2;
      end;
    except
    end;
    xml := nil;
  end;
  ____PaddingData := rspp;
end;

procedure TForm2.Button28Click(Sender: TObject);
begin
  exitAllThread;
  FreeLibrary(hh);
end;

procedure TForm2.Button2Click(Sender: TObject);
begin
  hh := LoadLibrary('LrExtutils.dll');
  Lr_clearCache := getprocaddress(hh, 'Lr_clearCache');
  savePageLog2 := getprocaddress(hh, 'savePageLog2');
  Read_logAllWithTableResults := getprocaddress(hh, 'Read_logAllWithTableResults');
  Read_log_One := getprocaddress(hh, 'Read_log_One');
  aaaaaa := getprocaddress(hh, 'aaaaaa');
  Lr_doo_test := getprocaddress(hh, 'Lr_doo_test');
  exitAllThread := getprocaddress(hh, 'exitAllThread');
end;

procedure TForm2.Button3Click(Sender: TObject);
var
  sj:string;
  I: Integer;
  tmpSjaaa:TStringList;
  rspp,bb,bb2: PlogRecdItem;
  xml:iXMLDocument;
  RootNode:IXMLNode;
  tmpBytes:TBytes;
begin
  sj := memo1.Lines[0];
  memo1.Lines.Delete(0);
  Edit2.Text := sj;
  tmpSjaaa:=TStringList.Create;
  for I := 0 to data.Count - 1 do
  begin
    if data[I].StartsWith(sj) then
    begin
      tmpSjaaa.Add(data[I].Substring(52,length(data[I])-58));
    end;
  end;


  ____PaddingData := nil;
  rspp := nil;
  bb := nil;
  for I := 0 to tmpSjaaa.Count-1 do
  begin
    xml:=TXMLDocument.Create(nil);
    xml.Active := True;
    try
      xml.LoadFromXML(tmpSjaaa[i]);
      RootNode := xml.DocumentElement;
      new(bb2);
      bb2.dbId := RootNode.Attributes['dbid'];
      bb2.lsn := Str2LSN(RootNode.Attributes['lsn']);
      tmpBytes := strToBytes(RootNode.Text);
      bb2.length := Length(tmpBytes);
      bb2.val := GetMemory(bb2.length);
      bb2.n := nil;
      Move(tmpBytes[0], bb2.val^, bb2.length);
      if bb = nil then
      begin
        bb := bb2;
        rspp := bb;
      end
      else begin
        bb.n := bb2;
        bb := bb2;
      end;
    except
    end;
    xml := nil;
  end;
  ____PaddingData := rspp;

  tmpSjaaa.Free;
  Timer1.Enabled := true
end;

procedure TForm2.Button4Click(Sender: TObject);
var
  tmpSjaaa:TStringList;
  I: Integer;
  sj:string;
begin
  data:=TStringList.Create;
  data.LoadFromFile(Edit1.Text);

  tmpSjaaa:=TStringList.Create;
  for I := 0 to data.Count - 1 do
  begin
    sj := data[I].Substring(0, 23);
    if tmpSjaaa.IndexOf(sj) = -1 then
    begin
      tmpSjaaa.Add(sj);
    end;
  end;
  memo1.Text := tmpSjaaa.text;
  tmpSjaaa.Free;

  Button4.Enabled := False;
end;

procedure TForm2.Timer1Timer(Sender: TObject);
begin
  if ____PaddingData=nil then
   Button3.Click;
end;

end.

