unit ResHelper;

interface

uses
  System.SysUtils, Vcl.ExtCtrls;

procedure SetImgData(img: TImage; ResName: string; ResType: string = 'IMG');

function getResdata(ResName: string; ResType: string): TBytes;

implementation

uses
  System.Classes, Vcl.Imaging.GIFImg, Vcl.Graphics, Vcl.Imaging.pngimage,Vcl.Imaging.jpeg;

procedure SetImgData(img: TImage; ResName: string; ResType: string = 'IMG');
var
  img_loading: TGraphic;
  img_loading_res: TResourceStream;
  headerData: array[0..10] of Byte;
begin
  img_loading_res := TResourceStream.Create(HInstance, ResName, PChar(ResType));
  try
    img_loading_res.Read(headerData[0], 10);
    img_loading_res.Seek(-10, soFromCurrent);

    if ((headerData[0] = $FF) and (headerData[6] = $4A) and (headerData[7] = $46) and (headerData[8] = $49) and (headerData[9] = $46)) then
    begin
      // return "image/jpeg";
      img_loading := TJPEGImage.Create;
    end
    else if ((headerData[0] = $89) and (headerData[1] = $50) and (headerData[2] = $4E) and (headerData[3] = $47)) then
    begin
      //return "image/png";
      img_loading := tpngimage.Create;
    end
    else if ((headerData[0] = $47) and (headerData[1] = $49) and (headerData[2] = $46) and (headerData[3] = $38) and (headerData[7] < 32)) then
    begin
      //return "image/gif";
      img_loading := TGIFImage.Create;
      TGIFImage(img_loading).Animate := True;
    end
    else if ((headerData[0] = $42) and (headerData[1] = $4D) and (headerData[6] = $0) and (headerData[7] = 0)) then
    begin
      // return "image/bmp";
      img_loading := TBitmap.Create;
    end else begin
      raise Exception.Create('不支持的图片格式');
    end;
    img_loading.LoadFromStream(img_loading_res);
    img.Picture.Assign(img_loading);
    img_loading.Free;
  finally
    img_loading_res.Free;
  end;
end;

function getResdata(ResName: string; ResType: string): TBytes;
var
  HResInfo: THandle;
  HGlobal: THandle;
  dataPnt: Pointer;
  resSize: Cardinal;
begin
  Result := nil;
  HResInfo := FindResource(HInstance, PChar(ResName), PChar(ResType));
  if HResInfo = 0 then
  begin
    Exit;
  end;
  HGlobal := LoadResource(HInstance, HResInfo);
  if HGlobal = 0 then
  begin
    Exit;
  end;
  dataPnt := LockResource(HGlobal);
  resSize := SizeOfResource(HInstance, HResInfo);
  SetLength(Result, resSize);
  Move(dataPnt^, Result[0], resSize);
end;

end.

