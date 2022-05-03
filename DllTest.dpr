program DllTest;
{$IFOPT D-}{$WEAKLINKRTTI ON}{$ENDIF}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}
{$R *.res}

uses
  Windows, System.SysUtils, JwaWinType, JwaNtStatus, JwaPsApi, JwaNative;

const
  IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE = $0040;
  IMAGE_DLLCHARACTERISTICS_NX_COMPAT    = $0100;

{$DYNAMICBASE ON} // prereq for ASLR / NX
{$SetPEOptFlags IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE or
  IMAGE_DLLCHARACTERISTICS_NX_COMPAT or IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE or
  IMAGE_FILE_RELOCS_STRIPPED}


function GetDosPath(const NtPath: String): String;
var
  nts: NTSTATUS;
  us: UNICODE_STRING;
  oa: OBJECT_ATTRIBUTES;
  hFile: THandle;
  iosb: IO_STATUS_BLOCK;
begin
  RtlInitUnicodeString(@us, PChar(NtPath));
  InitializeObjectAttributes(@oa, @us, OBJ_CASE_INSENSITIVE, 0, nil);
  nts := NtCreateFile(@hFile, SYNCHRONIZE, @oa, @iosb, nil,
    FILE_ATTRIBUTE_READONLY, FILE_SHARE_READ or FILE_SHARE_WRITE or
    FILE_SHARE_DELETE, FILE_OPEN_IF, 0, nil, 0);
  if (nts = STATUS_SUCCESS) and (hFile > 0) then
  begin
    SetLength(Result, MAX_PATH+1);
 {$WARN SYMBOL_PLATFORM OFF}
    SetLength(Result, GetFinalPathNameByHandle(hFile, PChar(Result),
      Length(Result), VOLUME_NAME_DOS));
 {$WARN SYMBOL_PLATFORM ON}
    Result := Result.Replace('\\?\', '');
    NtClose(hFile);
  end
  else begin
    Result := NtPath;
  end;

  RtlFreeUnicodeString(@us);
end;

procedure PrintProcessModules(const hProcess: THandle);
var
  hModules: array[0..1023] of HMODULE;
  NtPath: String;
  cbNeeded: DWORD;
  i: Integer;
begin
  ZeroMemory(@hModules[0], SizeOf(hModules));
  if (EnumProcessModules(hProcess, @hModules[0], SizeOf(hModules), cbNeeded)) then
  begin
    // skip 0 as it will be main module...
    for i := 1 to cbNeeded div SizeOf(HMODULE)-1 do
    begin
      SetLength(NtPath, MAX_PATH+1);
      SetLength(NtPath, GetMappedFilename(hProcess, Pointer(hModules[i]),
        PChar(NtPath), Length(NtPath)));
      if Length(NtPath) > 0 then
        WriteLn(GetDosPath(NtPath));
    end;
  end;
end;

var
  hProcess: THandle;
  dwPid: DWORD;
begin
  // first param is pid, if invalid take CURRENT PROCESS PSEUDO HANDLE
  dwPid := StrToIntDef(ParamStr(1), 0);
  if dwPid > 0 then
  begin
    hProcess := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ,
      False, dwPid);

    if hProcess = 0 then
    begin
      WriteLn(Format('OpenProcess for pid %d failed with %d',
        [dwPid, GetLastError]));
      Exit;
    end
  end
  else begin
    hProcess := GetCurrentProcess;
  end;

  PrintProcessModules(hProcess);
  if hProcess > 0 then
    CloseHandle(hProcess);
end.
