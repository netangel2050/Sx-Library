unit uProcessMemory;

interface

uses
  uTypes;

type
  TProcessMemoryCounters = record
    WorkingSetSize: U8;
    PeakWorkingSetSize: U8;

    procedure Add(const AProcessMemoryCounters: TProcessMemoryCounters);
    procedure Update(const AProcessMemoryCounters: TProcessMemoryCounters);
  end;

function GetProcessMemoryCounters(const AHandle: THandle): TProcessMemoryCounters;
function GetProcessMemoryCountersRecursive(const ARootProcessId: U4): TProcessMemoryCounters;

implementation

uses
  SysUtils,

  WinApi.Windows,
  WinApi.PsApi,

  uProcessInfos;

function GetProcessMemoryCounters(const AHandle: THandle): TProcessMemoryCounters;
var
  ProcessMemoryCounters: _PROCESS_MEMORY_COUNTERS;
begin
  ProcessMemoryCounters := Default(_PROCESS_MEMORY_COUNTERS);
  ProcessMemoryCounters.cb := SizeOf(ProcessMemoryCounters);
  if not GetProcessMemoryInfo(AHandle, @ProcessMemoryCounters, ProcessMemoryCounters.cb) then
    RaiseLastOSError;
  Result.WorkingSetSize := ProcessMemoryCounters.WorkingSetSize;
  Result.PeakWorkingSetSize := ProcessMemoryCounters.PeakWorkingSetSize;
end;

function GetProcessMemoryCountersRecursive(const ARootProcessId: U4): TProcessMemoryCounters;
var
  Handle: THandle;
  ProcessInfo: TProcessInfoItem;
begin
  Handle := OpenProcess(PROCESS_QUERY_INFORMATION, False, ARootProcessId);
  if (Handle <> 0) and (Handle <> INVALID_HANDLE_VALUE) then
  begin
    try
      Result := GetProcessMemoryCounters(Handle);
    finally
      CloseHandle(Handle);
    end;
  end
  else
  begin
    // Happen if process already terminated (87 � The parameter is incorrect)
    if GetLastError <> ERROR_INVALID_PARAMETER then
      RaiseLastOSError;
  end;

  for ProcessInfo in ProcessInfos.CompleteList do
  begin
    if ProcessInfo.ParentProcessId = ARootProcessId then
    begin
      Result.Add(GetProcessMemoryCountersRecursive(ProcessInfo.ProcessId));
    end;
  end;
end;

{ TProcessMemoryCounters }

procedure TProcessMemoryCounters.Add(const AProcessMemoryCounters: TProcessMemoryCounters);
begin
  Inc(WorkingSetSize, AProcessMemoryCounters.WorkingSetSize);
  Inc(PeakWorkingSetSize, AProcessMemoryCounters.PeakWorkingSetSize);
end;

procedure TProcessMemoryCounters.Update(const AProcessMemoryCounters: TProcessMemoryCounters);
begin
  WorkingSetSize := AProcessMemoryCounters.WorkingSetSize;
  if AProcessMemoryCounters.PeakWorkingSetSize > PeakWorkingSetSize then
    PeakWorkingSetSize := AProcessMemoryCounters.PeakWorkingSetSize;
end;

end.
