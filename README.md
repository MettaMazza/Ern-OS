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
bash build_ern_os.sh    # builds the vendored Ernos compiler, then the OS
./start_ern_os          # boots Ern-OS
```

The first boot prepares the disk and asks you to become the administrator.
Every later boot goes straight to the login. Say `help` inside the shell to
see everything Ern-OS understands, or read
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

- **M2 — services and apps**: an init system, a notes editor, a file
  manager, a system monitor; more people at once.
- **M3 — the desktop**: a full-screen terminal desktop.
- **M4 — self-rebuild from within**: say `rebuild the system` inside
  Ern-OS and it recompiles itself with its own toolchain.
- **Phase 2 — bare metal**: see the road map.

## License

MIT.
