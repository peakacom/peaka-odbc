@echo off
setlocal enabledelayedexpansion

:: ================================================
::   Peaka ODBC Driver - Build Script
::
::   Produces:
::     dist\peaka.mez        -- Power BI custom connector
::     dist\peaka_odbc.zip   -- Full distribution package
::
::   Structure inside peaka_odbc.zip:
::     driver\**                     (Simba ODBC driver, as-is)
::     bin\install.bat               (main setup entry point)
::     bin\utils\**                  (helper scripts + templates)
::     extensions\powerbi\peaka.mez  (Power BI connector)
::     README.md
::
::   Requires: 7-Zip (7z.exe)
::     - Install from https://7-zip.org
::     - Or ensure 7z.exe is on PATH
:: ================================================

set "SCRIPT_DIR=%~dp0"
if "!SCRIPT_DIR:~-1!"=="\" set "SCRIPT_DIR=!SCRIPT_DIR:~0,-1!"

set "SRC_DIR=!SCRIPT_DIR!\src"
set "DIST_DIR=!SCRIPT_DIR!\dist"
set "DRIVER_DIR=!SCRIPT_DIR!\driver"

:: ------------------------------------------------
:: Locate 7-Zip
:: ------------------------------------------------
set "SEVENZIP=7z"
"%ProgramFiles%\7-Zip\7z.exe" i >nul 2>&1
if not errorlevel 1 set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"

"!SEVENZIP!" i >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [ERROR] 7-Zip not found.
    echo          Install from https://7-zip.org and ensure 7z.exe is on PATH.
    echo.
    exit /b 1
)

:: ------------------------------------------------
:: Ensure dist\ exists
:: ------------------------------------------------
if not exist "!DIST_DIR!" mkdir "!DIST_DIR!"

echo.
echo  ================================================
echo       Peaka ODBC Driver - Build
echo  ================================================
echo.

:: ================================================
:: Step 1: Build peaka.mez
::   ZIP all files inside src\extensions\powerbi\
:: ================================================
echo  [1/2] Building dist\peaka.mez ...

set "MEZ_SRC=!SRC_DIR!\extensions\powerbi"
set "MEZ_OUT=!DIST_DIR!\peaka.mez"

if exist "!MEZ_OUT!" del /f /q "!MEZ_OUT!"

pushd "!MEZ_SRC!"
"!SEVENZIP!" a -tzip "!MEZ_OUT!" * -mx=5 -r
popd

if not exist "!MEZ_OUT!" (
    echo  [ERROR] peaka.mez was not created.
    exit /b 1
)
echo  OK: !MEZ_OUT!
echo.

:: ================================================
:: Step 2: Build peaka_odbc.zip
::   Stage all content then zip into dist\
:: ================================================
echo  [2/2] Building dist\peaka_odbc.zip ...

set "ZIP_OUT=!DIST_DIR!\peaka_odbc.zip"
set "STAGE_DIR=%TEMP%\_peaka_odbc_stage_%RANDOM%"

:: Clean and create staging dir
if exist "!STAGE_DIR!" rmdir /s /q "!STAGE_DIR!"
mkdir "!STAGE_DIR!"

:: Copy driver (as-is)
xcopy /e /i /q /y "!DRIVER_DIR!" "!STAGE_DIR!\driver\" >nul

:: Copy scripts: install.bat -> bin\  and  utils\ -> bin\utils\
if not exist "!STAGE_DIR!\bin" mkdir "!STAGE_DIR!\bin"
copy /y "!SRC_DIR!\scripts\install.bat" "!STAGE_DIR!\bin\install.bat" >nul
xcopy /e /i /q /y "!SRC_DIR!\scripts\utils" "!STAGE_DIR!\bin\utils\" >nul

:: Copy Power BI connector
if not exist "!STAGE_DIR!\extensions\powerbi" mkdir "!STAGE_DIR!\extensions\powerbi"
copy /y "!MEZ_OUT!" "!STAGE_DIR!\extensions\powerbi\peaka.mez" >nul

:: Copy README
copy /y "!SRC_DIR!\README.md" "!STAGE_DIR!\README.md" >nul

:: Create zip from staging dir
if exist "!ZIP_OUT!" del /f /q "!ZIP_OUT!"
pushd "!STAGE_DIR!"
"!SEVENZIP!" a -tzip "!ZIP_OUT!" * -mx=5 -r
popd

:: Remove staging dir
rmdir /s /q "!STAGE_DIR!"

if not exist "!ZIP_OUT!" (
    echo  [ERROR] peaka_odbc.zip was not created.
    exit /b 1
)
echo  OK: !ZIP_OUT!
echo.

echo  ================================================
echo   Build complete.
echo.
echo   dist\peaka.mez        -- Power BI connector
echo   dist\peaka_odbc.zip   -- Full distribution package
echo  ================================================
echo.
