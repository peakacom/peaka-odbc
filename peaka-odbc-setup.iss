; ================================================
;  Peaka ODBC Driver — Inno Setup 6 Script
;  Run: ISCC.exe peaka-odbc-setup.iss
; ================================================

[Setup]
AppName=Peaka ODBC Driver
AppVersion=2.3.9.1001
AppPublisher=Peaka
AppPublisherURL=https://peaka.com
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
DefaultDirName={autopf}\Peaka\ODBC
DefaultGroupName=Peaka ODBC
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
Compression=lzma2
SolidCompression=yes
OutputBaseFilename=PeakaODBC_Setup_2.3.9.1001
OutputDir=.\dist
WizardStyle=modern
SetupLogging=yes
UninstallDisplayName=Peaka ODBC Driver

; ================================================
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; ================================================
[Tasks]
Name: "powerbi"; Description: "Install Power BI Desktop connector (peaka.mez)"; GroupDescription: "Additional components:"; Flags: unchecked

; ================================================
[Files]
Source: "driver\SimbatrinoODBC64_2.3.9.1001\*"; DestDir: "{app}\driver\SimbatrinoODBC64_2.3.9.1001"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "driver\SimbatrinoODBC32_2.3.9.1001\*"; DestDir: "{app}\driver\SimbatrinoODBC32_2.3.9.1001"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "tools\*"; DestDir: "{app}\tools"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "install.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "custom\powerbi\peaka.mez"; DestDir: "{userdocs}\Power BI Desktop\Custom Connectors"; Flags: ignoreversion; Tasks: powerbi

; ================================================
[Registry]

; --- 32-bit driver (HKLM\SOFTWARE\Wow6432Node\ODBC — 32-bit hive) ---
Root: HKLM; Subkey: "SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\ODBC Drivers"; ValueType: string; ValueName: "Peaka ODBC Driver 32"; ValueData: "Installed"; Flags: uninsdeletevalue
Root: HKLM; Subkey: "SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\Peaka ODBC Driver 32"; ValueType: string; ValueName: "Description"; ValueData: "Peaka ODBC Driver 32"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\Peaka ODBC Driver 32"; ValueType: string; ValueName: "Driver"; ValueData: "{app}\driver\SimbatrinoODBC32_2.3.9.1001\lib\TrinoODBC_sb32.dll"
Root: HKLM; Subkey: "SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\Peaka ODBC Driver 32"; ValueType: string; ValueName: "Setup"; ValueData: "{app}\driver\SimbatrinoODBC32_2.3.9.1001\lib\TrinoODBC_sb32.dll"
Root: HKLM; Subkey: "SOFTWARE\Wow6432Node\Peaka\Peaka ODBC Driver 32\Driver"; ValueType: string; ValueName: "DriverManagerEncoding"; ValueData: "UTF-16"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Wow6432Node\Peaka\Peaka ODBC Driver 32\Driver"; ValueType: string; ValueName: "ErrorMessagesPath"; ValueData: "{app}\driver\SimbatrinoODBC32_2.3.9.1001\ErrorMessages"
Root: HKLM; Subkey: "SOFTWARE\Wow6432Node\Peaka\Peaka ODBC Driver 32\Driver"; ValueType: string; ValueName: "LogLevel"; ValueData: "0"
Root: HKLM; Subkey: "SOFTWARE\Wow6432Node\Peaka\Peaka ODBC Driver 32\Driver"; ValueType: string; ValueName: "LogNamespace"; ValueData: ""
Root: HKLM; Subkey: "SOFTWARE\Wow6432Node\Peaka\Peaka ODBC Driver 32\Driver"; ValueType: string; ValueName: "LogPath"; ValueData: ""

; ================================================
[Run]

; --- Register 64-bit driver explicitly in 64-bit registry hive via reg.exe /reg:64 ---
Filename: "reg.exe"; Parameters: "add ""HKLM\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers"" /v ""Peaka ODBC Driver"" /d ""Installed"" /f /reg:64"; Flags: runhidden waituntilterminated
Filename: "reg.exe"; Parameters: "add ""HKLM\SOFTWARE\ODBC\ODBCINST.INI\Peaka ODBC Driver"" /v ""Description"" /d ""Peaka ODBC Driver"" /f /reg:64"; Flags: runhidden waituntilterminated
Filename: "reg.exe"; Parameters: "add ""HKLM\SOFTWARE\ODBC\ODBCINST.INI\Peaka ODBC Driver"" /v ""Driver"" /d ""{app}\driver\SimbatrinoODBC64_2.3.9.1001\lib\TrinoODBC_sb64.dll"" /f /reg:64"; Flags: runhidden waituntilterminated
Filename: "reg.exe"; Parameters: "add ""HKLM\SOFTWARE\ODBC\ODBCINST.INI\Peaka ODBC Driver"" /v ""Setup"" /d ""{app}\driver\SimbatrinoODBC64_2.3.9.1001\lib\TrinoODBC_sb64.dll"" /f /reg:64"; Flags: runhidden waituntilterminated
Filename: "reg.exe"; Parameters: "add ""HKLM\SOFTWARE\Peaka\Peaka ODBC Driver\Driver"" /v ""DriverManagerEncoding"" /d ""UTF-16"" /f /reg:64"; Flags: runhidden waituntilterminated
Filename: "reg.exe"; Parameters: "add ""HKLM\SOFTWARE\Peaka\Peaka ODBC Driver\Driver"" /v ""ErrorMessagesPath"" /d ""{app}\driver\SimbatrinoODBC64_2.3.9.1001\ErrorMessages"" /f /reg:64"; Flags: runhidden waituntilterminated
Filename: "reg.exe"; Parameters: "add ""HKLM\SOFTWARE\Peaka\Peaka ODBC Driver\Driver"" /v ""LogLevel"" /d ""0"" /f /reg:64"; Flags: runhidden waituntilterminated
Filename: "reg.exe"; Parameters: "add ""HKLM\SOFTWARE\Peaka\Peaka ODBC Driver\Driver"" /v ""LogNamespace"" /d """" /f /reg:64"; Flags: runhidden waituntilterminated
Filename: "reg.exe"; Parameters: "add ""HKLM\SOFTWARE\Peaka\Peaka ODBC Driver\Driver"" /v ""LogPath"" /d """" /f /reg:64"; Flags: runhidden waituntilterminated

; --- Optional: create a DSN after installation ---
; shellexec + Verb runas = fresh UAC prompt so both System and User DSN options are available
Filename: "{app}\tools\install-dsn.bat"; Verb: "runas"; Description: "Create a DSN (connection) now"; Flags: postinstall shellexec skipifsilent; WorkingDir: "{app}"

; ================================================
[Code]

procedure InitializeWizard;
begin
  WizardForm.WelcomeLabel2.Caption :=
    'This will install the Peaka ODBC Driver (v2.3.9.1001) on your computer.' + #13#10 + #13#10 +
    'The driver registration requires Administrator rights.' + #13#10 + #13#10 +
    'Note: this installer is not digitally signed. ' +
    'If Windows SmartScreen shows a warning, click "More info" then "Run anyway".';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  PS1File, PSContent: String;
  ResultCode: Integer;
  MezFile: String;
begin
  if CurUninstallStep = usUninstall then begin

    // Ask about DSN removal before files are deleted
    if MsgBox(
      'Do you also want to remove all Peaka DSNs?' + #13#10 + #13#10 +
      'This will delete all Peaka DSN entries from ODBC Administrator ' +
      '(System and User, all scopes).' + #13#10 + #13#10 +
      'Select No to keep them.',
      mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
    begin
      PS1File := ExpandConstant('{tmp}') + '\_peaka_uninst_dsn.ps1';
      PSContent :=
        '$roots = @(' + #13#10 +
        '  @{ Root=''HKLM:\SOFTWARE\ODBC\ODBC.INI'';                    Src=''HKLM:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources'' },' + #13#10 +
        '  @{ Root=''HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI'';        Src=''HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\ODBC Data Sources'' },' + #13#10 +
        '  @{ Root=''HKCU:\SOFTWARE\ODBC\ODBC.INI'';                    Src=''HKCU:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources'' }' + #13#10 +
        ')' + #13#10 +
        'foreach ($r in $roots) {' + #13#10 +
        '  if (-not (Test-Path $r.Src)) { continue }' + #13#10 +
        '  $names = (Get-ItemProperty $r.Src).PSObject.Properties |' + #13#10 +
        '    Where-Object { $_.Value -like ''Peaka*'' -and $_.Name -notlike ''PS*'' } |' + #13#10 +
        '    Select-Object -ExpandProperty Name' + #13#10 +
        '  foreach ($name in $names) {' + #13#10 +
        '    Remove-ItemProperty -Path $r.Src -Name $name -ErrorAction SilentlyContinue' + #13#10 +
        '    $k = $r.Root + ''\'' + $name' + #13#10 +
        '    if (Test-Path $k) { Remove-Item -Path $k -Recurse -Force }' + #13#10 +
        '  }' + #13#10 +
        '}';
      SaveStringToFile(PS1File, PSContent, False);
      Exec('powershell.exe',
           '-ExecutionPolicy Bypass -File "' + PS1File + '"',
           '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      DeleteFile(PS1File);
    end;

  end;

  if CurUninstallStep = usPostUninstall then begin
    // Remove 64-bit driver entries written by reg.exe /reg:64
    RegDeleteValue(HKLM, 'SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers', 'Peaka ODBC Driver');
    RegDeleteKeyIncludingSubkeys(HKLM, 'SOFTWARE\ODBC\ODBCINST.INI\Peaka ODBC Driver');
    RegDeleteKeyIncludingSubkeys(HKLM, 'SOFTWARE\Peaka\Peaka ODBC Driver');

    // Remove Power BI connector if it was installed
    MezFile := ExpandConstant('{userdocs}') + '\Power BI Desktop\Custom Connectors\peaka.mez';
    if FileExists(MezFile) then
      DeleteFile(MezFile);
  end;

end;
