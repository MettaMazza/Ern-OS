@echo off
REM smoke_windows.bat - the Windows twin of the durability check the macOS
REM suite runs: build Ern-OS, write a note, restart, and prove the note is
REM still there. Run this on a real Windows PC to verify the port.
REM
REM Usage (from the repo root):  tests\smoke_windows.bat
setlocal
cd /d "%~dp0\.."

call build_ern_os.bat
if errorlevel 1 (
    echo SMOKE FAIL: could not build Ern-OS
    exit /b 1
)

if exist disk rmdir /s /q disk

echo [smoke] first boot: create an account and write a note ...
(
  echo ada
  echo lovelace
  echo ada
  echo lovelace
  echo write a note called hello saying good morning world
  echo shut down
) | start_ern_os.exe --plain > tests\smoke1.txt 2>&1

echo [smoke] second boot: read the note back ...
(
  echo ada
  echo lovelace
  echo read hello
  echo shut down
) | start_ern_os.exe --plain > tests\smoke2.txt 2>&1

findstr /C:"good morning world" tests\smoke2.txt >nul
if errorlevel 1 (
    echo SMOKE FAIL: the note did not survive a restart ^(see tests\smoke2.txt^)
    exit /b 1
)
findstr /C:"lovelace" disk\system\registry\users\ada >nul
if not errorlevel 1 (
    echo SMOKE FAIL: a plain password reached the disk
    exit /b 1
)
echo SMOKE PASS: Ern-OS built, ran, remembered across a restart, and stored no plain password.
endlocal
