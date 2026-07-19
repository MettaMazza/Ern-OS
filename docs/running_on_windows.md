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

Nothing else — no Rust, OpenSSL, Visual Studio or pthread library. The runtime
uses native Win32 synchronization and threads. The **graphical desktop**
additionally needs raylib installed (`raylib.dll` or `libraylib.dll` on the
PATH); without it, Ern-OS runs the terminal desktop, which needs nothing.

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

This copies the required sources into a unique folder under `%TEMP%`, builds
there, creates an account, writes a note, restarts, exercises orphan/stale
atomic-write recovery, preserves a health-probe name collision, and checks
that no plain password reached the disk. It also self-rebuilds and runs the
rebuilt binary's health check. It never creates, renames or deletes the
checkout's `disk\`.

## Verification and platform details

`.github/workflows/ci.yml` runs `build_ern_os.bat` and the isolated smoke on
a real `windows-latest` GitHub runner for every push and pull request. The job
also fails if a project-root `disk\` appears. Treat a green Windows job as the
portability proof for a particular commit; a local macOS run cannot substitute
for it. Linux separately runs the complete suite and proves it leaves no root
disk.

Windows-specific runtime paths are deliberate:

- **Passwords typed in the desktop** rely on `_getch`, which reads a key
  at a time without echo — the same as the macOS raw path.
- **The heartbeat and other services** use Win32 threads through the same
  runtime that the macOS build uses; the thread-safe garbage collector is
  platform-independent.
- **Random salts and UUIDs** come from `BCryptGenRandom`, loaded from the
  system `bcrypt.dll`; startup fails closed if the CSPRNG is unavailable.
- **Atomic replacement** uses `MoveFileExA` with replace-existing and
  write-through flags. POSIX builds use `rename`.
- **Crypto hashes** use the vendored runtime implementation, so there is no
  hidden Homebrew/OpenSSL linker dependency.
