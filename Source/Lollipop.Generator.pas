unit Lollipop.Generator;

interface

uses
  W3C.SVG2;

type
  JFontCharacter = class external
    d: String;
    o: Integer;
  end;
  JFontCharacters = array of JFontCharacter;

  JHersheyFont = class external
    name: String;
    chars: JFontCharacters;
  end;

  TTextPosition = (tpTop, tpTopLeft, tpTopRight, tpBottom, tpBottomLeft,
    tpBottomRight, tpLeft, tpRight, tpMiddle);

  TLollipopDot = class
  private
    FX, FY: Integer;
    FValue: Integer;
    FColor: String;
    FTextPosition: TTextPosition;
    FIsFeint: Boolean;
  public
    constructor Create(X, Y, Value: Integer; Color: String;
      TextPosition: TTextPosition = tpTop; IsFeint: Boolean = False);

    property Color: String read FColor;
    property Value: Integer read FValue;
    property X: Integer read FX;
    property Y: Integer read FY;
    property TextPosition: TTextPosition read FTextPosition;
    property IsFeint: Boolean read FIsFeint;
  end;

  TLollipopProblemGroup = class
  private
    FProblems: array of String;
    FColor: String;
  public
    constructor Create(Color: String);

    property Color: String read FColor;
    property Problems: array of String read FProblems;
  end;

  TArrayOfInteger = array of Integer;

  TOperation = (opAdd, opSub, opMul, opCustom);
  TOperations = set of TOperation;

  TLollipop = class
  private
    FText: string;
    FUseFeints: Boolean;
    FOperations: TOperations;
    FChars: JFontCharacters;
    FDotCount: Integer;
    FMaximum: Integer;
    FWidth: Integer;
    FColorCount: Integer;
    FMargin: Integer;
    FStrokes: TArrayOfInteger;
    FColors: array of String;
    FNumbers: TArrayOfInteger;
    FFeints: TArrayOfInteger;
    FProblems: array of String;
    FProblemGroups: array of TLollipopProblemGroup;
    FDots: array of TLollipopDot;
    procedure CalculateStatistics;
    procedure GenerateNumbers;
    procedure GenerateMathProblems;
    procedure GenerateFeints;
    procedure RandomizeColors;
    procedure SetupColors;
    procedure CalculateDots;
    procedure GatherProblemGroups;

    procedure SetMaximum(Value: Integer);
    procedure SetMargin(Value: Integer);
    procedure SetText(Value: String);
    procedure SetUseFeints(Value: Boolean);
    procedure SetOperations(Value: TOperations);
  protected
    procedure MarginChanged;
    procedure MaximumChanged;
    procedure OperationsChanged;
    procedure TextChanged;
    procedure UseFeintsChanged;

    procedure RenderTextToSvg(Svg: JSVGSVGElement);
    procedure RenderDotsToSvg(Svg: JSVGSVGElement);
    procedure RenderQuestionsToSvg(Svg: JSVGSVGElement);
  public
    constructor Create(Chars: JFontCharacters);

    procedure RenderToSvg(Svg: JSVGSVGElement; ScaleFactor: Float = 1);

    property Margin: Integer read FMargin write SetMargin;
    property Text: String read FText write SetText;
    property Maximum: Integer read FMaximum write SetMaximum;
    property Width: Integer read FWidth;
    property UseFeints: Boolean read FUseFeints write SetUseFeints;
    property Operations: TOperations read FOperations write SetOperations;
    property ColorCount: Integer read FColorCount;
    property DotCount: Integer read FDotCount;
  end;

const
  XMLNS = 'http://www.w3.org/2000/svg';

implementation

uses
  W3C.DOM4, WHATWG.Console;

{ TLollipopDot }

constructor TLollipopDot.Create(X, Y, Value: Integer; Color: String;
  TextPosition: TTextPosition = tpTop; IsFeint: Boolean = False);
begin
  FX := X;
  FY := Y;
  FValue := Value;
  FColor := Color;
  FTextPosition := TextPosition;
  FIsFeint := IsFeint;
end;


{ TLollipopProblemGroup }

constructor TLollipopProblemGroup.Create(Color: String);
begin
  FColor := Color;
end;


{ TLollipop }

constructor TLollipop.Create(Chars: JFontCharacters);
begin
  FChars := Chars;
  FMaximum := 999;
  FMargin := 12;
  FUseFeints := True;
  FOperations := [opAdd, opSub];
end;

function HueToColor(Hue: Float): String;
var
  M1, M2: Float;
const
  // reciprocal mul. opt.
  COne255th = 1 / 255;
  COne6th = 1 / 6;
  COne3rd = 1 / 3;

  function IntHueToColor(Hue: Float): Integer;
  var
    V: Float;
  begin
    Hue := Hue - Floor(Hue);
    if 6 * Hue < 1 then
      V := M1 + (M2 - M1) * Hue * 6
    else if 2 * Hue < 1 then
      V := M2
    else if 3 * Hue < 2 then
      V := M1 + (M2 - M1) * (2 * COne3rd - Hue) * 6
    else
      V := M1;
    Result := Round(V * $FF);
  end;

begin
  var S := 1;
  var L := 0.3 + 0.2 * Random;
  M2 := L * (1 + S);
  M1 := 2 * L - M2;
  Result := '#' +
    IntToHex(IntHueToColor(Hue + COne3rd), 2) +
    IntToHex(IntHueToColor(Hue), 2) +
    IntToHex(IntHueToColor(Hue - COne3rd), 2);
end;

procedure TLollipop.SetupColors;
begin
  FColors.Clear;
  for var Index := 0 to FColorCount - 1 do
    FColors.Add(HueToColor(Index / FColorCount));
end;

procedure TLollipop.RandomizeColors;
begin
  for var Index := Low(FColors) to High(FColors) do
    FColors.Swap(RandomInt(FColorCount), RandomInt(FColorCount));
end;

procedure TLollipop.CalculateStatistics;
begin
  FWidth := 0;
  FDotCount := 0;
  FColorCount := 0;

  for var Index := 1 to Length(FText) do
  begin
    var CurrentChar := UpperCase(FText[Index]);
    var CharData := FChars[Ord(CurrentChar) - Ord('A')].D;
    var CharOffset := FChars[Ord(CurrentChar) - Ord('A')].O;

    var PenDown := False;
    var StrokeCount := 0;
    while Length(CharData) > 0 do
    begin
      Inc(FDotCount);

      // get command
      if CharData[1] = 'M' then
      begin
        if StrokeCount > 0 then
          FStrokes.Add(StrokeCount);
        StrokeCount := 0;
        PenDown := False;
        Delete(CharData, 1, 1);
        Inc(FColorCount);
      end
      else
      if CharData[1] = 'L' then
      begin
        PenDown := True;
        Delete(CharData, 1, 1);
      end;

      Inc(StrokeCount);

      var SepPos := Pos(' ', CharData);
      if SepPos = 0 then
        SepPos := Length(CharData) + 1;
      Delete(CharData, 1, SepPos);
    end;

    FStrokes.Add(StrokeCount);
    FWidth := FWidth + 10 + CharOffset;
  end;

  FWidth := FWidth + 2;
end;

procedure TLollipop.GenerateNumbers;
begin
  FNumbers.Clear;

  for var Index := 0 to FDotCount - 1 do
  begin
    var NewValue: Integer;
    repeat
      NewValue := RandomInt(Maximum + 1);
    until FNumbers.IndexOf(NewValue) < 0;

    FNumbers.Add(NewValue);
  end;
end;

procedure TLollipop.GenerateFeints;
begin
  FFeints.Clear;

  if not UseFeints then
    exit;

  for var Index := 0 to 3 * FColorCount do
  begin
    var Found: Boolean;
    var NewValue: Integer;
    repeat
      NewValue := RandomInt(Maximum + 1);
      Found := FNumbers.IndexOf(NewValue) >= 0;

      if not Found and (Length(FFeints) > 0) then
        Found := FFeints.IndexOf(NewValue) >= 0;
    until not Found;

    FFeints.Add(NewValue);
  end;
end;

procedure TLollipop.GenerateMathProblems;
var
  Operation: TOperation;
  Problem: String;
  Test: Integer;
begin
  FProblems.Clear;

  for var Index := Low(FNumbers) to High(FNumbers) do
  begin
    var Value := FNumbers[Index];

    // get random operation
    repeat
      case RandomInt(15) of
        5..7:
          Operation := opSub;
        8..9:
          Operation := opMul;
        10..14:
          Operation := opCustom;
        else
          Operation := opAdd;
      end;

      if (Operation = opMul) and IsPrime(Value) then
      begin
        repeat
          Value := RandomInt(Maximum + 1);
        until (FNumbers.IndexOf(Value) < 0) and not IsPrime(Value);
        FNumbers[Index] := Value;
      end;
    until Operation in FOperations;

    case Operation of
      opAdd:
        begin
          var A := RandomInt(Value);
          var B := Value - A;
          Problem := IntToStr(A) + ' + ' + IntToStr(B) + ' =';
        end;
      opSub:
        begin
          var A := Value + RandomInt(FMaximum - Value + 1);
          var B := A - Value;

          Problem := IntToStr(A) + ' - ' + IntToStr(B) + ' =';
        end;
      opMul:
        begin
          repeat
            Test := RandomInt(Value);
          until (Value mod Test = 0) and (Test <> 1);

          var A := Test;
          var B := Value div Test;

          Problem := IntToStr(A) + ' * ' + IntToStr(B) + ' =';
        end;
      opCustom:
        begin
          Problem := ' = ' + IntToStr(Value);
        end;
    end;

    FProblems.Add(Problem);
  end;
end;

procedure TLollipop.GatherProblemGroups;
begin
  FProblemGroups.Clear;
  var ProblemIndex := 0;
  Assert(FColorCount = FStrokes.Length);

  for var Index := 0 to FColorCount - 1 do
  begin
    var ProblemGroup := TLollipopProblemGroup.Create(FColors[Index]);

    for var ItemIndex := 0 to FStrokes[Index] - 1 do
    begin
      ProblemGroup.Problems.Add(FProblems[ProblemIndex]);
      Inc(ProblemIndex);
    end;

    FProblemGroups.Add(ProblemGroup);
  end;

  // shuffle problems
  for var Index := Low(FProblemGroups) to High(FProblemGroups) do
    FProblemGroups.Swap(RandomInt(FProblemGroups.Length), RandomInt(FProblemGroups.Length));

  // sort to have short groups in front
  FProblemGroups.Sort(lambda(Left, Right: TLollipopProblemGroup): Integer
      Result := Left.Problems.Length - Right.Problems.Length;
    end);
end;

procedure TLollipop.SetMargin(Value: Integer);
begin
  if Value <> FMargin then
  begin
    FMargin := Value;
    MarginChanged;
  end;
end;

procedure TLollipop.SetMaximum(Value: Integer);
begin
  if Value <> FMaximum then
  begin
    FMaximum := Value;
    MaximumChanged;
  end;
end;

procedure TLollipop.SetOperations(Value: TOperations);
begin
  if Variant(Value) <> Variant(FOperations) then
  begin
    FOperations := Value;
    OperationsChanged;
  end;
end;

procedure TLollipop.SetText(Value: String);
begin
  if Value <> FText then
  begin
    FText := Value;
    TextChanged;
  end;
end;

procedure TLollipop.SetUseFeints(Value: Boolean);
begin
  if Value <> FUseFeints then
  begin
    FUseFeints := Value;
    UseFeintsChanged;
  end;
end;

procedure TLollipop.MaximumChanged;
begin
  GenerateNumbers;
  GenerateMathProblems;
  GenerateFeints;
  CalculateDots;
  GatherProblemGroups;
end;

procedure TLollipop.MarginChanged;
begin
  CalculateDots;
end;

procedure TLollipop.OperationsChanged;
begin
  GenerateMathProblems;
  GenerateFeints;
  CalculateDots;
  GatherProblemGroups;
end;

procedure TLollipop.TextChanged;
begin
  CalculateStatistics;
  SetupColors;
  RandomizeColors;
  GenerateNumbers;
  GenerateMathProblems;
  GenerateFeints;
  CalculateDots;
  GatherProblemGroups;
end;

procedure TLollipop.UseFeintsChanged;
begin
  GenerateFeints;
  CalculateDots;
end;

procedure TLollipop.CalculateDots;
begin
  var ColorIndex := -1;
  var DotIndex := 0;
  var Offset := 0;
  FDots.Clear;

  for var Index := 1 to Length(FText) do
  begin
    var CurrentChar := UpperCase(FText[Index]);
    var CharData := FChars[Ord(CurrentChar) - Ord('A')].d;
    var CharOffset := FChars[Ord(CurrentChar) - Ord('A')].o;

    var PenDown := False;
    while Length(CharData) > 0 do
    begin
      CharOffset := FChars[Ord(CurrentChar) - Ord('A')].o;
      // get command
      if CharData[1] = 'M' then
      begin
        PenDown := False;
        Delete(CharData, 1, 1);
        Inc(ColorIndex);
      end
      else
      if CharData[1] = 'L' then
      begin
        PenDown := True;
        Delete(CharData, 1, 1);
      end;

      var SepPos := Pos(',', CharData);
      var X := Offset + StrToInt(Copy(CharData, 1, SepPos - 1));
      Delete(CharData, 1, SepPos);

      SepPos := Pos(' ', CharData);
      if SepPos = 0 then
        SepPos := Length(CharData) + 1;
      var Y := StrToInt(Copy(CharData, 1, SepPos - 1));
      Delete(CharData, 1, SepPos);

      var TextPosition := tpRight;
      if Y < 5 then
        TextPosition := tpTop
      else
      if Y >= 20 then
        TextPosition := tpBottom;

      // add dots to dot array
      FDots.Add(TLollipopDot.Create(FMargin + X, FMargin + Y,
        FNumbers[DotIndex], FColors[ColorIndex], TextPosition));

      Inc(DotIndex);
    end;

    Offset := Offset + 10 + CharOffset;
  end;

  // calculate dots for the feints
  for var Index := Low(FFeints) to High(FFeints) do
  begin
    var X := RandomInt(2 * FMargin + FWidth);
    var Y := 4 + RandomInt(2 * FMargin + 2);

    var TextPosition := TTextPosition(RandomInt(High(TTextPosition)));

    // add dots to dot array
    FDots.Add(TLollipopDot.Create(X, Y, FFeints[Index],
      FColors[RandomInt(Length(FColors))], TextPosition, True));
  end;
end;

procedure TLollipop.RenderTextToSvg(Svg: JSVGSVGElement);
begin
  var Offset := 0;
  var ColorIndex := -1;
  var Group := Document.createElementNS(xmlns, 'g');
  Group.setAttribute('id', 'HersheyText');
  Svg.appendChild(Group);
  for var Index := 1 to Length(FText) do
  begin
    var CurrentChar := UpperCase(FText[Index]);
    var CharData := FChars[Ord(CurrentChar) - Ord('A')].d;
    var CharOffset := FChars[Ord(CurrentChar) - Ord('A')].o;

    var Path := Document.createElementNS(xmlns, 'path');
    Path.setAttribute('id', 'Letter' + CurrentChar + 'Path' + IntToStr(Index));
    Path.setAttribute('stroke', '#000000');
    Path.setAttribute('stroke-width', '1');
    Path.setAttribute('fill', 'none');
    Path.setAttribute('d', CharData);
    Path.setAttribute('transform', 'translate(' + IntToStr(FMargin + Offset) + ', ' + IntToStr(FMargin)+ ')');
    Group.appendChild(Path);

    Offset := Offset + 10 + CharOffset;
  end;
end;

procedure TLollipop.RenderDotsToSvg(Svg: JSVGSVGElement);
begin
  var OuterGroup := JSVGGElement(Document.createElementNS(xmlns, 'g'));
  OuterGroup.setAttribute('id', 'Dots');
  Svg.appendChild(OuterGroup);

  procedure UpdateTextPosition(Text: JSVGTextElement;
    TextPosition: TTextPosition; X, Y: Integer);
  begin
    case TextPosition of
      tpTop:
        begin
          Text.setAttribute('text-anchor', 'middle');
          Text.setAttribute('alignment-baseline', 'middle');
          Text.setAttribute('x', IntToStr(X));
          Text.setAttribute('y', FloatToStr(Y - 3.2));
        end;
      tpTopLeft:
        begin
          Text.setAttribute('text-anchor', 'end');
          Text.setAttribute('alignment-baseline', 'middle');
          Text.setAttribute('x', IntToStr(X));
          Text.setAttribute('y', FloatToStr(Y - 3.2));
        end;
      tpTopRight:
        begin
          Text.setAttribute('text-anchor', 'start');
          Text.setAttribute('alignment-baseline', 'middle');
          Text.setAttribute('x', IntToStr(X));
          Text.setAttribute('y', FloatToStr(Y - 3.2));
        end;
      tpBottom:
        begin
          Text.setAttribute('text-anchor', 'middle');
          Text.setAttribute('alignment-baseline', 'middle');
          Text.setAttribute('x', IntToStr(X));
          Text.setAttribute('y', FloatToStr(Y + 4.2));
        end;
      tpBottomLeft:
        begin
          Text.setAttribute('text-anchor', 'end');
          Text.setAttribute('alignment-baseline', 'middle');
          Text.setAttribute('x', IntToStr(X));
          Text.setAttribute('y', FloatToStr(Y + 4.2));
        end;
      tpBottomRight:
        begin
          Text.setAttribute('text-anchor', 'start');
          Text.setAttribute('alignment-baseline', 'middle');
          Text.setAttribute('x', IntToStr(X));
          Text.setAttribute('y', FloatToStr(Y + 4.2));
        end;
      tpLeft:
        begin
          Text.setAttribute('text-anchor', 'end');
          Text.setAttribute('alignment-baseline', 'middle');
          Text.setAttribute('x', FloatToStr(X - 2.5));
          Text.setAttribute('y', FloatToStr(Y + 0.5));
        end;
      tpRight:
        begin
          Text.setAttribute('text-anchor', 'start');
          Text.setAttribute('alignment-baseline', 'middle');
          Text.setAttribute('x', FloatToStr(X + 2.5));
          Text.setAttribute('y', FloatToStr(Y + 0.5));
        end;
      else
        begin
          Text.setAttribute('text-anchor', 'middle');
          Text.setAttribute('alignment-baseline', 'middle');
          Text.setAttribute('x', IntToStr(X));
          Text.setAttribute('y', IntToStr(Y));
        end;
    end;
  end;

  function ListContainsPath(List: JNodeList): Boolean;
  begin
    Result := False;
    for var Index := 0 to List.length - 1 do
      if List.item(Index) is JSVGPathElement then
        Exit(True);
  end;

  for var Dot in FDots do
  begin
    var InnerGroup := JSVGGElement(Document.createElementNS(xmlns, 'g'));
    InnerGroup.setAttribute('id', 'Dot' + IntToStr(Dot.Value));
    InnerGroup.setAttribute('style', 'fill:' + Dot.Color + ';stroke:none');
    OuterGroup.appendChild(InnerGroup);

    var Circle := Document.createElementNS(xmlns, 'circle');
    Circle.setAttribute('id', 'Circle' + IntToStr(Dot.Value));
    Circle.setAttribute('r', '1');
    Circle.setAttribute('cx', IntToStr(Dot.X));
    Circle.setAttribute('cy', IntToStr(Dot.Y));
    InnerGroup.appendChild(Circle);

    var Text := JSVGTextElement(Document.createElementNS(xmlns, 'text'));
    Text.setAttribute('id', 'Text' + IntToStr(Dot.Value));
    Text.innerHTML := IntToStr(Dot.Value);
    Text.style.fontSize := '4px';
    InnerGroup.appendChild(Text);
    var TextPosition := Dot.TextPosition;

    UpdateTextPosition(Text, TextPosition, Dot.X, Dot.Y);

    try
      // check for intersections
      if Dot.IsFeint then
      begin
        var IntersectList := Svg.getIntersectionList(InnerGroup.getBBox, OuterGroup);
        var TrialIndex := 0;

        while (IntersectList.length > 2) and (TrialIndex < 99) do
        begin
          var X := RandomInt(2 * FMargin + FWidth);
          var Y := 4 + RandomInt(2 * FMargin + 20);
          Circle.setAttribute('cx', IntToStr(X));
          Circle.setAttribute('cy', IntToStr(Y));
          UpdateTextPosition(Text, TextPosition, X, Y);

          IntersectList := Svg.getIntersectionList(InnerGroup.getBBox, OuterGroup);
          Inc(TrialIndex);
        end;
      end
      else
      begin
        var IntersectList := Svg.getIntersectionList(Text.getBBox, nil);
        if ListContainsPath(IntersectList) then
        begin
          // alter text position
          TextPosition := tpTop;
          repeat
            UpdateTextPosition(Text, TextPosition, Dot.X, Dot.Y);
            IntersectList := Svg.getIntersectionList(Text.getBBox, nil);
            Inc(TextPosition);
          until not ListContainsPath(IntersectList) or (TextPosition > tpRight);
          if ListContainsPath(IntersectList) then
            UpdateTextPosition(Text, Dot.TextPosition, Dot.X, Dot.Y);
        end;
      end;
    except
    end;
  end;
end;

procedure TLollipop.RenderQuestionsToSvg(Svg: JSVGSVGElement);
begin
  var Offset := 60;

  var Group := Document.createElementNS(xmlns, 'g');
  Group.setAttribute('id', 'Questions');

  for var ProblemGroup in FProblemGroups do
  begin
    var Text := Document.createElementNS(xmlns, 'text');
    Text.setAttribute('font-size', '5px');
    Text.setAttribute('line-height', '5px');
    Text.setAttribute('style', 'fill:' + ProblemGroup.Color + ';stroke:none');
    Text.setAttribute('x', IntToStr(Margin));
    Text.setAttribute('y', IntToStr(Offset));
    Text.style.fontSize := '5px';

    for var Problem in ProblemGroup.Problems do
    begin
      var TextSpan := Document.createElementNS(xmlns, 'tspan');
      TextSpan.innerHTML := Problem;
      TextSpan.setAttribute('font-size', '5px');
      TextSpan.setAttribute('line-height', '5px');
      TextSpan.setAttribute('x', IntToStr(Margin));
      TextSpan.setAttribute('y', IntToStr(Offset));
      Text.appendChild(TextSpan);

      Offset += 8;
    end;

    Offset += 8;
    Group.appendChild(Text);
  end;

  Svg.appendChild(Group);
end;

procedure TLollipop.RenderToSvg(Svg: JSVGSVGElement; ScaleFactor: Float = 1);
begin
  var SuspendDrawHandle := Svg.suspendRedraw(1000);
  Svg.currentScale := ScaleFactor;
  RenderTextToSvg(Svg);
  RenderDotsToSvg(Svg);
  RenderQuestionsToSvg(Svg);
  Svg.unsuspendRedraw(SuspendDrawHandle);
end;

end.