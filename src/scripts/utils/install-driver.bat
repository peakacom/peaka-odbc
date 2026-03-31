@echo off
setlocal enabledelayedexpansion

:: ================================================
::   Peaka ODBC Driver - Driver Installer
::   Registers the driver DLL in ODBCINST.INI.
::   Run once per machine (or per driver bit).
:: ================================================

:: Detect script directory (bin\utils\) and root dir (two levels up)
set "SCRIPT_DIR=%~dp0"
if "!SCRIPT_DIR:~-1!"=="\" set "SCRIPT_DIR=!SCRIPT_DIR:~0,-1!"
for %%F in ("!SCRIPT_DIR!\..\..") do set "ROOT_DIR=%%~fF"

:: Check admin rights
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
echo       Peaka ODBC Driver - Driver Installer
echo  ================================================
echo.
echo   Operating System : %OS_BIT%-bit
if "!IS_ADMIN!"=="0" (
    echo   Admin Rights     : NO
    echo   ^> Registry will NOT be applied automatically.
    echo     A .reg file will be generated for manual use.
) else (
    echo   Admin Rights     : YES
)
echo.

:: ------------------------------------------------
:: 1. Driver architecture
:: ------------------------------------------------
set "DRIVER_BIT=64"
if "%OS_BIT%"=="32" (
    set "DRIVER_BIT=32"
    echo   Driver           : 32-bit
    echo.
    goto :arch_done
)
echo   Driver architecture:
echo     [1] 64-bit  ^(default^)
echo     [2] 32-bit
echo.
set "DC=1"
set /p "DC=   Your choice [1]: "
if "!DC!"=="2" set "DRIVER_BIT=32"
echo.

:arch_done
set "DRIVER_REGNAME=Peaka ODBC Driver"
if "!DRIVER_BIT!"=="32" set "DRIVER_REGNAME=Peaka ODBC Driver 32"

:: ------------------------------------------------
:: Registry root paths (PowerShell format)
:: ------------------------------------------------
set "ODBCINST_PS_ROOT=HKLM:\SOFTWARE\ODBC\ODBCINST.INI"
set "VENDOR_PS_ROOT=HKLM:\SOFTWARE\Peaka"
if "%OS_BIT%"=="64" if "!DRIVER_BIT!"=="32" (
    set "ODBCINST_PS_ROOT=HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI"
    set "VENDOR_PS_ROOT=HKLM:\SOFTWARE\Wow6432Node\Peaka"
)

:: ------------------------------------------------
:: Check if driver already registered
:: ------------------------------------------------
!PSHELL! -ExecutionPolicy Bypass -Command "if (Test-Path '!ODBCINST_PS_ROOT!\!DRIVER_REGNAME!') { exit 0 } else { exit 1 }" >nul 2>&1
if not errorlevel 1 (
    echo   [INFO] "!DRIVER_REGNAME!" is already registered.
    echo.
    set "REINSTALL=no"
    set /p "REINSTALL=   Reinstall anyway? (yes/no) [no]: "
    if /i not "!REINSTALL!"=="yes" (
        echo   Skipped.
        echo.
        goto :end_driver
    )
    echo.
)

:: ------------------------------------------------
:: Prepare paths
:: ------------------------------------------------
set "INSTALLDIR_SINGLE=!ROOT_DIR!\driver\SimbatrinoODBC!DRIVER_BIT!_2.3.9.1001"
set "ROOT_DOUBLE=!ROOT_DIR:\=\\!"
set "INSTALLDIR_DOUBLE=!ROOT_DOUBLE!\\driver\\SimbatrinoODBC!DRIVER_BIT!_2.3.9.1001"
set "DLL_NAME=TrinoODBC_sb64.dll"
if "!DRIVER_BIT!"=="32" set "DLL_NAME=TrinoODBC_sb32.dll"
set "DLL_PATH_SINGLE=!INSTALLDIR_SINGLE!\lib\!DLL_NAME!"
set "ERR_PATH_SINGLE=!INSTALLDIR_SINGLE!\ErrorMessages"

echo   Driver     : !DRIVER_REGNAME!
echo   DLL        : !DLL_PATH_SINGLE!
echo.

:: ================================================
:: Branch on admin rights — use goto to avoid
:: echo-in-block parsing issues with parentheses
:: ================================================
if "!IS_ADMIN!"=="1" goto :branch_admin
goto :branch_noadmin

:: ================================================
:: BRANCH A: Admin — write registry directly via PS
:: ================================================
:branch_admin
echo   Registering driver...
set "PS_TMP=%TEMP%\_peaka_tmp_driver.ps1"

echo $drv      = '!DRIVER_REGNAME!'                                        > "!PS_TMP!"
echo $dll      = '!DLL_PATH_SINGLE!'                                       >> "!PS_TMP!"
echo $errPath  = '!ERR_PATH_SINGLE!'                                       >> "!PS_TMP!"
echo $instRoot = '!ODBCINST_PS_ROOT!'                                      >> "!PS_TMP!"
echo $vendRoot = '!VENDOR_PS_ROOT!'                                        >> "!PS_TMP!"
echo.                                                                       >> "!PS_TMP!"
echo $driversKey = $instRoot + '\ODBC Drivers'                             >> "!PS_TMP!"
echo if (-not (Test-Path $driversKey)) { New-Item $driversKey -Force ^| Out-Null }   >> "!PS_TMP!"
echo Set-ItemProperty -Path $driversKey -Name $drv -Value 'Installed'     >> "!PS_TMP!"
echo.                                                                       >> "!PS_TMP!"
echo $drvKey = $instRoot + '\' + $drv                                      >> "!PS_TMP!"
echo New-Item -Path $drvKey -Force ^| Out-Null                             >> "!PS_TMP!"
echo Set-ItemProperty -Path $drvKey -Name 'Description' -Value $drv       >> "!PS_TMP!"
echo Set-ItemProperty -Path $drvKey -Name 'Driver'      -Value $dll       >> "!PS_TMP!"
echo Set-ItemProperty -Path $drvKey -Name 'Setup'       -Value $dll       >> "!PS_TMP!"
echo.                                                                       >> "!PS_TMP!"
echo $vendorKey = $vendRoot + '\' + $drv + '\Driver'                      >> "!PS_TMP!"
echo New-Item -Path $vendorKey -Force ^| Out-Null                         >> "!PS_TMP!"
echo Set-ItemProperty -Path $vendorKey -Name 'DriverManagerEncoding' -Value 'UTF-16'  >> "!PS_TMP!"
echo Set-ItemProperty -Path $vendorKey -Name 'ErrorMessagesPath'     -Value $errPath  >> "!PS_TMP!"
echo Set-ItemProperty -Path $vendorKey -Name 'LogLevel'              -Value '0'       >> "!PS_TMP!"
echo Set-ItemProperty -Path $vendorKey -Name 'LogNamespace'          -Value ''        >> "!PS_TMP!"
echo Set-ItemProperty -Path $vendorKey -Name 'LogPath'               -Value ''        >> "!PS_TMP!"
echo Write-Host "Driver registered: $drv"                                 >> "!PS_TMP!"

!PSHELL! -ExecutionPolicy Bypass -File "!PS_TMP!"
del "!PS_TMP!" >nul 2>&1
goto :end_driver

:: ================================================
:: BRANCH B: No admin — generate .reg for manual use
:: ================================================
:branch_noadmin
set "DRIVER_REG=!ROOT_DIR!\peaka-driver.reg"

set "TPL=template\Setup-64bitDriverOn64Windows.reg"
if "%OS_BIT%"=="64" if "!DRIVER_BIT!"=="32" set "TPL=template\Setup-32bitDriverOn64Windows.reg"
if "%OS_BIT%"=="32" set "TPL=template\Setup-32bitDriverOn32Windows.reg"
set "TPL_FILE=!SCRIPT_DIR!\!TPL!"

set "PS_TMP=%TEMP%\_peaka_tmp_drvgen.ps1"
set "Q=[char]34"

echo $q = [char]34                                                                                                     > "!PS_TMP!"
echo $c = [IO.File]::ReadAllText('!TPL_FILE!')                                                                         >> "!PS_TMP!"
echo $c = $c.Replace('^<INSTALLDIR^>', '!INSTALLDIR_DOUBLE!')                                                            >> "!PS_TMP!"
echo $c = $c.Replace('\ODBCINST.INI\Peaka ODBC Driver]', '\ODBCINST.INI\!DRIVER_REGNAME!]')                           >> "!PS_TMP!"
echo $c = $c.Replace($q+'Peaka ODBC Driver'+$q+'='+$q+'Installed'+$q, $q+'!DRIVER_REGNAME!'+$q+'='+$q+'Installed'+$q) >> "!PS_TMP!"
echo $c = $c.Replace('Description'+$q+'='+$q+'Peaka ODBC Driver', 'Description'+$q+'='+$q+'!DRIVER_REGNAME!')         >> "!PS_TMP!"
echo $c = $c.Replace('\Peaka\Peaka ODBC Driver', '\Peaka\!DRIVER_REGNAME!')                                           >> "!PS_TMP!"
echo $lines = $c -split "`r`n"; $keep = $false; $out = @('REGEDIT4', '')                                             >> "!PS_TMP!"
echo foreach ($line in $lines) {                                                                                       >> "!PS_TMP!"
echo     if ($line -match '^\[HKEY.*ODBCINST' -or $line -match '^\[HKEY.*\\Peaka\\') { $keep = $true }               >> "!PS_TMP!"
echo     if ($line -match '^\[HKEY.*ODBC\.INI') { $keep = $false }                                                    >> "!PS_TMP!"
echo     if ($keep) { $out += $line }                                                                                  >> "!PS_TMP!"
echo }                                                                                                                 >> "!PS_TMP!"
echo [IO.File]::WriteAllText('!DRIVER_REG!', ($out -join "`r`n"))                                                     >> "!PS_TMP!"

!PSHELL! -ExecutionPolicy Bypass -File "!PS_TMP!"
del "!PS_TMP!" >nul 2>&1

if not exist "!DRIVER_REG!" (
    echo  [ERROR] Failed to generate peaka-driver.reg
    pause
    exit /b 1
)

echo.
echo  ================================================
echo   [ACTION REQUIRED] No admin rights.
echo.
echo   Registry file generated:
echo   !DRIVER_REG!
echo.
echo   To install, run it as Administrator:
echo     Right-click the file ^> Merge
echo  ================================================

:end_driver
echo.
echo  ================================================
echo   Done.
echo  ================================================
echo.
pause
