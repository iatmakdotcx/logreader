unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    Button9: TButton;
    Button10: TButton;
    Button11: TButton;
    Button12: TButton;
    Button13: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button10Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    procedure Button13Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  hh: THandle;
  Lr_clearCache: function(pSrvProc: Pointer): Integer;
  d_do_SavePagelog: function(pSrvProc: Pointer): Integer;

implementation
uses
  logCreatehelper;

{$R *.dfm}

procedure TForm1.Button10Click(Sender: TObject);
var
  rspp: PlogRecdItem;
  bb2: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;

  rspp.TranID_1 := $1;
  rspp.TranID_2 := $2;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $A0;
  rspp.lsn.lsn_3 := $01;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  d_do_SavePagelog(nil);
end;

procedure TForm1.Button11Click(Sender: TObject);
var
  rspp: PlogRecdItem;
  bb2: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;

  rspp.TranID_1 := $1;
  rspp.TranID_2 := $2;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $A1;
  rspp.lsn.lsn_3 := $01;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $A1;
  bb2.lsn.lsn_2 := $A1;
  bb2.lsn.lsn_3 := $02;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;
  rspp := bb2;


  d_do_SavePagelog(nil);

end;

procedure TForm1.Button13Click(Sender: TObject);
var
  rspp: PlogRecdItem;
  bb2: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;

  rspp.TranID_1 := $1;
  rspp.TranID_2 := $2;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $A0;
  rspp.lsn.lsn_3 := $02;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  d_do_SavePagelog(nil);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  hh := LoadLibrary('LrExtutils.dll');
  Lr_clearCache := getprocaddress(hh, 'Lr_clearCache');
  d_do_SavePagelog := getprocaddress(hh, 'd_do_SavePagelog');
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  Lr_clearCache(nil);
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  FreeLibrary(hh)
end;

procedure TForm1.Button4Click(Sender: TObject);
var
  rspp: PlogRecdItem;
  bb2: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;

  rspp.TranID_1 := $1;
  rspp.TranID_2 := $2;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $A2;
  rspp.lsn.lsn_3 := $01;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $A1;
  bb2.lsn.lsn_2 := $A2;
  bb2.lsn.lsn_3 := $02;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;
  rspp := bb2;

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $A2;
  bb2.lsn.lsn_2 := $A2;
  bb2.lsn.lsn_3 := $02;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;
  rspp := bb2;

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $A2;
  bb2.lsn.lsn_2 := $A2;
  bb2.lsn.lsn_3 := $02;
  bb2.dbId := 6;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;
  rspp := bb2;

  d_do_SavePagelog(nil);
end;

procedure TForm1.Button5Click(Sender: TObject);
var
  rspp: PlogRecdItem;
  bb2: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;

  rspp.TranID_1 := $1;
  rspp.TranID_2 := $2;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $A3;
  rspp.lsn.lsn_3 := $01;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  d_do_SavePagelog(nil);
end;

procedure TForm1.Button6Click(Sender: TObject);
var
  rspp: PlogRecdItem;
  bb2: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;

  rspp.TranID_1 := $1;
  rspp.TranID_2 := $2;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $A3;
  rspp.lsn.lsn_3 := $01;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $A1;
  bb2.lsn.lsn_2 := $A3;
  bb2.lsn.lsn_3 := $02;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;
  rspp := bb2;


  d_do_SavePagelog(nil);

end;

procedure TForm1.Button7Click(Sender: TObject);
var
  rspp: PlogRecdItem;
  bb2: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;

  rspp.TranID_1 := $1;
  rspp.TranID_2 := $2;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $A0;
  rspp.lsn.lsn_3 := $02;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  d_do_SavePagelog(nil);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  TObject.Create;
end;

end.

