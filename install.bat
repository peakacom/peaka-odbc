@echo off
setlocal enabledelayedexpansion

:: ================================================
::   Peaka ODBC Driver - Setup
::
::   This is the main entry point.
::   It guides you through driver + DSN installation.
::
::   You can also run the steps individually:
::     tools\install-driver.bat  - register the driver DLL
::     tools\install-dsn.bat     - create a named DSN
::     tools\uninstall.bat       - remove a DSN or driver
::     tools\list-dsn.bat        - show installed DSNs
:: ================================================

set "SCRIPT_DIR=%~dp0"
if "!SCRIPT_DIR:~-1!"=="\" set "SCRIPT_DIR=!SCRIPT_DIR:~0,-1!"

set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"

cls
echo.
echo  ================================================
echo       Peaka ODBC Driver - Setup
echo  ================================================
echo.
echo   What would you like to do?
echo.
echo     [1] Full setup       ^(Driver + DSN^)
echo     [2] Driver only      ^(register DLL, once per machine^)
echo     [3] DSN only         ^(add connection, repeatable^)
echo     [4] Uninstall        ^(remove DSN or driver^)
echo     [5] List installed   ^(show DSNs and drivers^)
echo     [0] Exit
echo.
set "ACTION=1"
set /p "ACTION=   Your choice [1]: "

if "!ACTION!"=="0" exit /b 0
if "!ACTION!"=="2" goto :run_driver
if "!ACTION!"=="3" goto :run_dsn
if "!ACTION!"=="4" goto :run_uninstall
if "!ACTION!"=="5" goto :run_list

:: Default: full setup (1 or Enter)
:run_full
echo.
echo  --- Step 1/2: Driver Installation ---
call "!SCRIPT_DIR!\tools\install-driver.bat"
echo.
echo  --- Step 2/2: DSN Creation ---
call "!SCRIPT_DIR!\tools\install-dsn.bat"
goto :eof

:run_driver
call "!SCRIPT_DIR!\tools\install-driver.bat"
goto :eof

:run_dsn
call "!SCRIPT_DIR!\tools\install-dsn.bat"
goto :eof

:run_uninstall
call "!SCRIPT_DIR!\tools\uninstall.bat"
goto :eof

:run_list
call "!SCRIPT_DIR!\tools\list-dsn.bat"
goto :eof
