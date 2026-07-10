@echo off
REM build_ern_os.bat - build Ern-OS on Windows, using only clang.
REM
REM   1. Build the Ernos compiler from the frozen bootstrap if it is missing.
REM   2. Compile start_ern_os.ep (the whole OS) into start_ern_os.exe.
REM
REM Requires: LLVM/clang on the PATH, and a Windows 10+ terminal (Windows
REM Terminal, or a recent console) so the desktop's VT escape codes work.
REM The runtime uses native Win32 threads, so no extra thread library.
REM
REM Usage:  build_ern_os.bat
setlocal
cd /d "%~dp0"

if not exist "toolchain\epc.exe" (
    echo [toolchain] compiling the Ernos compiler from frozen C with clang ...
    clang -O2 "toolchain\epc_bootstrap.c" -o "toolchain\epc.exe"
    if errorlevel 1 (
        echo [toolchain] build failed
        exit /b 1
    )
)

echo [ern-os] compiling the operating system ...
"toolchain\epc.exe" start_ern_os.ep
if errorlevel 1 (
    echo [ern-os] compile failed
    exit /b 1
)

echo [ern-os] done - boot it with:  start_ern_os.exe
endlocal
