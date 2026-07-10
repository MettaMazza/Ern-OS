# Running Ern-OS on Windows

Ern-OS is written to run on both macOS and Microsoft Windows. Every part
that touches the machine — the screen, the keyboard, files, the clock,
threads — goes through the hardware abstraction layer and the language
runtime, and both carry a native Windows path alongside the macOS/Linux
one. The desktop draws with plain ANSI/VT escape codes, which a modern
Windows terminal understands just as macOS Terminal does.

## What you need

- **LLVM/clang** on your `PATH` (`clang --version` should work). Install
  it from the LLVM releases or with `winget install LLVM.LLVM`.
- **A Windows 10+ terminal** — Windows Terminal, or a recent console host.
  These render VT escape sequences, which the desktop needs. (On very old
  consoles the escape codes would show as text; use Windows Terminal.)

Nothing else — no Rust, no Visual Studio, no libraries. The runtime uses
native Win32 threads, so there is no separate thread library to link.

## Build and boot

From a command prompt in the repo:

```bat
build_ern_os.bat
start_ern_os.exe
```

`build_ern_os.bat` compiles the vendored Ernos compiler from the frozen
`toolchain\epc_bootstrap.c` with clang, then compiles the whole OS. Boot
into the desktop, or run the sentence-only shell with:

```bat
start_ern_os.exe --plain
```

## Verify the port

```bat
tests\smoke_windows.bat
```

This builds Ern-OS, creates an account, writes a note, restarts, and
checks the note is still there and that no plain password reached the
disk — the same durability proof the macOS suite runs.

## Honest status

The macOS build is exercised on every change by the full test suite. The
**Windows path is written and reviewed for portability but has not yet
been run on a real Windows machine** — this project is developed on a Mac,
which cannot execute Windows binaries. The building blocks it depends on
(the `read_key` / `terminal_columns` / `terminal_rows` / `screen_write`
runtime builtins, and Win32 threads) all carry `#ifdef _WIN32` native
paths, and the desktop uses only escape codes both terminals share. If you
run `tests\smoke_windows.bat` on a PC and it reports trouble, that output
is exactly what is needed to finish the port — please share it.

Two things known to differ on Windows today:

- **Passwords typed in the desktop** rely on `_getch`, which reads a key
  at a time without echo — the same as the macOS raw path.
- **The heartbeat and other services** use Win32 threads through the same
  runtime that the macOS build uses; the thread-safe garbage collector is
  platform-independent.
