# Ern-OS

**A small operating system written entirely in plain-English Ernos.**

Ern-OS boots into its own world: its own disk, its own people and passwords,
its own folders and notes — and you talk to it in plain English. Every line
of the system is written in [Ernos](https://github.com/mettamazza), the
plain-English programming language, and the whole thing rebuilds from
nothing with only a C compiler. No cloud, no accounts, no telemetry:
everything Ern-OS knows lives inside its own `disk/` folder.

```
=====================================
  Ern-OS
  a small operating system written
  entirely in plain-English Ernos
=====================================

Who are you? maria
Your password?
Welcome back, maria.

/home/maria > make a folder called letters
Made a folder called letters.
/home/maria > go to letters
You are now in /home/maria/letters.
/home/maria/letters > write a note called hello saying good morning world
Saved the note hello.
/home/maria/letters > read hello
The note hello says:
good morning world
```

## Build and boot

You need a C compiler (clang) — nothing else.

```bash
bash build_ern_os.sh      # builds the vendored Ernos compiler, then the OS
./start_ern_os            # boots into the graphical desktop (needs raylib)
./start_ern_os --terminal # a full-screen text desktop (no libraries)
./start_ern_os --plain    # or the sentence-only shell
```

For the graphical desktop, install raylib once: `brew install raylib` (or
your package manager). Without it, Ern-OS falls back to the terminal
desktop automatically — that face needs nothing at all. On Windows it is
the same, with clang and a Windows 10+ terminal — `build_ern_os.bat` then
`start_ern_os.exe`. See [docs/running_on_windows.md](docs/running_on_windows.md).

The first boot prepares the disk and asks you to become the administrator.
The **graphical desktop** is a real window: a menu bar with the clock, a
conversation window, a text line you type sentences into, and a dock of
clickable app buttons. The **terminal desktop** is the same idea drawn in
text — a Mac-style menu bar, a live side panel (Tab flips it), a
Windows-style taskbar. Every face runs the very same plain-English
commands. Say `help` inside, or read
[docs/the_command_language.md](docs/the_command_language.md).

## What it is

- **Self-contained.** Everything works offline. The whole world lives in
  `disk/`; you can read it with any file browser, and nothing ever leaves it.
- **Self-hosted.** `toolchain/epc_bootstrap.c` is the Ernos compiler,
  compiled by itself into C. clang builds the compiler, the compiler builds
  the OS — the machine needs nothing but a C compiler, ever.
- **Plain English all the way down.** The shell speaks English, and so does
  the source: the disk driver is `the_disk.ep`, the parser is
  `understand_command.ep`, and logins are checked by `verify_login`.
- **Safe.** Passwords are stored salted and folded through SHA-256 a hundred
  thousand times. Every path is checked at one fence (`the_disk.ep`), so
  nothing can reach outside the disk. Members can only change their own
  home; every action lands in a readable system log.
- **Lived-in.** Several people share one machine (`add a person called
  finn`), and it ships with apps: a **notes** editor, a numbered **files**
  walker, a system **monitor**, and a first-day **welcome** tour that
  greets the very first login. `what is running` shows the services.

## How it is built

Three strict layers, one rule: **only the hal touches the host machine.**

```
userland   system/shell/   the conversation: understand, do, help
kernel     system/kernel/  folders, people, sessions, the system log
hal        system/hal/     the terminal, the disk, the clock, the machine
```

The layer rule is enforced by the test suite, and it is the road to real
hardware: to boot Ern-OS on bare metal one day, only the four hal files
need rewriting. The full design is in
[docs/how_ern_os_works.md](docs/how_ern_os_works.md), and the bare-metal
road map in [docs/road_to_bare_metal.md](docs/road_to_bare_metal.md).

## Tests

```bash
bash tests/run_all_tests.sh
```

Checks the layer rules, runs the unit tests (the command parser, the
virtual files and their permission fences, accounts and password safety),
then boots the whole OS against a scripted conversation and compares the
transcript — twice, to prove nothing is forgotten between boots.

## The road ahead

- ~~**M1 — boot, login, shell**~~ done.
- ~~**M2 — services, apps, people**~~ done.
- ~~**M3 — the desktop**~~ done: a full-screen terminal desktop, blending
  Mac and Windows, portable to both.
- ~~**M4 — self-rebuild from within**~~ done: say `rebuild the system` and
  Ern-OS recompiles itself with its own toolchain, checks the result, and
  swaps it in — proven byte-identical across generations on every test run.
- ~~**M5 — a real graphical desktop**~~ done: a raylib window with a mouse,
  a dock of clickable apps, and a text line — the same conversation, in
  pixels. The terminal desktop and plain shell remain (they need nothing).
- **Phase 2 — bare metal**: see the road map.

## Taking Ern-OS with you

Everything needed travels in this one folder. To hand it to another
machine (or another person), pack it without your personal disk and the
built things:

```bash
tar --exclude='disk' --exclude='start_ern_os' --exclude='start_ern_os.previous' \
    --exclude='rebuilt_ern_os' --exclude='rebuilt_ern_os.ep' \
    --exclude='toolchain/epc' --exclude='toolchain/epc_next' --exclude='*_compiled.c' \
    --exclude='tests/tmp_run' --exclude='.git' -czf ern-os.tar.gz -C .. Ern-OS
```

On the other machine: unpack, then `bash install.sh` (or `bash install.sh
--check` to run the whole test suite first). Only clang is needed. On
Windows: `build_ern_os.bat`, then `tests\smoke_windows.bat` to verify.

## License

MIT.
