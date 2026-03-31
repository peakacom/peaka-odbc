@echo off
setlocal enabledelayedexpansion

:: ================================================
::   Peaka ODBC Driver - Uninstaller
::   Removes a DSN (system or user) and optionally
::   removes the driver registration.
:: ================================================

:: Admin check
set "IS_ADMIN=0"

:: Use 64-bit PowerShell even if this process is 32-bit (e.g. launched from a 32-bit installer)
set "PSHELL=powershell"
if defined PROCESSOR_ARCHITEW6432 set "PSHELL=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"

cls
echo.
echo  ================================================
echo       Peaka ODBC Driver - Uninstaller
echo  ================================================
echo.
echo   Admin Rights : !IS_ADMIN! ^(1=yes, 0=no^)
echo.

:: ------------------------------------------------
:: Find all Peaka DSNs (System + User)
:: ------------------------------------------------
set "PS_TMP=%TEMP%\_peaka_tmp_uninstall.ps1"
set "PS_OUT=%TEMP%\_peaka_tmp_dsn_list.txt"

>  "!PS_TMP!" echo $results = @()
>> "!PS_TMP!" echo $roots = @(
>> "!PS_TMP!" echo     @{ Label='System (64-bit)'; Path='HKLM:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources' },
>> "!PS_TMP!" echo     @{ Label='System (32-bit)'; Path='HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\ODBC Data Sources' },
>> "!PS_TMP!" echo     @{ Label='User';            Path='HKCU:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources' }
>> "!PS_TMP!" echo )
>> "!PS_TMP!" echo foreach ($r in $roots) {
>> "!PS_TMP!" echo     if (Test-Path $r.Path) {
>> "!PS_TMP!" echo         (Get-ItemProperty $r.Path).PSObject.Properties ^|
>> "!PS_TMP!" echo         Where-Object { $_.Value -like 'Peaka*' -and $_.Name -notlike 'PS*' } ^|
>> "!PS_TMP!" echo         ForEach-Object { $results += "$($r.Label)|$($_.Name)" }
>> "!PS_TMP!" echo     }
>> "!PS_TMP!" echo }
>> "!PS_TMP!" echo $results ^| Out-File '%PS_OUT%' -Encoding ASCII

!PSHELL! -ExecutionPolicy Bypass -File "!PS_TMP!"
del "!PS_TMP!" >nul 2>&1

:: Load results
set "DSN_COUNT=0"
if exist "!PS_OUT!" (
    for /f "usebackq delims=" %%L in ("!PS_OUT!") do (
        set /a DSN_COUNT+=1
        set "DSN_!DSN_COUNT!=%%L"
    )
    del "!PS_OUT!" >nul 2>&1
)

if !DSN_COUNT!==0 (
    echo   No Peaka DSNs found on this machine.
    echo.
    goto :ask_driver
)

:: ------------------------------------------------
:: List and select DSN
:: ------------------------------------------------
echo   Installed Peaka DSNs:
echo.
for /l %%i in (1,1,!DSN_COUNT!) do (
    :: Format: "LABEL|DSN_NAME"
    for /f "tokens=1,2 delims=|" %%A in ("!DSN_%%i!") do (
        echo     [%%i] %%B  ^(%%A^)
    )
)
echo     [0] Skip DSN removal
echo.
set /p "CHOICE=   Select DSN to remove [0]: "

if "!CHOICE!"=="0" goto :ask_driver

set "SEL_LABEL="
set "SEL_DSN="
for /l %%i in (1,1,!DSN_COUNT!) do (
    if "!CHOICE!"=="%%i" (
        for /f "tokens=1,2 delims=|" %%A in ("!DSN_%%i!") do (
            set "SEL_LABEL=%%A"
            set "SEL_DSN=%%B"
        )
    )
)

if "!SEL_DSN!"=="" (
    echo  [ERROR] Invalid selection.
    pause
    exit /b 1
)

:: System DSN requires admin
set "SEL_IS_USER=0"
if "!SEL_LABEL!"=="User" set "SEL_IS_USER=1"
if "!SEL_IS_USER!"=="0" if "!IS_ADMIN!"=="0" (
    echo.
    echo  [ERROR] Removing a system DSN requires Administrator rights.
    echo          Right-click ^> Run as administrator
    echo.
    pause
    exit /b 1
)

echo.
echo   You selected: "!SEL_DSN!"  ^(!SEL_LABEL!^)
set /p "CONFIRM=   Are you sure? (yes/no) [no]: "
if /i not "!CONFIRM!"=="yes" (
    echo   Cancelled.
    goto :ask_driver
)

:: ------------------------------------------------
:: Remove DSN
:: ------------------------------------------------

:: Determine registry path in batch first (avoids conditional blocks inside PS1 generation)
set "ODBC_PS_ROOT=HKLM:\SOFTWARE\ODBC\ODBC.INI"
if "!SEL_IS_USER!"=="1"                    set "ODBC_PS_ROOT=HKCU:\SOFTWARE\ODBC\ODBC.INI"
if "!SEL_LABEL!"=="System (32-bit)"        set "ODBC_PS_ROOT=HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI"

set "PS_TMP=%TEMP%\_peaka_tmp_remove.ps1"

>  "!PS_TMP!" echo $dsn    = '!SEL_DSN!'
>> "!PS_TMP!" echo $root   = '!ODBC_PS_ROOT!'
>> "!PS_TMP!" echo $srcKey = $root + '\ODBC Data Sources'
>> "!PS_TMP!" echo $dsnKey = $root + '\' + $dsn
>> "!PS_TMP!" echo if (Test-Path $srcKey) {
>> "!PS_TMP!" echo     Remove-ItemProperty -Path $srcKey -Name $dsn -ErrorAction SilentlyContinue
>> "!PS_TMP!" echo }
>> "!PS_TMP!" echo if (Test-Path $dsnKey) {
>> "!PS_TMP!" echo     Remove-Item -Path $dsnKey -Recurse -Force
>> "!PS_TMP!" echo     Write-Host "Removed: $dsnKey"
>> "!PS_TMP!" echo } else {
>> "!PS_TMP!" echo     Write-Host "[WARN] Key not found - nothing was removed: $dsnKey"
>> "!PS_TMP!" echo }

!PSHELL! -ExecutionPolicy Bypass -File "!PS_TMP!"
del "!PS_TMP!" >nul 2>&1
echo.

:: ------------------------------------------------
:: Optionally remove driver — detect what is actually installed
:: ------------------------------------------------
:ask_driver
echo   Checking for installed Peaka drivers...

set "PS_TMP=%TEMP%\_peaka_tmp_drvdetect.ps1"
set "PS_OUT=%TEMP%\_peaka_tmp_drv_list.txt"

>  "!PS_TMP!" echo $found = @()
>> "!PS_TMP!" echo $roots = @('HKLM:\SOFTWARE\ODBC\ODBCINST.INI', 'HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI')
>> "!PS_TMP!" echo foreach ($root in $roots) {
>> "!PS_TMP!" echo     $key = $root + '\ODBC Drivers'
>> "!PS_TMP!" echo     if (Test-Path $key) {
>> "!PS_TMP!" echo         (Get-ItemProperty $key).PSObject.Properties ^|
>> "!PS_TMP!" echo         Where-Object { $_.Name -like 'Peaka*' -and $_.Name -notlike 'PS*' } ^|
>> "!PS_TMP!" echo         ForEach-Object { $found += $_.Name }
>> "!PS_TMP!" echo     }
>> "!PS_TMP!" echo }
>> "!PS_TMP!" echo $found ^| Sort-Object -Unique ^| Out-File '%PS_OUT%' -Encoding ASCII

!PSHELL! -ExecutionPolicy Bypass -File "!PS_TMP!"
del "!PS_TMP!" >nul 2>&1

set "DRV_COUNT=0"
if exist "!PS_OUT!" (
    for /f "usebackq delims=" %%L in ("!PS_OUT!") do (
        set /a DRV_COUNT+=1
        set "IDRV_!DRV_COUNT!=%%L"
    )
    del "!PS_OUT!" >nul 2>&1
)

if !DRV_COUNT!==0 (
    echo   No installed Peaka drivers found. Nothing to remove.
    echo.
    goto :done
)

echo.
echo   Installed Peaka drivers:
echo.
for /l %%i in (1,1,!DRV_COUNT!) do (
    echo     [%%i] !IDRV_%%i!
)
echo     [0] Skip
echo.
set /p "DC=   Your choice [0]: "

if "!DC!"=="0" goto :done

if "!IS_ADMIN!"=="0" (
    echo.
    echo  [ERROR] Removing a driver requires Administrator rights.
    echo          Right-click ^> Run as administrator
    echo.
    goto :done
)

set "DRIVER_REGNAME="
for /l %%i in (1,1,!DRV_COUNT!) do (
    if "!DC!"=="%%i" set "DRIVER_REGNAME=!IDRV_%%i!"
)
if "!DRIVER_REGNAME!"=="" (
    echo  [ERROR] Invalid selection.
    goto :done
)

echo.
echo   You selected: "!DRIVER_REGNAME!"
set /p "DCONFIRM=   Are you sure? (yes/no) [no]: "
if /i not "!DCONFIRM!"=="yes" (
    echo   Skipped.
    goto :done
)

set "PS_TMP=%TEMP%\_peaka_tmp_rmdriver.ps1"

>  "!PS_TMP!" echo $drv = '!DRIVER_REGNAME!'
>> "!PS_TMP!" echo $removed = 0
>> "!PS_TMP!" echo $roots = @('HKLM:\SOFTWARE', 'HKLM:\SOFTWARE\Wow6432Node')
>> "!PS_TMP!" echo foreach ($root in $roots) {
>> "!PS_TMP!" echo     $key = "$root\ODBC\ODBCINST.INI\ODBC Drivers"
>> "!PS_TMP!" echo     if (Test-Path $key) { Remove-ItemProperty $key -Name $drv -ErrorAction SilentlyContinue }
>> "!PS_TMP!" echo     $drvKey = "$root\ODBC\ODBCINST.INI\$drv"
>> "!PS_TMP!" echo     if (Test-Path $drvKey) { Remove-Item $drvKey -Recurse -Force; $removed++; Write-Host "Removed: $drvKey" }
>> "!PS_TMP!" echo     $vendKey = "$root\Peaka\$drv"
>> "!PS_TMP!" echo     if (Test-Path $vendKey) { Remove-Item $vendKey -Recurse -Force; Write-Host "Removed: $vendKey" }
>> "!PS_TMP!" echo }
>> "!PS_TMP!" echo if ($removed -eq 0) { Write-Host "[WARN] No registry keys were found to remove." }

!PSHELL! -ExecutionPolicy Bypass -File "!PS_TMP!"
del "!PS_TMP!" >nul 2>&1
echo   Driver "!DRIVER_REGNAME!" removed.

:: ------------------------------------------------
:: Final cleanup: offer to remove any remaining Peaka DSNs
:: ------------------------------------------------
:cleanup_check
set "PS_TMP=%TEMP%\_peaka_tmp_final_detect.ps1"
set "PS_OUT=%TEMP%\_peaka_tmp_final_dsns.txt"

>  "!PS_TMP!" echo $results = @()
>> "!PS_TMP!" echo $roots = @(
>> "!PS_TMP!" echo     @{ Label='System (64-bit)'; Path='HKLM:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources' },
>> "!PS_TMP!" echo     @{ Label='System (32-bit)'; Path='HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\ODBC Data Sources' },
>> "!PS_TMP!" echo     @{ Label='User';            Path='HKCU:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources' }
>> "!PS_TMP!" echo )
>> "!PS_TMP!" echo foreach ($r in $roots) {
>> "!PS_TMP!" echo     if (Test-Path $r.Path) {
>> "!PS_TMP!" echo         (Get-ItemProperty $r.Path).PSObject.Properties ^|
>> "!PS_TMP!" echo         Where-Object { $_.Value -like 'Peaka*' -and $_.Name -notlike 'PS*' } ^|
>> "!PS_TMP!" echo         ForEach-Object { $results += "$($r.Label)|$($_.Name)" }
>> "!PS_TMP!" echo     }
>> "!PS_TMP!" echo }
>> "!PS_TMP!" echo $results ^| Out-File '%PS_OUT%' -Encoding ASCII

!PSHELL! -ExecutionPolicy Bypass -File "!PS_TMP!"
del "!PS_TMP!" >nul 2>&1

set "REM_COUNT=0"
if exist "!PS_OUT!" (
    for /f "usebackq delims=" %%L in ("!PS_OUT!") do (
        set /a REM_COUNT+=1
        set "REM_!REM_COUNT!=%%L"
    )
    del "!PS_OUT!" >nul 2>&1
)

if !REM_COUNT!==0 goto :done

echo.
echo   The following Peaka DSNs are still registered:
echo.
for /l %%i in (1,1,!REM_COUNT!) do (
    for /f "tokens=1,2 delims=|" %%A in ("!REM_%%i!") do (
        echo     - %%B  ^(%%A^)
    )
)
echo.
set "REMOVE_ALL=no"
set /p "REMOVE_ALL=   Remove all remaining Peaka DSNs? (yes/no) [no]: "
if /i not "!REMOVE_ALL!"=="yes" goto :done

set "PS_TMP=%TEMP%\_peaka_tmp_cleanup_all.ps1"
>  "!PS_TMP!" echo $dsnRoots = @(
>> "!PS_TMP!" echo     @{ Root='HKLM:\SOFTWARE\ODBC\ODBC.INI';             Src='HKLM:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources' },
>> "!PS_TMP!" echo     @{ Root='HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI'; Src='HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\ODBC Data Sources' },
>> "!PS_TMP!" echo     @{ Root='HKCU:\SOFTWARE\ODBC\ODBC.INI';             Src='HKCU:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources' }
>> "!PS_TMP!" echo )
>> "!PS_TMP!" echo foreach ($r in $dsnRoots) {
>> "!PS_TMP!" echo     if (-not (Test-Path $r.Src)) { continue }
>> "!PS_TMP!" echo     $names = (Get-ItemProperty $r.Src).PSObject.Properties ^|
>> "!PS_TMP!" echo         Where-Object { $_.Value -like 'Peaka*' -and $_.Name -notlike 'PS*' } ^|
>> "!PS_TMP!" echo         Select-Object -ExpandProperty Name
>> "!PS_TMP!" echo     foreach ($name in $names) {
>> "!PS_TMP!" echo         Remove-ItemProperty -Path $r.Src -Name $name -ErrorAction SilentlyContinue
>> "!PS_TMP!" echo         $dsnKey = $r.Root + '\' + $name
>> "!PS_TMP!" echo         if (Test-Path $dsnKey) { Remove-Item -Path $dsnKey -Recurse -Force }
>> "!PS_TMP!" echo         Write-Host "Removed DSN: $name"
>> "!PS_TMP!" echo     }
>> "!PS_TMP!" echo }

!PSHELL! -ExecutionPolicy Bypass -File "!PS_TMP!"
del "!PS_TMP!" >nul 2>&1
echo.

:done
echo.
echo  ================================================
echo   Done. Please close and reopen ODBC Administrator.
echo  ================================================
echo.
pause
