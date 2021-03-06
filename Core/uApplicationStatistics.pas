unit uApplicationStatistics;

interface

uses
  uTypes,
  uFileStatistics,
  uSxIniFile,
  uTimeSpan;

type
  TRunStatistics = record
    Count: U8;
    TotalElapsedTimeInMs: U8;
  end;

  TSection = record
    RunStatistics: TRunStatistics;
    FileStatistics: TFileStatistics;
  end;

  TApplicationStatistics = class
  strict private
    FSection: TSection;
    FRunFirstTime: BG;
    FStartTime: U8;
    FElapsedTime: TTimeSpan;
    FTotalElapsedTime: TTimeSpan;
    procedure RWData(const ASave: BG);
    procedure RWSection(const AIniFile: TSxIniFile; const ASave: BG);
    function GetElapsedTime: TTimeSpan;
  public
    constructor Create;
    destructor Destroy; override;

    property ElapsedTime: TTimeSpan read GetElapsedTime;
    property TotalElapsedTime: TTimeSpan read FTotalElapsedTime;
    property RunCount: U8 read FSection.RunStatistics.Count;
    property RunFirstTime: BG read FRunFirstTime;
  end;

implementation

uses
	uProjectInfo,
  uMainTimer,
  uMainCfg,
  uLocalMainCfg;

{ TApplicationStatistics }

constructor TApplicationStatistics.Create;
begin
  inherited;

	FStartTime := MainTimer.Value.Ticks;

  RWData(False);
	Inc(FSection.RunStatistics.Count);

	Assert(FSection.RunStatistics.Count > 0);
	FRunFirstTime := FSection.RunStatistics.Count <= 1;
end;

destructor TApplicationStatistics.Destroy;
begin
  RWData(True);

  inherited;
end;

function TApplicationStatistics.GetElapsedTime: TTimeSpan;
begin
  FElapsedTime.Ticks := MainTimer.IntervalFrom(FStartTime);
  Result := FElapsedTime;
end;

const
	Section = 'Statistics';

procedure TApplicationStatistics.RWData(const ASave: BG);
begin
  if ASave then
  begin
    FSection.FileStatistics := FileStatistics;
    FSection.RunStatistics.TotalElapsedTimeInMs := FTotalElapsedTime.Milliseconds;
  	if Assigned(LocalMainCfg) then
    begin
      FSection.RunStatistics.TotalElapsedTimeInMs := FTotalElapsedTime.Milliseconds + ElapsedTime.Milliseconds;
      LocalMainCfg.WriteString(Section, 'Version', GetProjectInfo(piProductVersion));
      RWSection(LocalMainCfg, True);
    end;

    // Backward compatibility
  	if Assigned(MainCfg) then
      LocalMainCfg.DeleteSection(Section);
  end
  else
  begin
    FSection.RunStatistics.TotalElapsedTimeInMs := 0;
    FSection.FileStatistics := FileStatistics;

    // Backward compatibility
  	if Assigned(LocalMainCfg) then
      RWSection(LocalMainCfg, False);

  	if Assigned(LocalMainCfg) then
      RWSection(LocalMainCfg, False);

    FTotalElapsedTime.Milliseconds := FSection.RunStatistics.TotalElapsedTimeInMs;
    FileStatistics := FSection.FileStatistics;
	end;
end;

procedure TApplicationStatistics.RWSection(const AIniFile: TSxIniFile; const ASave: BG);
begin
  AIniFile.ReadAndIncrementOrWrite(Section, 'RunCount', FSection.RunStatistics.Count, ASave);
  AIniFile.ReadAndIncrementOrWrite(Section, 'RunTime', FSection.RunStatistics.TotalElapsedTimeInMs, ASave);
  AIniFile.ReadAndIncrementOrWrite(Section, 'ReadCount', FSection.FileStatistics.ReadCount, ASave);
  AIniFile.ReadAndIncrementOrWrite(Section, 'ReadBytes', FSection.FileStatistics.ReadBytes, ASave);
  AIniFile.ReadAndIncrementOrWrite(Section, 'WriteCount', FSection.FileStatistics.WriteCount, ASave);
  AIniFile.ReadAndIncrementOrWrite(Section, 'WriteBytes', FSection.FileStatistics.WriteBytes, ASave);
end;

end.

