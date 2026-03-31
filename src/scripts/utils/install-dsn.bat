@echo off
setlocal enabledelayedexpansion

:: ================================================
::   Peaka ODBC Driver - DSN Installer
::   Creates a named DSN pointing to an installed driver.
::   Can be run multiple times for different DSNs.
::   Does NOT require admin if scope = User.
::   Writes registry directly — no .reg file generated.
:: ================================================

:: Detect admin rights
set "IS_ADMIN=0"

:: Use 64-bit PowerShell even if this process is 32-bit (e.g. launched from a 32-bit installer)
set "PSHELL=powershell"
if defined PROCESSOR_ARCHITEW6432 set "PSHELL=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"

:: Detect OS architecture
set "OS_BIT=32"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "OS_BIT=64"
if defined PROCESSOR_ARCHITEW6432 set "OS_BIT=64"

cls
echo.
echo  ================================================
echo       Peaka ODBC Driver - DSN Installer
echo  ================================================
echo.
echo   Admin Rights : !IS_ADMIN! ^(1=yes, 0=no^)
echo.

:: ------------------------------------------------
:: 1. Scope: System-wide or User
:: ------------------------------------------------
echo   DSN Scope:
echo     [1] System-wide  ^(all users, requires Admin^)
echo     [2] Current user only  ^(no Admin needed^)
echo.
set /p "SC=   Your choice [1]: "
set "SCOPE=SYSTEM"
set "HKEYROOT=HKEY_LOCAL_MACHINE"
set "PS_HKEYROOT=HKLM:"
if "!SC!"=="2" (
    set "SCOPE=USER"
    set "HKEYROOT=HKEY_CURRENT_USER"
    set "PS_HKEYROOT=HKCU:"
)

:: System-wide requires admin
if "!SCOPE!"=="SYSTEM" if "!IS_ADMIN!"=="0" (
    echo.
    echo  [ERROR] System-wide DSN requires Administrator rights.
    echo          Right-click ^> Run as administrator
    echo.
    pause
    exit /b 1
)
echo.

:: ------------------------------------------------
:: 2. Auto-detect installed Peaka drivers
:: ------------------------------------------------
set "PS_TMP=%TEMP%\_peaka_tmp_detect.ps1"
set "PS_OUT=%TEMP%\_peaka_tmp_drivers.txt"

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
        set "DRV_!DRV_COUNT!=%%L"
    )
    del "!PS_OUT!" >nul 2>&1
)

if !DRV_COUNT!==0 (
    echo  [ERROR] No Peaka drivers found on this machine.
    echo          Please run install-driver.bat first.
    echo.
    pause
    exit /b 1
)

if "!DRV_COUNT!"=="1" (
    set "DRIVER_REGNAME=!DRV_1!"
    echo   Driver: !DRIVER_REGNAME!  ^(auto-selected^)
    echo.
) else (
    echo   Installed Peaka drivers:
    for /l %%i in (1,1,!DRV_COUNT!) do echo     [%%i] !DRV_%%i!
    echo.
    set /p "DRC=   Select driver [1]: "
    set "DRIVER_REGNAME=!DRV_1!"
    for /l %%i in (1,1,!DRV_COUNT!) do (
        if "!DRC!"=="%%i" set "DRIVER_REGNAME=!DRV_%%i!"
    )
    echo.
)

:: ------------------------------------------------
:: 3. DSN name
:: ------------------------------------------------
echo   DSN name  ^(visible in ODBC Administrator^):
echo.
set "DSN_NAME=Peaka"
set /p "DN=   DSN Name [Peaka]: "
if not "!DN!"=="" set "DSN_NAME=!DN!"
echo.

:: Check if DSN already exists
set "ODBC_PS_ROOT=!PS_HKEYROOT!\SOFTWARE\ODBC\ODBC.INI"
if "!SCOPE!"=="SYSTEM" if "%OS_BIT%"=="64" if "!DRIVER_REGNAME!"=="Peaka ODBC Driver 32" (
    set "ODBC_PS_ROOT=HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI"
)

!PSHELL! -ExecutionPolicy Bypass -Command "if (Test-Path '!ODBC_PS_ROOT!\!DSN_NAME!') { exit 0 } else { exit 1 }" >nul 2>&1
if not errorlevel 1 (
    echo   [INFO] DSN "!DSN_NAME!" already exists.
    set /p "OVERWRITE=   Overwrite? (yes/no) [no]: "
    if /i not "!OVERWRITE!"=="yes" (
        echo   Cancelled.
        pause
        exit /b 0
    )
    echo.
)

:: ------------------------------------------------
:: 4. Zone
:: ------------------------------------------------
echo   Zone:
echo     [1] US  ^(default^)
echo     [2] EU
echo.
set /p "ZC=   Your choice [1]: "
set "DEFAULT_HOST=dbc.peaka.studio"
if "!ZC!"=="2" set "DEFAULT_HOST=dbc.eu.peaka.studio"
echo.

:: ------------------------------------------------
:: 5. Host
:: ------------------------------------------------
set "HOST=!DEFAULT_HOST!"
set /p "HI=   Host [!DEFAULT_HOST!]: "
if not "!HI!"=="" set "HOST=!HI!"
echo.

:: ------------------------------------------------
:: 6. Port
:: ------------------------------------------------
set "PORT=4567"
set /p "PI=   Port [4567]: "
if not "!PI!"=="" set "PORT=!PI!"
echo.

:: ------------------------------------------------
:: Summary
:: ------------------------------------------------
echo  ================================================
echo   Scope       : !SCOPE!
echo   Driver      : !DRIVER_REGNAME!
echo   DSN Name    : !DSN_NAME!
echo   Host        : !HOST!
echo   Port        : !PORT!
echo  ================================================
echo.

:: ------------------------------------------------
:: Write DSN directly to registry via PowerShell
:: (no .reg file generated — we already have the rights)
:: ------------------------------------------------
set "PS_TMP=%TEMP%\_peaka_tmp_dsn.ps1"

>  "!PS_TMP!" echo $dsnName  = '!DSN_NAME!'
>> "!PS_TMP!" echo $drvName  = '!DRIVER_REGNAME!'
>> "!PS_TMP!" echo $host_    = '!HOST!'
>> "!PS_TMP!" echo $port_    = '!PORT!'
>> "!PS_TMP!" echo $odbcRoot = '!ODBC_PS_ROOT!'
>> "!PS_TMP!" echo.
>> "!PS_TMP!" echo $srcKey = $odbcRoot + '\ODBC Data Sources'
>> "!PS_TMP!" echo if (-not ^(Test-Path $srcKey^)) { New-Item -Path $srcKey -Force ^| Out-Null }
>> "!PS_TMP!" echo Set-ItemProperty -Path $srcKey -Name $dsnName -Value $drvName
>> "!PS_TMP!" echo.
>> "!PS_TMP!" echo $dsnKey = $odbcRoot + '\' + $dsnName
>> "!PS_TMP!" echo New-Item -Path $dsnKey -Force ^| Out-Null
>> "!PS_TMP!" echo Set-ItemProperty -Path $dsnKey -Name 'Driver'             -Value $drvName
>> "!PS_TMP!" echo Set-ItemProperty -Path $dsnKey -Name 'Description'        -Value 'Peaka DSN'
>> "!PS_TMP!" echo Set-ItemProperty -Path $dsnKey -Name 'AuthenticationType' -Value 'No Authentication'
>> "!PS_TMP!" echo Set-ItemProperty -Path $dsnKey -Name 'Host'               -Value $host_
>> "!PS_TMP!" echo Set-ItemProperty -Path $dsnKey -Name 'Port'               -Value $port_
>> "!PS_TMP!" echo Write-Host "DSN registered: $dsnName -> $drvName @ ${host_}:${port_}"

!PSHELL! -ExecutionPolicy Bypass -File "!PS_TMP!"
set "PS_ERR=!errorlevel!"
del "!PS_TMP!" >nul 2>&1

echo.
if "!PS_ERR!"=="0" (
    echo  ================================================
    echo   DSN "!DSN_NAME!" created successfully.
    echo   Scope: !SCOPE!
    echo   Please close and reopen ODBC Administrator.
    echo  ================================================
) else (
    echo  [ERROR] PowerShell script failed ^(exit code !PS_ERR!^).
    echo          DSN may not have been created correctly.
)
echo.
pause
