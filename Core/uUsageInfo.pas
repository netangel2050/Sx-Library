unit uUsageInfo;

interface

uses
  uTypes;

var
  DefaultAskedForUpload: BG = False;

procedure TryUploadData(const AURL: string; const AForce: BG = False);

implementation

uses
  SysUtils,
  Classes,
  OmniXML,
  uStrings,
  uSxIniFile,
  uLocalMainCfg,
  uWebUpdate,
  uProjectInfo,
  uOperatingSystem,
  uTemporaryDirectory,
  uSystemMemory,
  uFileStatistics,
  uFiles,
  uSystemPaths,
  uCommonApplication,
  uCPU,
  uMainLog,
  uOutputInfo,
  uMsg,
  uSxXMLDocument;

type
  TUsageInfo = class
    // Commands - usability - SxAction - keys+shortcuts
    // RunCount/Time

    // AvgRunTime w/o bug
    // Error Messages
    // Any operation time


    // Startup
    // Configuration
    // Hardware CPU, RAM, Disk
    // OS

  end;

var
  AskedForUpload: BG;
  UploadInfo: BG;
  LastUploadCount: UG;
  LastUploadTime: U8;

procedure RWOptions(const Save: BG);
begin
  if Save = False then
  	AskedForUpload := DefaultAskedForUpload;
  LocalMainCfg.RWBool('Upload', 'AskedForUpload', AskedForUpload, Save);
  if Save = False then
  	UploadInfo := True;
  LocalMainCfg.RWBool('Upload', 'UploadInfo', UploadInfo, Save);
  LocalMainCfg.RWNum('Upload', 'LastUploadCount', LastUploadCount, Save);
  LocalMainCfg.RWNum('Upload', 'LastUploadTime', LastUploadTime, Save);
end;

function GetComputerGUID: TGUID;
var
  SxMainIni: TSxIniFile;
  s: string;
begin
	SxMainIni := TSxIniFile.Create(SystemPaths.CompanyLocalAppDataDir + 'Main.ini');
  try
    SxMainIni.RWString('Computer', 'GUID', s, False);
    if s = '' then
    begin
      CreateGUID(Result);
      SxMainIni.WriteString('Computer', 'GUID', GUIDToString(Result));
    end
    else
      Result := StringToGUID(s);
  finally
  	SxMainIni.Free;
  end;
end;

function GetXMLText: string;
var
  GUID: TGUID;
  XMLDocument: IXMLDocument;

  procedure SaveData(const Name, Value: string);
  var
  	XMLElement: IXMLElement;
  begin
		XMLElement := XMLDocument.CreateElement(Name);
    XMLElement.Text := Value;
    XMLDocument.DocumentElement.AppendChild(XMLElement);
  end;

var
  XMLElement: IXMLElement;
begin
  GUID := GetComputerGUID;

	XMLDocument := TSxXMLDocument.Create;
	try
		XMLElement := XMLDocument.CreateElement('root');
    XMLDocument.AppendChild(XMLElement);

    // Key
    SaveData('GUID', GUIDToString(GUID));
    SaveData('ComputerName', OperatingSystem.ComputerName);
    SaveData('ProjectName', GetProjectInfo(piInternalName));

    // Version
    SaveData('ProjectVersion', GetProjectInfo(piFileVersion));

    // Statistics
    SaveData('RunCount', IntToStr(CommonApplication.Statistics.RunCount));
    SaveData('RunTime', IntToStr(CommonApplication.Statistics.TotalElapsedTime.Milliseconds));
    SaveData('ReadCount', IntToStr(FileStatistics.ReadCount));
    SaveData('WriteCount', IntToStr(FileStatistics.WriteCount));
    SaveData('ReadBytes', IntToStr(FileStatistics.ReadBytes));
    SaveData('WriteBytes', IntToStr(FileStatistics.WriteBytes));

    // OS
    SaveData('OSName', OperatingSystem.Name);
    SaveData('OSMajor', IntToStr(Win32MajorVersion));
    SaveData('OSMinor', IntToStr(Win32MinorVersion));
    SaveData('OSBuild', IntToStr(Win32BuildNumber));

    // Hardware
    SaveData('CPU', IntToStr(CPU.ID));
    SaveData('CPUName', CPU.Name);
    SaveData('CPUFrequency', IntToStr(CPU.DefaultFrequency));
    SaveData('LogicalProcessorCount', IntToStr(CPU.LogicalProcessorCount));

    SaveData('MemoryTotalPhys', IntToStr(SystemMemory.Physical.Total));
    SaveData('MemoryTotalPageFile', IntToStr(SystemMemory.PageFile.Total));

		Result := TSxXMLDocument(XMLDocument).GetAsString;
	finally
		XMLDocument := nil;
		// Release XML document
	end;
end;

function UploadData(const AURL: string): BG;
var
  FileName, ResponseFileName: TFileName;
  Source: TStrings;
  TempDir: string;
  Response: string;
begin
  TempDir := TemporaryDirectory.ProcessTempDir;
  ResponseFileName := TempDir + 'response.txt';
  Source := TStringList.Create;
  try
    Source.Add('data=' + GetXMLText);
    Result := DownloadFileWithPost(AURL, Source, False, ResponseFileName);
    if Result then
    begin
      Response := ReadStringFromFile(ResponseFileName);
      if Response <> 'Done.' then
      begin
        Result := False;
        MainLog.Add('Invalid response: ' + Response, mlError);
  //      raise Exception.Create('Invalid response.');
      end;
    end;
  finally
    Source.Free;
    DeleteFile(FileName);
    DeleteFile(ResponseFileName);
  end;
end;

procedure UploadAndUpdateOptions(const AURL: string);
begin
  if UploadData(AURL) then
  begin
    LastUploadCount := CommonApplication.Statistics.RunCount;
    LastUploadTime := CommonApplication.Statistics.TotalElapsedTime.Milliseconds;
    RWOptions(True);
  end;
end;

function CanUpload: BG;
begin
  if AskedForUpload = False then
  begin
    if Confirmation('To improve future versions of ' + GetProjectInfo(piProductName) + ', we can collect statistics on which application features you use. No sensitive information will be collected.' + FullSep +
      'Do you wish to contribute your usage statistics?', [mbYes, mbNo]) = mbYes then
    begin
      UploadInfo := True;
    end
    else
      UploadInfo := False;
    AskedForUpload := True;
    RWOptions(True);
  end;
  Result := UploadInfo;
end;

function TimeForUpload: BG;
const
  MaxUploadInterval = 30 * Minute;
  MaxUploadCount = 20;
begin
  Result := (CommonApplication.Statistics.TotalElapsedTime.Milliseconds >= LastUploadTime + MaxUploadInterval) or (CommonApplication.Statistics.RunCount >= LastUploadCount + MaxUploadCount);
end;

procedure TryUploadData(const AURL: string; const AForce: BG = False);
begin
  if (CommonApplication = nil) or (LocalMainCfg = nil) then
    Exit;
  try
    RWOptions(False);
    if AForce or (TimeForUpload and CanUpload) then
    begin
      UploadAndUpdateOptions(AURL);
    end;
  except
    on E: Exception do
      if MainLog.IsLoggerFor(mlError) then
        MainLog.Add(E.Message, mlError);
  end;
end;

end.
