@echo off
rem ============================================================
rem  WinHotKey-AHK - one-click compile script for Windows
rem
rem  Ahk2Exe.exe lookup order:
rem    1. environment variable AHK2EXE_EXE
rem    2. subfolder "tools" next to this script
rem    3. AutoHotkey v2 install folders
rem
rem  A v2 base file AutoHotkey64.exe is located automatically and
rem  passed via /base when found. This is needed when Ahk2Exe.exe
rem  sits alone in the tools subfolder with no base file beside it.
rem
rem  Usage  : double-click this file, or run build.bat in cmd
rem  Output : WinHotKey.exe in this same folder, standalone
rem ============================================================
setlocal

set "SRC=%~dp0WinHotKey.ahk"
set "OUT=%~dp0WinHotKey.exe"

rem ---- locate Ahk2Exe.exe ----
set "AHK2EXE="
if defined AHK2EXE_EXE set "AHK2EXE=%AHK2EXE_EXE%"
if defined AHK2EXE goto FOUND_AHK2EXE
if exist "%~dp0tools\Ahk2Exe.exe" set "AHK2EXE=%~dp0tools\Ahk2Exe.exe"
if defined AHK2EXE goto FOUND_AHK2EXE
if exist "%ProgramFiles%\AutoHotkey\v2\Ahk2Exe.exe" set "AHK2EXE=%ProgramFiles%\AutoHotkey\v2\Ahk2Exe.exe"
if defined AHK2EXE goto FOUND_AHK2EXE
if exist "%LocalAppData%\Programs\AutoHotkey\v2\Ahk2Exe.exe" set "AHK2EXE=%LocalAppData%\Programs\AutoHotkey\v2\Ahk2Exe.exe"
if defined AHK2EXE goto FOUND_AHK2EXE
if exist "%ProgramFiles%\AutoHotkey\Compiler\Ahk2Exe.exe" set "AHK2EXE=%ProgramFiles%\AutoHotkey\Compiler\Ahk2Exe.exe"
if defined AHK2EXE goto FOUND_AHK2EXE

echo [ERROR] Ahk2Exe.exe was not found.
echo.
echo Looked in:
echo   - env var AHK2EXE_EXE
echo   - %~dp0tools\Ahk2Exe.exe
echo   - AutoHotkey v2 install folders
echo.
echo Fix: open the AutoHotkey app from the Start menu, click
echo Compile and follow the prompts. Or download Ahk2Exe from
echo https://github.com/AutoHotkey/Ahk2Exe/releases and put
echo Ahk2Exe.exe into the tools folder next to build.bat.
echo.
exit /b 1

:FOUND_AHK2EXE
rem ---- locate the v2 base file AutoHotkey64.exe ----
set "BASE="
if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" set "BASE=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
if not defined BASE if exist "%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe" set "BASE=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe"

echo Compiler: %AHK2EXE%
echo Source  : %SRC%
echo Output  : %OUT%
if defined BASE echo Base file: %BASE%
echo.
echo Compiling...
echo.

if defined BASE goto WITH_BASE
"%AHK2EXE%" /in "%SRC%" /out "%OUT%" /compress 1
goto CHECK_RESULT

:WITH_BASE
"%AHK2EXE%" /in "%SRC%" /out "%OUT%" /base "%BASE%" /compress 1

:CHECK_RESULT
if not errorlevel 1 goto COMPILE_OK
echo.
echo [ERROR] Compile failed. See the output above.
echo If it mentions a missing base file, make sure AutoHotkey v2
echo is installed, or add /base with the full path to
echo AutoHotkey64.exe.
echo.
exit /b 1

:COMPILE_OK
echo.
echo Done: %OUT%
echo Note: keep hotkeys.ini in the same folder as the exe.
echo A template is created automatically on first run.
echo.
pause
