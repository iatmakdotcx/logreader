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
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  hh: THandle;
  Lr_clearCache: function(pSrvProc: Pointer): Integer;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
begin
  hh := LoadLibrary('LrExtutils.dll');
  Lr_clearCache := getprocaddress(hh, 'Lr_clearCache');
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  Lr_clearCache(nil);
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  FreeLibrary(hh)
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  TObject.Create;
end;

end.

