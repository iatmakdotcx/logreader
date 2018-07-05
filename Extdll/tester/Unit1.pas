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
    Button14: TButton;
    Button15: TButton;
    Button16: TButton;
    Button17: TButton;
    Button18: TButton;
    Button19: TButton;
    Button20: TButton;
    Button21: TButton;
    Button22: TButton;
    Button23: TButton;
    Button24: TButton;
    Button25: TButton;
    Button26: TButton;
    GroupBox1: TGroupBox;
    Button27: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button10Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    procedure Button13Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button14Click(Sender: TObject);
    procedure Button15Click(Sender: TObject);
    procedure Button17Click(Sender: TObject);
    procedure Button18Click(Sender: TObject);
    procedure Button19Click(Sender: TObject);
    procedure Button20Click(Sender: TObject);
    procedure Button21Click(Sender: TObject);
    procedure Button22Click(Sender: TObject);
    procedure Button23Click(Sender: TObject);
    procedure Button24Click(Sender: TObject);
    procedure Button25Click(Sender: TObject);
    procedure Button26Click(Sender: TObject);
    procedure Button27Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  hh: THandle;
  Lr_clearCache: function(pSrvProc: Pointer): Integer;
  savePageLog2: function : Boolean;
  Read_logAllWithTableResults: function(pSrvProc: Pointer; dbid: Byte; Lsn1: Dword): Integer; stdcall;
  Read_log_One: function(dbid: Byte; Lsn1: Dword; Lsn2: Dword; Lsn3: word): PAnsiChar; stdcall;
  aaaaaa: function: PansiChar; stdcall;
  Lr_doo_test : function (dbid: Word; lsn1, lsn2: DWORD; lsn3: WORD):Int32;stdcall;

implementation

uses
  logCreatehelper;

{$R *.dfm}

procedure TForm1.Button10Click(Sender: TObject);
var
  rspp: PlogRecdItem;
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

  savePageLog2;
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
  rspp.lsn.lsn_2 := $A0;
  rspp.lsn.lsn_3 := $02;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $A1;
  bb2.lsn.lsn_2 := $A0;
  bb2.lsn.lsn_3 := $04;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;
  rspp := bb2;

savePageLog2

end;

procedure TForm1.Button13Click(Sender: TObject);
var
  rspp: PlogRecdItem;
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

savePageLog2;
end;

procedure TForm1.Button14Click(Sender: TObject);
var
  rspp: PlogRecdItem;
  bb2: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;

  rspp.TranID_1 := $1;
  rspp.TranID_2 := $2;
  rspp.lsn.lsn_1 := $10;
  rspp.lsn.lsn_2 := $20;
  rspp.lsn.lsn_3 := $01;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $10;
  bb2.lsn.lsn_2 := $21;
  bb2.lsn.lsn_3 := $01;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;
  rspp := bb2;

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $10;
  bb2.lsn.lsn_2 := $22;
  bb2.lsn.lsn_3 := $01;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;
  rspp := bb2;

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $10;
  bb2.lsn.lsn_2 := $23;
  bb2.lsn.lsn_3 := $03;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;
  rspp := bb2;

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $10;
  bb2.lsn.lsn_2 := $24;
  bb2.lsn.lsn_3 := $03;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;
  rspp := bb2;

 savePageLog2;
end;

procedure TForm1.Button15Click(Sender: TObject);
var
  rspp: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;

  rspp.TranID_1 := $1;
  rspp.TranID_2 := $2;
  rspp.lsn.lsn_1 := $10;
  rspp.lsn.lsn_2 := $23;
  rspp.lsn.lsn_3 := $05;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

 savePageLog2;

end;

procedure TForm1.Button17Click(Sender: TObject);
var
  rspp: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;
  rspp.TranID_1 := $0;
  rspp.TranID_2 := $0;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $c0;
  rspp.lsn.lsn_3 := $03;
  rspp.dbId := 5;
  rspp.length := $A;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  savePageLog2;
end;

procedure TForm1.Button18Click(Sender: TObject);
begin
  Read_logAllWithTableResults(nil, 5, 512);
end;

procedure TForm1.Button19Click(Sender: TObject);
begin
  ShowMessage(string(Read_log_One(50, 512, 504, 2)));
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  hh := LoadLibrary('LrExtutils.dll');
  Lr_clearCache := getprocaddress(hh, 'Lr_clearCache');
  savePageLog2 := getprocaddress(hh, 'savePageLog2');
  Read_logAllWithTableResults := getprocaddress(hh, 'Read_logAllWithTableResults');
  Read_log_One := getprocaddress(hh, 'Read_log_One');
  aaaaaa := getprocaddress(hh, 'aaaaaa');
  Lr_doo_test := getprocaddress(hh, 'Lr_doo_test');
end;

procedure TForm1.Button20Click(Sender: TObject);
begin
  ShowMessage(aaaaaa);
end;

procedure TForm1.Button21Click(Sender: TObject);
var
  rspp: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;
  rspp.TranID_1 := $0;
  rspp.TranID_2 := $0;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $c0;
  rspp.lsn.lsn_3 := $05;
  rspp.dbId := 5;
  rspp.length := $A;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  savePageLog2;
end;

procedure TForm1.Button22Click(Sender: TObject);
var
  rspp: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;
  rspp.TranID_1 := $0;
  rspp.TranID_2 := $0;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $c8;
  rspp.lsn.lsn_3 := $1;
  rspp.dbId := 5;
  rspp.length := $A;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  savePageLog2;
end;

procedure TForm1.Button23Click(Sender: TObject);
var
  rspp: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;
  rspp.TranID_1 := $0;
  rspp.TranID_2 := $0;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $d0;
  rspp.lsn.lsn_3 := $3;
  rspp.dbId := 5;
  rspp.length := $A;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  savePageLog2;
end;

procedure TForm1.Button24Click(Sender: TObject);
var
  rspp: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;
  rspp.TranID_1 := $0;
  rspp.TranID_2 := $0;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $c8;
  rspp.lsn.lsn_3 := $10;
  rspp.dbId := 5;
  rspp.length := $A;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  savePageLog2;
end;

procedure TForm1.Button25Click(Sender: TObject);
var
  rspp: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;
  rspp.TranID_1 := $0;
  rspp.TranID_2 := $0;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $c7;
  rspp.lsn.lsn_3 := $1;
  rspp.dbId := 5;
  rspp.length := $A;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  savePageLog2;
end;

procedure TForm1.Button26Click(Sender: TObject);
var
  rspp: PlogRecdItem;
begin
  New(rspp);
  ____PaddingData := rspp;
  rspp.TranID_1 := $0;
  rspp.TranID_2 := $0;
  rspp.lsn.lsn_1 := $A1;
  rspp.lsn.lsn_2 := $c7;
  rspp.lsn.lsn_3 := $10;
  rspp.dbId := 5;
  rspp.length := $A;
  rspp.val := PAnsiChar('1234567890');
  rspp.n := nil;

  savePageLog2;
end;

procedure TForm1.Button27Click(Sender: TObject);
begin
//  rspp.TranID_1 := $0;
//  rspp.TranID_2 := $0;
//  rspp.lsn.lsn_1 := $A1;
//  rspp.lsn.lsn_2 := $c0;
//  rspp.lsn.lsn_3 := $03;
//  rspp.dbId := 5;
//  rspp.length := $A;
//  rspp.val := PAnsiChar('1234567890');

  ShowMessage(IntToStr(Lr_doo_test(7,$36,$198,$1)));
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

savePageLog2;
end;

procedure TForm1.Button5Click(Sender: TObject);
var
  rspp: PlogRecdItem;
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

savePageLog2;
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
  rspp.lsn.lsn_3 := $02;
  rspp.dbId := 5;
  rspp.length := 10;
  rspp.val := PAnsiChar('1234567890');

  New(bb2);
  rspp.n := bb2;
  bb2.TranID_1 := $1;
  bb2.TranID_2 := $2;
  bb2.lsn.lsn_1 := $A1;
  bb2.lsn.lsn_2 := $A3;
  bb2.lsn.lsn_3 := $03;
  bb2.dbId := 5;
  bb2.length := 10;
  bb2.val := PAnsiChar('abcdefghij');
  bb2.n := nil;

savePageLog2;
end;

procedure TForm1.Button7Click(Sender: TObject);
var
  rspp: PlogRecdItem;
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

savePageLog2;
end;

end.

