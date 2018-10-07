unit uGlobalOptions;

interface

uses
  uTypes,
  uOptions,
  uStartup,
  Graphics;

type
	TGlobalOption = (
    goLanguage,
    goMaxThreads,
    goStartMenuIcon, goDesktopIcon, goQuickLaunchIcon, goRunAfterStartUp,
		goShowSplashScreenWhenApplicationStarts,
		goMenuItemHeightScale,
		goWindowBackgroundTexture,
		goWindowBackgroundColor,
{$if CompilerVersion >= 23}
		goVisualStyle,
{$ifend}
		goAutomaticallyCheckForUpdate,
		goCheckForUpdateDaysPeriod);

var
	GlobalOptions: array [TGlobalOption] of TOption = (
		(Typ: vsCombo),
		(Typ: vsSpin; Default: 1; Minimum: 1; Maximum: 256),
		(Typ: vsCheck; Default: 1),
    (Typ: vsCheck; Default: 1),
    (Typ: vsCheck; Default: 1),
		(Typ: vsCheck; Default: 0),
    (Typ: vsCheck; Default: 1),
		(Typ: vsSpin; Default: 100; Minimum: 100; Maximum: 400),
		(Typ: vsCheck; Default: 1),
		(Typ: vsColor; Default: clBtnFace; Minimum: 0; Maximum: MaxInt),
{$if CompilerVersion >= 23}
		(Typ: vsFilename; DefaultStr: ''),
{$ifend}
		(Typ: vsCheck; Default: 1),
		(Typ: vsSpin; Default: 14; Minimum: 0; Maximum: 365));

	GlobalParams: array [TGlobalOption] of TParam;

	LastUpdate: TDateTime;

function GetBackgroundWindowTexture: BG;
function GetBackgroundWindowColor: TColor;

procedure RWCommon(const Save: BG);
procedure OptionChanged(const OptionIndex: SG);
function LinkChange(const GlobalOption: TGlobalOption; const ObjectChange: TObjectChange): BG;

implementation

uses
  SysUtils,
  Math,
  uFiles,
  uStartState,
  uDIniFile,
  uCPU,
  uStrings,
  // TODO
{$if CompilerVersion >= 23}
  Vcl.Themes,
  Vcl.Styles,
{$ifend}
  Forms,
	uSplash, uMenus, uMultiIns, uAbout, uLog, uSounds, uFileExt, uAPI, uNewThread,
	uMsgDlg, uMsg, ufOptions, uReg, uProjectInfo, uLink,
	uWebUpdate, uDictionary, uUsageInfo,
	Classes, Windows, ExtCtrls;

function GetBackgroundWindowTexture: BG;
begin
	Result := GlobalParams[goWindowBackgroundTexture].Bool;
end;

function GetBackgroundWindowColor: TColor;
begin
	Result := GlobalParams[goWindowBackgroundColor].Num;
end;

{$if CompilerVersion >= 23}
function GetVisualStylesDir: string;
begin
	if IsDebug then
		Result := 'C:\Projects\Safrad\' + '_common' + PathDelim + 'Visual Styles' + PathDelim
	else
		Result := WorkDir + 'Visual Styles' + PathDelim;
end;
{$ifend}

function LinkChange(const GlobalOption: TGlobalOption; const ObjectChange: TObjectChange): BG;
var
	LinkFileName, LinkFileName2: TFileName;
	Dir: string;
begin
	Result := False;
	case GlobalOption of
	goStartMenuIcon:
		begin
{			Dir := ShellFolder('Common Start Menu', True) + 'Programs' + PathDelim + GetProjectInfo
				(piProductName) + PathDelim; // Permision Denied if limited user! }
			Dir := ShellFolder('Start Menu', False) + 'Programs' + PathDelim + GetProjectInfo
				(piProductName) + PathDelim;
			LinkFileName := Dir + GetProjectInfo(piProductName) + '.lnk';
		end;
	goDesktopIcon:
		LinkFileName := ShellFolder('Common Desktop', True) + GetProjectInfo(piProductName) + '.lnk';
	goQuickLaunchIcon:
	begin
		LinkFileName := CommonAppDataDir + PathDelim + 'Microsoft' + PathDelim + 'Internet Explorer' +
			PathDelim + 'Quick Launch' + PathDelim;
		LinkFileName2 := LinkFileName + 'User Pinned\TaskBar\';
		if DirectoryExists(LinkFileName2) then
			LinkFileName := LinkFileName2;
		LinkFileName := LinkFileName + GetProjectInfo(piProductName) + '.lnk';
	end;
	end;
	case ObjectChange of
	ocTest:
		Result := FileExists(LinkFileName);
	ocCreate:
		begin
			CreateLink(LinkFileName, ExeFileName, '', WorkDir, 0, GetProjectInfo(piFileDescription),
				ExeFileName, 0);
		end;
	ocRemove:
		begin
			if FileExists(LinkFileName) then
				SysUtils.DeleteFile(LinkFileName);
			case GlobalOption of
			goStartMenuIcon:
				RemoveDir(Dir);
			end;
		end;
	end;
end;

procedure SetBackgroundColor(const AComponent: TComponent);
var
	i: SG;
begin
	for i := 0 to AComponent.ComponentCount - 1 do
	begin
		if AComponent.Components[i] is TForm then
		begin
			TForm(AComponent.Components[i]).Color := GetBackgroundWindowColor;
			SetBackgroundColor(AComponent.Components[i]);
		end;
	end;
end;

procedure SetBackgroundInvalidate(const AComponent: TComponent);
var
	i: SG;
begin
	for i := 0 to AComponent.ComponentCount - 1 do
	begin
		if AComponent.Components[i] is TForm then
		begin
			TForm(AComponent.Components[i]).Invalidate;
			SetBackgroundColor(AComponent.Components[i]);
		end;
	end;
end;

procedure OptionChanged(const OptionIndex: SG);
{$if CompilerVersion >= 23}
var
  FileName: TFileName;
{$ifend}
begin
	case TGlobalOption(OptionIndex) of
  goLanguage:
    Dictionary.LanguageIndex := GlobalParams[goLanguage].Num;
	goStartMenuIcon, goDesktopIcon, goQuickLaunchIcon:
		begin
			if GlobalParams[TGlobalOption(OptionIndex)].Bool then
				LinkChange(TGlobalOption(OptionIndex), ocCreate)
			else
				LinkChange(TGlobalOption(OptionIndex), ocRemove);
		end;
	goRunAfterStartUp:
		begin
			if GlobalParams[TGlobalOption(OptionIndex)].Bool then
				RegisterStartup
			else
				UnregisterStartup;
		end;
	goShowSplashScreenWhenApplicationStarts:
		begin
			if GlobalParams[TGlobalOption(OptionIndex)].Bool then
//				ShowSplashScreen(False) Runtime 216 if application closed before splash hide
			else
				HideSplashScreen(True);
		end;
  goMenuItemHeightScale:
  begin
    MenuItemHeightScale := GlobalParams[TGlobalOption(OptionIndex)].Num;
  end;
	goWindowBackgroundTexture:
		begin
			SetBackgroundInvalidate(Application);
	end;
	goWindowBackgroundColor:
		begin
			SetBackgroundColor(Application);
		end;
{$if CompilerVersion >= 23}
  goVisualStyle:
    begin
      FileName := ExpandDir(GlobalParams[TGlobalOption(OptionIndex)].Str);
      if (FileName <> '') and (FileExists(FileName)) then
      begin
        if ExtractFileName(FileName) = 'Windows.vsf' then
          TStyleManager.TrySetStyle('Windows', False)
        else if TStyleManager.IsValidStyle(FileName) then
        begin
          try
            TStyleManager.LoadFromFile(FileName);
          except
            on E: EDuplicateStyleException do ;
          end;
          TStyleManager.TrySetStyle(AddSpace(DelFileExt(ExtractFileName(FileName))), False);
        end
        else
        begin
          TStyleManager.TrySetStyle('Windows', False);
          ErrorMsg('Style %1 is not valid.', [FileName]);
        end;
      end;
    end;
{$ifend}
	end;
end;

procedure RWCommon(const Save: BG);
const
	Section = 'Options';
begin
	// Compatibility
	if Save = False then
	begin
    GlobalOptions[goLanguage].Minimum := -2;
    GlobalOptions[goLanguage].Maximum  := Dictionary.AvailableLanguageCount;
    GlobalOptions[goLanguage].DefaultStr := Dictionary.GetLanguages;
    GlobalOptions[goLanguage].Default  := -2;
{$if CompilerVersion >= 23}
  	GlobalOptions[goVisualStyle].DefaultStr := GetVisualStylesDir;
{$ifend}
		if MainIni.ValueExists(Section, 'ViewSplashScreen') then
		begin
			GlobalOptions[goShowSplashScreenWhenApplicationStarts].Default := MainIni.ReadNum
				(Section, 'ViewSplashScreen', 1);
		end;
		if MainIni.ValueExists(Section, 'AutomaticallyCheckForUpdate') then
		begin
			GlobalOptions[goAutomaticallyCheckForUpdate].Default := MainIni.ReadNum
				(Section, 'AutomaticallyCheckForUpdate', 1);
		end;
	end
	else
	begin
		MainIni.DeleteValue(Section, 'ViewSplashScreen');
		MainIni.DeleteValue(Section, 'AutomaticallyCheckForUpdate');
	end;

	uOptions.RWOptions(POptions(@GlobalOptions), Length(GlobalOptions), PParams(@GlobalParams),
		MainIni, 'Global Options', Save);

{	if Save = False then
		AutomaticallyCheckForUpdate := True;
	MainIni.RWBool(Section, 'AutomaticallyCheckForUpdate', AutomaticallyCheckForUpdate, Save);}
	MainIni.RWDateTime(Section, 'LastUpdate', LastUpdate, Save);

  if Save = False then
  begin
{$if CompilerVersion >= 23}
    OptionChanged(SG(goVisualStyle));
{$ifend}
    OptionChanged(SG(goMenuItemHeightScale));
  end;
end;

initialization

InitOptionNames(TypeInfo(TGlobalOption), GlobalOptions);

if TStartState.RunFromIDE then
  GlobalOptions[goMaxThreads].Maximum := 4; // CreateThread is too slow if run from IDE

GlobalOptions[goMaxThreads].Default := Min(GCPU.LogicalProcessorCount, GlobalOptions[goMaxThreads].Maximum);
DefaultOptions(POptions(@GlobalOptions), Length(GlobalOptions), PParams(@GlobalParams));

end.
