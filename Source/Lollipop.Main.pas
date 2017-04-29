unit Lollipop.Main;

interface

uses
  ECMA.TypedArray, W3C.DOM4, W3C.HTML5, W3C.SVG2, Lollipop.Framework,
  Lollipop.Generator;

{$DEFINE UseXmlSerializer}
{$DEFINE Simplified}

type
  TButtonGenerate = class(TButtonElement);
  TControlContainer = class(TDivElement);
  TOuterContainer = class(TDivElement);

  TMainScreen = class(TDivElement)
  private
    FTextLabel: TLabelElement;
    FTextEdit: TInputTextElement;
    FMaximumLabel: TLabelElement;
    FMaximumEdit: TInputTextElement;
    FFeintsLabel: TLabelElement;
    FFeintsEdit: TInputCheckBoxElement;
    FAdditionLabel: TLabelElement;
    FAdditionEdit: TInputCheckBoxElement;
    FSubtractionLabel: TLabelElement;
    FSubtractionEdit: TInputCheckBoxElement;
    FMultiplicationLabel: TLabelElement;
    FMultiplicationEdit: TInputCheckBoxElement;
    FCustomLabel: TLabelElement;
    FCustomEdit: TInputCheckBoxElement;
    FButtonGenerate: TButtonGenerate;
    {$IFNDEF SIMPLIFIED}
    FButtonDownload: TButtonGenerate;
    {$ENDIF}
    FSvgDocument: TSvgElement;
    FFontChars: JFontCharacters;
    FImage: TImageElement;
  public
    constructor Create(Owner: IHtmlElementOwner); overload; override;

    procedure Resize(Event: JEvent);
    procedure GenerateLollipop;
    procedure DownloadLollipop(Svg: JSVGSVGElement);
  end;

var
  MainScreen: TMainScreen;

implementation

uses
  ECMA.Date, ECMA.JSON, ECMA.Console, ECMA.Encode, W3C.Geometry, W3C.CSSOM,
  W3C.CSSOMView, W3C.UIEvents, W3C.TouchEvents, W3C.WebStorage, WHATWG.XHR,
  {$IFDEF UseXmlSerializer}W3C.DOMParser{$ELSE}W3C.FileAPI{$ENDIF};


{ TMainScreen }

constructor TMainScreen.Create(Owner: IHtmlElementOwner);
begin
  inherited Create(Owner);

  MainScreen := Self;
  DivElement.ID := 'main';

  var OuterContainer := TOuterContainer.Create(Self as IHtmlElementOwner);

  FImage := TImageElement.Create(OuterContainer as IHtmlElementOwner);
  FImage.ImageElement.src := 'Lollipop.svg';

  var Container := TControlContainer.Create(OuterContainer as IHtmlElementOwner);
  FTextLabel := TLabelElement.Create(Container as IHtmlElementOwner);
  FTextEdit := TInputTextElement.Create(Container as IHtmlElementOwner);
  FTextEdit.Value := 'MATHEMATIK';
  FTextLabel.Text := 'Text:';
  FTextLabel.Style.marginRight := '1em';
  Variant(FTextLabel.LabelElement).&for := FTextEdit.InputElement;

  Container := TControlContainer.Create(OuterContainer as IHtmlElementOwner);
  FMaximumLabel := TLabelElement.Create(Container as IHtmlElementOwner);
  FMaximumLabel.Style.marginRight := '1em';
  FMaximumEdit := TInputTextElement.Create(Container as IHtmlElementOwner);
  FMaximumEdit.InputElement.max := '99999';
  FMaximumEdit.InputElement.min := '20';
  FMaximumEdit.InputElement.value := '999';
  FMaximumLabel.Text := 'Maximum Value:';
  Variant(FMaximumLabel.LabelElement).&for := FMaximumEdit.InputElement;

  Container := TControlContainer.Create(OuterContainer as IHtmlElementOwner);
  FFeintsLabel := TLabelElement.Create(Container as IHtmlElementOwner);
  FFeintsLabel.Style.marginRight := '1em';
  FFeintsEdit := TInputCheckBoxElement.Create(Container as IHtmlElementOwner);
  FFeintsEdit.InputElement.checked := True;
  FFeintsLabel.Text := 'Generate Feints';
  Variant(FFeintsLabel.LabelElement).&for := FFeintsEdit.InputElement;

  Container := TControlContainer.Create(OuterContainer as IHtmlElementOwner);
  var Category := TParagraphElement.Create(Container as IHtmlElementOwner);
  Category.Style.display := 'inline';
  Category.Text := 'Operation: ';
  FAdditionLabel := TLabelElement.Create(Container as IHtmlElementOwner);
  FAdditionLabel.Text := 'Addition';
  FAdditionEdit := TInputCheckBoxElement.Create(Container as IHtmlElementOwner);
  FAdditionEdit.InputElement.checked := True;
  FAdditionEdit.Style.marginRight := '1em';
  Variant(FAdditionLabel.LabelElement).&for := FAdditionEdit.InputElement;

  FSubtractionLabel := TLabelElement.Create(Container as IHtmlElementOwner);
  FSubtractionLabel.Text := 'Subtraction';
  FSubtractionEdit := TInputCheckBoxElement.Create(Container as IHtmlElementOwner);
  FSubtractionEdit.InputElement.checked := True;
  FSubtractionEdit.Style.marginRight := '1em';
  Variant(FSubtractionLabel.LabelElement).&for := FSubtractionEdit.InputElement;

  FMultiplicationLabel := TLabelElement.Create(Container as IHtmlElementOwner);
  FMultiplicationLabel.Text := 'Multiplication';
  FMultiplicationEdit := TInputCheckBoxElement.Create(Container as IHtmlElementOwner);
  FMultiplicationEdit.InputElement.checked := False;
  FMultiplicationEdit.Style.marginRight := '1em';
  Variant(FMultiplicationLabel.LabelElement).&for := FMultiplicationEdit.InputElement;

  FCustomLabel := TLabelElement.Create(Container as IHtmlElementOwner);
  FCustomLabel.Text := 'Custom';
  FCustomEdit := TInputCheckBoxElement.Create(Container as IHtmlElementOwner);
  FCustomEdit.InputElement.checked := False;
  FCustomEdit.Style.marginRight := '1em';
  Variant(FCustomLabel.LabelElement).&for := FCustomEdit.InputElement;

  Container := TControlContainer.Create(OuterContainer as IHtmlElementOwner);
  FButtonGenerate := TButtonGenerate.Create(Container as IHtmlElementOwner);
  FButtonGenerate.Text := 'Generate';
  FButtonGenerate.ButtonElement.addEventListener('click', lambda
    GenerateLollipop;
  end);
  FButtonGenerate.ButtonElement.addEventListener('touchstart', lambda
    GenerateLollipop;
  end);

  {$IFNDEF SIMPLIFIED}
  FButtonDownload := TButtonGenerate.Create(Container as IHtmlElementOwner);
  FButtonDownload.Text := 'Download';
  FButtonDownload.ButtonElement.addEventListener('click', lambda
    DownloadLollipop(FSvgDocument.SvgElement);
  end);
  FButtonDownload.ButtonElement.addEventListener('touchstart', lambda
    DownloadLollipop(FSvgDocument.SvgElement);
  end);
  {$ENDIF}

  FSvgDocument := TSvgElement.Create(Self as IHtmlElementOwner);

  var Request := JXMLHttpRequest.Create;
  Request.onload := lambda
    var Font := JHersheyFont(JSON.Parse(Request.responseText));
    FFontChars := Font.Chars;

    Result := nil;
  end;
  Request.overrideMimeType('application/json');
  Request.responseType := 'application/json';
  Request.open('GET', 'HersheyFont.json', true);
  Request.send;

  Resize(nil);
end;

procedure TMainScreen.Resize(Event: JEvent);
begin
  // TODO
end;

procedure TMainScreen.GenerateLollipop;
begin
  var Lollipop := TLollipop.Create(FFontChars);
  Lollipop.Maximum := StrToInt(FMaximumEdit.InputElement.value);
  Lollipop.Text := FTextEdit.Value;
  Lollipop.UseFeints := FFeintsEdit.InputElement.checked;
  var Operations: TOperations := [];
  if FAdditionEdit.InputElement.checked then
    Include(Operations, opAdd);
  if FSubtractionEdit.InputElement.checked then
    Include(Operations, opSub);
  if FMultiplicationEdit.InputElement.checked then
    Include(Operations, opMul);
  if FCustomEdit.InputElement.checked then
    Include(Operations, opCustom);
  Lollipop.Operations := Operations;

  {$IFDEF SIMPLIFIED}
  var ScaleFactor := 4;
  var Svg := JSVGSVGElement(Document.createElementNS('http://www.w3.org/2000/svg', 'svg'));

  Svg.setAttribute('width', IntToStr(Round(ScaleFactor * (Lollipop.Width + 2 * Lollipop.Margin))));
  Svg.setAttribute('height', IntToStr(Round(ScaleFactor * (24 + Lollipop.DotCount * 5 + 30 + 2 * Lollipop.Margin))));

  Lollipop.RenderToSvg(Svg, ScaleFactor);
  DownloadLollipop(Svg);
  {$ELSE}
  var ScaleFactor := 4;
  var Svg := FSvgDocument.SvgElement;

  // clear SVG document
  while Svg.lastChild <> nil do
    Svg.removeChild(Svg.lastChild);

  Svg.setAttribute('width', IntToStr(Round(ScaleFactor * (Lollipop.Width + 2 * Lollipop.Margin))));
  Svg.setAttribute('height', IntToStr(Round(ScaleFactor * (24 + Lollipop.DotCount * 5 + 30 + 2 * Lollipop.Margin))));

  Lollipop.RenderToSvg(FSvgDocument.SvgElement, ScaleFactor);
  {$ENDIF}
end;

procedure TMainScreen.DownloadLollipop(Svg: JSVGSVGElement);
begin
  {$IFDEF UseXmlSerializer}
  var Serializer := JXMLSerializer.Create;
  var Source := Serializer.serializeToString(Svg);

  //add xml declaration
  Source := '<?xml version="1.0" standalone="no"?>'#13#10 + Source;
  var svgUrl := 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(Source);
  {$ELSE}
  var SvgData := Svg.outerHTML;
  var SvgBlob := JBlob.Create([svgData], JBlobPropertyBag(
    class
      &type = 'image/svg+xml;charset=utf-8'
    end));
  var svgUrl := JURL.createObjectURL(svgBlob);
  {$ENDIF}

  var DownloadLink := JHTMLLinkElement(document.createElement('a'));
  DownloadLink.href := svgUrl;
  DownloadLink.download := 'Lollipop ' + FTextEdit.InputElement.value + '.svg';
  Document.body.appendChild(downloadLink);
  DownloadLink.click;
  Document.body.removeChild(downloadLink);
end;

end.