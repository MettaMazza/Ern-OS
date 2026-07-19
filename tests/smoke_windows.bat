@echo off
REM smoke_windows.bat - the Windows twin of the durability check the macOS
REM suite runs: build Ern-OS, write a note, restart, and prove the note is
REM still there. Run this on a real Windows PC to verify the port.
REM
REM Usage (from the repo root):  tests\smoke_windows.bat
setlocal EnableExtensions
set "SOURCE=%~dp0\.."
set "WORK=%TEMP%\ern-os-smoke-%RANDOM%-%RANDOM%"
mkdir "%WORK%" || exit /b 1
mkdir "%WORK%\toolchain" || exit /b 1
mkdir "%WORK%\tests" || exit /b 1
xcopy /E /I /Q "%SOURCE%\system" "%WORK%\system" >nul
xcopy /E /I /Q "%SOURCE%\stdlib" "%WORK%\stdlib" >nul
copy /Y "%SOURCE%\toolchain\epc_bootstrap.c" "%WORK%\toolchain\epc_bootstrap.c" >nul
copy /Y "%SOURCE%\start_ern_os.ep" "%WORK%\start_ern_os.ep" >nul
copy /Y "%SOURCE%\build_ern_os.bat" "%WORK%\build_ern_os.bat" >nul
pushd "%WORK%"

call build_ern_os.bat
if errorlevel 1 (
    echo SMOKE FAIL: could not build Ern-OS
    exit /b 1
)

echo [smoke] first boot: create an account and write a note ...
(
  echo ada
  echo lovelace
  echo ada
  echo lovelace
  echo write a note called hello saying good morning world
  echo shut down
) | start_ern_os.exe --plain > tests\smoke1.txt 2>&1

REM Simulate two interrupted atomic writes in the isolated disk. One orphaned
REM stage must be promoted; where a final exists, its stale stage must lose.
> "disk\home\ada\recover.ern-new" echo recovered safely
> "disk\home\ada\authoritative" echo final value
> "disk\home\ada\authoritative.ern-new" echo stale value
> "disk\system\run\self_check_note" echo user sentinel

echo [smoke] second boot: read the note back ...
(
  echo ada
  echo lovelace
  echo read hello
  echo read recover
  echo read authoritative
  echo shut down
) | start_ern_os.exe --plain > tests\smoke2.txt 2>&1

findstr /C:"good morning world" tests\smoke2.txt >nul
if errorlevel 1 (
    echo SMOKE FAIL: the note did not survive a restart ^(see tests\smoke2.txt^)
    exit /b 1
)
findstr /C:"recovered safely" tests\smoke2.txt >nul
if errorlevel 1 (
    echo SMOKE FAIL: an orphan atomic-write stage was not recovered
    exit /b 1
)
findstr /C:"final value" tests\smoke2.txt >nul
if errorlevel 1 (
    echo SMOKE FAIL: a stale stage displaced its authoritative final file
    exit /b 1
)
findstr /C:"lovelace" disk\system\registry\users\ada >nul
if not errorlevel 1 (
    echo SMOKE FAIL: a plain password reached the disk
    exit /b 1
)

echo [smoke] third boot: the system rebuilds itself ...
(
  echo ada
  echo lovelace
  echo rebuild the system
  echo shut down
) | start_ern_os.exe --plain > tests\smoke3.txt 2>&1

findstr /C:"The new Ern-OS is in place" tests\smoke3.txt >nul
if errorlevel 1 (
    echo SMOKE FAIL: the self-rebuild did not finish ^(see tests\smoke3.txt^)
    exit /b 1
)
start_ern_os.exe --just-checking > tests\smoke4.txt 2>&1
findstr /C:"all is well" tests\smoke4.txt >nul
if errorlevel 1 (
    echo SMOKE FAIL: the rebuilt system failed its own checks ^(see tests\smoke4.txt^)
    exit /b 1
)
findstr /C:"user sentinel" disk\system\run\self_check_note >nul
if errorlevel 1 (
    echo SMOKE FAIL: the health probe changed a pre-existing user file
    exit /b 1
)
echo SMOKE PASS: built, recovered atomic writes, preserved the health collision, remembered across a restart, stored no plain password, and rebuilt itself.
popd
echo [smoke] isolated files kept for inspection at: %WORK%
endlocal
