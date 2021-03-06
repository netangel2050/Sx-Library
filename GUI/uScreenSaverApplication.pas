unit uScreenSaverApplication;

interface

uses
  uVCLGUIApplication,
  uTypes,
  uCustomArgument,
  uSwitchArgument,
  uNumericalIntervalArgument,

  SysUtils,
  Windows;

type
  TScreenSaverApplication = class(TVCLGUIApplication)
  private
    FConfigParent: HWND;
    FConfigurationArgument: TNumericalIntervalArgument;
    FStartArgument: TSwitchArgument;
    FPreviewArgument: TNumericalIntervalArgument;
    FSetPasswordArgument: TNumericalIntervalArgument;

    function GetTargetExeFileName: TFileName;
    procedure SetPassword;
    procedure Install;
    procedure Uninstall;
    procedure TryPreview(const AParamHandle: THandle);
  protected
    procedure AddArguments; override;
    procedure OnRun; override;
    procedure Finalize; override;

    procedure Start; virtual; abstract;
    procedure Configure(const AParamHandle: THandle); virtual; abstract;
    procedure FillPreview(const AParamHandle: THandle); virtual; abstract;
  end;

implementation

uses
  Registry,

  uProjectInfo,
  uDictionary,
  uOutputFormat,
  uFiles,
  uSystemPaths,
  uStrings,
  uStopwatch,
  uMainLog,
  uMsg,
  uMsgDlg;

{ TScreenSaverApplication }

procedure TScreenSaverApplication.AddArguments;
begin
  inherited;

  // "Settings" or "Preview" is called before "Small preview" application instance is finished
  // 2 instances are required
  FAllowMultipleInstance.DefaultValue := True;
  FAllowMultipleInstance.Value := True;

  FStartArgument := TSwitchArgument.Create;
  FStartArgument.Shortcut := 's';
  FStartArgument.Description := 'Execute saver';
  FStartArgument.RequireCheck := rcOptional;
  Arguments.Add(FStartArgument);

  FPreviewArgument := TNumericalIntervalArgument.Create;
  FPreviewArgument.Shortcut := 'p';
  FPreviewArgument.Description := 'Preview';
  FPreviewArgument.RequireCheck := rcOptional;
  FPreviewArgument.NumericalInterval.MinimalValue := 1;
  Arguments.Add(FPreviewArgument);

  FConfigurationArgument := TNumericalIntervalArgument.Create;
  FConfigurationArgument.Shortcut := 'c';
  FConfigurationArgument.Description := 'Configuration';
  FConfigurationArgument.RequireCheck := rcOptional;
  FConfigurationArgument.NumericalInterval.MinimalValue := 1;
  Arguments.Add(FConfigurationArgument);

  FSetPasswordArgument := TNumericalIntervalArgument.Create;
  FSetPasswordArgument.Shortcut := 'a';
  FSetPasswordArgument.Description := 'Set password';
  FSetPasswordArgument.RequireCheck := rcOptional;
  FSetPasswordArgument.NumericalInterval.MinimalValue := 1;
  Arguments.Add(FSetPasswordArgument);
end;

procedure TScreenSaverApplication.Finalize;
begin
  try
    FStartArgument.Free;
    FPreviewArgument.Free;
    FConfigurationArgument.Free;
    FSetPasswordArgument.Free;
    if FConfigParent <> 0 then
      SetForegroundWindow(FConfigParent);
  finally
    inherited;
  end;
end;

function TScreenSaverApplication.GetTargetExeFileName: TFileName;
begin
  Result := SystemPaths.SysDir + 'ss' + GetProjectInfo(piInternalName) + '.scr';
end;

procedure TScreenSaverApplication.Install;
var
	TargetExeFileName: TFileName;
	Reg: TRegistry;
begin
  CopyFile(SystemPaths.ExeFileName, GetTargetExeFileName, False);
  CopyDir(SystemPaths.WorkDir + 'Languages\', SystemPaths.SysDir + 'Languages\');
  CopyDir(SystemPaths.WorkDir + 'Sounds\', SystemPaths.SysDir + 'Sounds\');
  CopyDir(SystemPaths.WorkDir + 'Graphics\', SystemPaths.SysDir + 'Graphics\');
  Reg := TRegistry.Create(KEY_SET_VALUE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('Control Panel' + PathDelim + 'Desktop' + PathDelim, False) then
    begin
      Reg.WriteString('SCRNSAVE.EXE', TargetExeFileName);
    end;
  finally
    Reg.Free;
  end;
  Information(GetProjectInfo(piProductName) + CharSpace + Translate('successfully installed.'));
end;

procedure TScreenSaverApplication.OnRun;
begin
  inherited;

  if FStartArgument.Exists then
  begin
  	FConfigParent := GetForegroundWindow;
    Start;
    Exit;
  end;
  if FConfigurationArgument.Exists then
  begin
    Configure(FConfigurationArgument.Value);
    Exit;
  end;
  if FPreviewArgument.Exists then
  begin
    TryPreview(FPreviewArgument.Value);
    Exit;
  end;
  if FSetPasswordArgument.Exists then
  begin
    SetPassword;
    Exit;
  end;

  case MsgDlg('Select next action.', [''], False, mlConfirmation, ['Run', 'Install', 'Uninstall', 'Cancel'], DlgWait) of
  0: Start;
  1: Install;
  2: Uninstall;
  end;
end;

procedure TScreenSaverApplication.SetPassword;
var
	HLib : THandle;
	P: function(a: PChar; ParentHandle: THandle; b, c: Integer): Integer; stdcall;
begin
	HLib := LoadLibrary(PChar(SystemPaths.SysDir + 'MPR.DLL'));
	if HLib <> 0 then begin
		P := GetProcAddress(HLib, 'PwdChangePasswordA');
		if Assigned(P) then
			P('SCRSAVE', FSetPasswordArgument.Value, 0, 0);
		FreeLibrary (HLib);
	end;
end;

procedure TScreenSaverApplication.TryPreview(const AParamHandle: THandle);
begin
  if MainLog.IsLoggerFor(mlDebug) then
    MainLog.LogEnter('TryPreview');
  FillPreview(AParamHandle);
  if MainLog.IsLoggerFor(mlDebug) then
    MainLog.LogLeave('TryPreview');
end;

procedure TScreenSaverApplication.Uninstall;
var
	Res: BG;
begin
  Res := DeleteFileEx(GetTargetExeFileName);
  Res := Res and RemoveDirsEx(SystemPaths.SysDir + 'Sounds\', True);
  Res := Res and RemoveDirsEx(SystemPaths.SysDir + 'Graphics\', True);
  if Res then
    Information(GetProjectInfo(piProductName) + CharSpace + Translate('successfully uninstalled.'));
end;

end.
