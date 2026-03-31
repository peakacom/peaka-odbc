@echo off
setlocal enabledelayedexpansion

:: Use 64-bit PowerShell even if this process is 32-bit (e.g. launched from a 32-bit installer)
set "PSHELL=powershell"
if defined PROCESSOR_ARCHITEW6432 set "PSHELL=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"

:: ================================================
::   Peaka ODBC Driver - List Installed DSNs
:: ================================================

cls
echo.
echo  ================================================
echo       Peaka ODBC Driver - Installed DSNs
echo  ================================================
echo.

set "PS_TMP=%TEMP%\_peaka_tmp_list.ps1"
set "PS_OUT=%TEMP%\_peaka_tmp_list_out.txt"

>  "!PS_TMP!" echo $q = [char]34
>> "!PS_TMP!" echo $results = @()
>> "!PS_TMP!" echo.
>> "!PS_TMP!" echo # --- Installed Drivers ---
>> "!PS_TMP!" echo $driverRoots = @(
>> "!PS_TMP!" echo     @{ Label='64-bit'; Path='HKLM:\SOFTWARE\ODBC\ODBCINST.INI' },
>> "!PS_TMP!" echo     @{ Label='32-bit'; Path='HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI' }
>> "!PS_TMP!" echo )
>> "!PS_TMP!" echo $results += "INSTALLED DRIVERS"
>> "!PS_TMP!" echo $results += "--------------------------------------------"
>> "!PS_TMP!" echo foreach ($r in $driverRoots) {
>> "!PS_TMP!" echo     $driversKey = $r.Path + '\ODBC Drivers'
>> "!PS_TMP!" echo     if (Test-Path $driversKey) {
>> "!PS_TMP!" echo         $props = Get-ItemProperty $driversKey
>> "!PS_TMP!" echo         $props.PSObject.Properties ^| Where-Object { $_.Name -like 'Peaka*' -and $_.Name -notlike 'PS*' } ^| ForEach-Object {
>> "!PS_TMP!" echo             $drvKey = $r.Path + '\' + $_.Name
>> "!PS_TMP!" echo             $dllPath = if (Test-Path $drvKey) { (Get-ItemProperty $drvKey).Driver } else { 'n/a' }
>> "!PS_TMP!" echo             $results += "  [$($r.Label)]  $($_.Name)"
>> "!PS_TMP!" echo             $results += "           DLL : $dllPath"
>> "!PS_TMP!" echo         }
>> "!PS_TMP!" echo     }
>> "!PS_TMP!" echo }
>> "!PS_TMP!" echo $results += ""
>> "!PS_TMP!" echo.
>> "!PS_TMP!" echo # --- Installed DSNs ---
>> "!PS_TMP!" echo $dsnRoots = @(
>> "!PS_TMP!" echo     @{ Label='System (64-bit)'; Path='HKLM:\SOFTWARE\ODBC\ODBC.INI' },
>> "!PS_TMP!" echo     @{ Label='System (32-bit)'; Path='HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI' }
>> "!PS_TMP!" echo )
>> "!PS_TMP!" echo $results += "INSTALLED DSNs"
>> "!PS_TMP!" echo $results += "--------------------------------------------"
>> "!PS_TMP!" echo foreach ($r in $dsnRoots) {
>> "!PS_TMP!" echo     $sourcesKey = $r.Path + '\ODBC Data Sources'
>> "!PS_TMP!" echo     if (Test-Path $sourcesKey) {
>> "!PS_TMP!" echo         $props = Get-ItemProperty $sourcesKey
>> "!PS_TMP!" echo         $props.PSObject.Properties ^| Where-Object { $_.Value -like 'Peaka*' -and $_.Name -notlike 'PS*' } ^| ForEach-Object {
>> "!PS_TMP!" echo             $dsnKey = $r.Path + '\' + $_.Name
>> "!PS_TMP!" echo             $host_ = if (Test-Path $dsnKey) { (Get-ItemProperty $dsnKey -ErrorAction SilentlyContinue).Host } else { 'n/a' }
>> "!PS_TMP!" echo             $port_ = if (Test-Path $dsnKey) { (Get-ItemProperty $dsnKey -ErrorAction SilentlyContinue).Port } else { 'n/a' }
>> "!PS_TMP!" echo             $driver_ = if (Test-Path $dsnKey) { (Get-ItemProperty $dsnKey -ErrorAction SilentlyContinue).Driver } else { 'n/a' }
>> "!PS_TMP!" echo             $results += "  [$($r.Label)]  DSN: $($_.Name)"
>> "!PS_TMP!" echo             $results += "           Driver : $driver_"
>> "!PS_TMP!" echo             $results += "           Host   : $host_"
>> "!PS_TMP!" echo             $results += "           Port   : $port_"
>> "!PS_TMP!" echo         }
>> "!PS_TMP!" echo     }
>> "!PS_TMP!" echo }
>> "!PS_TMP!" echo.
>> "!PS_TMP!" echo $results ^| Out-File -FilePath '%PS_OUT%' -Encoding ASCII

!PSHELL! -ExecutionPolicy Bypass -File "!PS_TMP!"
del "!PS_TMP!" >nul 2>&1

if exist "!PS_OUT!" (
    type "!PS_OUT!"
    del "!PS_OUT!" >nul 2>&1
) else (
    echo   Could not read registry.
)

echo.
echo  ================================================
echo.
pause
