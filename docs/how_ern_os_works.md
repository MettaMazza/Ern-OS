# How Ern-OS works

## The one rule

**Only the hal touches the host machine.** Everything else — the kernel,
the shell, every future app — lives entirely inside the world the hal
provides. `tests/run_all_tests.sh` enforces this with the layer lint; a
build fails if anything above the hal calls the host.

```
userland   system/shell/*.ep     may use: kernel (and the hal's say/ask/clock)
           system/apps/*.ep
kernel     system/kernel/*.ep    may use: hal
hal        system/hal/*.ep       may use: the host (vendored stdlib)
```

This rule bounds the bare-metal plan: when Ern-OS one day boots on real
hardware, the six hosted HAL modules get hardware or freestanding editions.
The runtime must also become freestanding; kernel, apps and shell stay on the
same contracts.

## The layers

### hal — the hardware abstraction layer

| file | what it hides |
|---|---|
| `the_terminal.ep` | the screen and the keyboard (`say`, `ask`) |
| `the_disk.ep` | where bytes live; the only file that knows about `disk/` |
| `the_clock.ep` | what time it is |
| `the_machine.ep` | the computer itself (its name, powering off) |
| `outside_programs.ep` | the hosted self-rebuild's process and binary operations |
| `the_glass.ep` | the optional raylib window, drawing, mouse and keyboard |

`the_disk.ep` is also the security fence: every path is checked here —
no `..`, no absolute paths, no strange characters — so nothing above it
can ever reach outside the disk folder, no matter how confused it gets.

### kernel — the world Ern-OS offers

| file | what it owns |
|---|---|
| `virtual_files.ep` | the folder world (`/home`, `/system`, `/apps`), who may change what |
| `user_accounts.ep` | people and their password fingerprints |
| `sessions.ep` | who is at the keyboard, where they are standing |
| `system_log.ep` | the diary at `/system/log/system.log` |
| `messages.ep` | the message board — named channels, the system's IPC |
| `services.ep` | real background threads (heartbeat), uptime, the boot moment |

**How services work.** A service runs on its own thread and owns
everything it touches. Its two channels are posted on the message board
under well-known names ("heartbeat orders", "heartbeat answers"); the
shell and the apps speak to it only through the board, with small
number messages (1 = stop, 2 = how are you?). This required fixing the
language runtime itself — spawned threads were invisible to the garbage
collector, and a thread waiting in channel_select could stall or crash
collections — both fixed upstream (with regression tests in the
language repo's differential suite) after this project found them.

Answer codes: kernel actions that change things return a small number —
1 it worked, 2 not allowed, 3 bad name, 4 no such thing, 5 folder not
empty, 6 already exists, 7 the host I/O failed. The shell turns every code
into a sentence, and checked log calls visibly report a diary failure.

Passwords are never stored. A current record keeps `salt` from the operating
system CSPRNG, `rounds` (currently 200,000), `scheme` and `secret`. The v2
scheme domain-separates salt and password, then repeatedly folds with the
runtime's internal SHA-256. Verification uses the record's valid round count
and compares without an early exit. A successful login to the legacy
`stretched-sha256` scheme rewrites it in the current form. Passwords must be
at least eight characters; failed logins are delayed.

### the glass (graphical) desktop

| file | its job |
|---|---|
| `hal/the_glass.ep` | the ONLY window-server touchpoint: raylib loaded at run time, wrapped in plain-English brushes (a box, a line of writing, the mouse, the keys) |
| `desktop/glass_painting.ep` | pure layout: bar heights, dock-button rectangles, hit-testing, the colour palette — all testable |
| `desktop/glass_desktop.ep` | the frame loop: Mac-like menu/window chrome, Windows-like Start/taskbar, conversation, system sidebar and graphical login; runs sentences through the same perform_command |

The graphical face reuses everything the terminal face built. `say` still
files output into the transcript (capture mode); the glass paints that
transcript in a window each frame. Apps ask for input through a second
hook beside M3's repaint hook — an **input hook**: `ask`/`ask_secret`, when
one is installed, pull the typed line from the on-screen text line instead
of the keyboard, so notes/files/monitor run in the window **unchanged**.
raylib is the one optional graphical dependency; the boot picks that face
only when `glass_available` says a window is possible, and falls back to
the terminal desktop otherwise. On bare metal (Phase 2) this file would
drive a framebuffer instead — the desktop above it wouldn't change.

### the self-rebuild

| file | its job |
|---|---|
| `hal/outside_programs.ep` | the ONLY place allowed to run host programs (enforced by lint); per-OS copy/move/remove and `.exe` naming |
| `kernel/rebuilding.ep` | the loop as small steps — copy source, compile, check, swap, tidy — plus the toolchain re-bake; each step logged |
| `shell/self_checks.ep` | what `--just-checking` runs: the disk, the ears (parser), the locks (a pinned password-folding answer), the face (frame widths) → "all is well" |

`rebuild the system` closes the self-hosting loop from inside: the OS
compiles a copy of its own source with the vendored toolchain (compiling
the original name would write over the running binary), boots the result
headless until it says *all is well*, and only then swaps it in — keeping
the old binary as `.previous` and restoring it if the swap goes wrong.
The suite proves the loop every run in a disposable copied worktree: two
consecutive self-rebuilds must emit byte-identical C, without touching a
real project disk. `run_command` returns a program's printed output,
so every step is judged by what it *says* — fittingly for this project.

### userland — the conversation and the apps

| file | its job |
|---|---|
| `understand_command.ep` | sentence → command (verb, target, extra) |
| `do_command.ep` | command → kernel calls → answer in English |
| `help_text.ep` | the help |
| `the_shell.ep` | login and the listen–understand–do–answer loop |
| `apps/app_registry.ep` | which apps exist, opening one by name |
| `apps/notes.ep` | line-by-line note editor |
| `apps/files.ep` | numbered folder walker |
| `apps/monitor.ep` | the system report |
| `apps/welcome.ep` | the first-day tour (opens itself on first login) |

Apps run in the foreground, in the same program: opening one hands it the
conversation until it says done. There is at most one at a time and one
owner of the terminal. A distinct shutdown signal unwinds nested app input;
logout clears the graphical session and transcript before another person can
sign in.

### The desktop

| file | its job |
|---|---|
| `desktop/screen_painting.ep` | pure string brushes: escape codes, colours, framed-window and bar builders (no printing — all testable) |
| `desktop/the_desktop.ep` | the layout, the side panels, the key-by-key prompt, and `desktop_loop` |

The desktop is a **face over the same conversation**. Its trick is in the
terminal HAL: in full-screen mood, `say` no longer prints — it files each
line into a transcript the desktop paints inside its window. So the shell,
the parser, `do_command`, and every app run completely unchanged; their
words simply land in the right place. When an app asks a question from deep
in the call stack, the terminal fires a **repaint hook** the desktop left
behind (a closure — the HAL never imports the desktop), so the screen
refreshes before it waits for the answer. The main prompt reads one key at
a time (so **Tab** can flip the side panel mid-sentence); app sub-prompts
read a whole line. Two new HAL verbs, `paint` (draw raw bytes, no newline)
and `ask_secret` (echo `*`), sit on four runtime builtins added for this —
`read_key`, `terminal_columns`, `terminal_rows`, `screen_write` — each with
a native macOS and Windows path. `--plain` turns the whole face off and
gives the M2 shell.

## One program, one manifest

The Ernos compiler builds whole programs, and two imports of the same file
through different paths collide. So Ern-OS uses a single import manifest:
`start_ern_os.ep` names every module exactly once, and no module inside
`system/` carries imports of its own (the lint enforces this too).

## The virtual disk

`disk/` on the host is the whole universe: `disk/home/<person>` is each
person's home, `disk/system/registry/users/` the account records,
`disk/system/log/` the diary. It is plain files on purpose — you can read
every part of it with an ordinary file browser, and back it up by copying
one folder. Replacing content writes a sibling `.ern-new` file and atomically
renames it into place. On the next access, a final file wins over a stale
stage; an orphaned complete stage is promoted. That policy covers account
records, notes and critical state because all of them use `disk_write`.

The runtime supplies SHA-256 and MD5 internally; Ern-OS does not link
OpenSSL. Random salts and UUIDs use the host CSPRNG (BCryptGenRandom on
Windows, arc4random on Apple/BSD, getrandom or `/dev/urandom` on Linux/Unix)
and fail closed rather than falling back to a predictable generator.

## The first bare-metal layer

`baremetal/` is deliberately parallel to the hosted program while the Ernos
runtime becomes freestanding. Its Multiboot2 entry begins in the bootloader's
32-bit protected mode, creates four-level identity paging for the first GiB,
enables x86_64 long mode, establishes its own stack and calls a freestanding C
kernel. That kernel uses only the new `ern_hal_*` and `ern_*` runtime contracts.

There is no libc, pthread, host filesystem, process, window server or raylib in
the linked ELF. The current hardware terminal writes directly to COM1; the
machine HAL halts the CPU. A bounded 1 MiB bump arena supplies the first
allocator. `epc freestanding` runs the normal Ernos parser, checks, optimizer
and code generator with a small host-free ABI. The build uses it to compile
`baremetal/kernel/hello.ep`, whose HAL call and success result are required
before the kernel emits its final marker. CI boots the GRUB ISO in QEMU and
requires both the Ernos-authored serial line and that marker.

This does not bypass the layer rule or create a second product. It establishes
the bottom edge and now carries the first real Ernos-generated function across
it. ABI v1 is intentionally limited to primitive code and explicit HAL FFI;
managed collections, threads and the existing Ernos kernel/userland still need
the freestanding collector, scheduler and disk contracts before they can run
inside the ELF.

## Rules of thumb for writing Ern-OS code

Learned the hard way, enforced by example:

1. Annotate string parameters `as Str` — no longer load-bearing since
   the compiler learned to honor and infer parameter types, but it keeps
   intent readable.
2. All words for people go through `say`/`ask` — one owner of the
   terminal. (The old pointer-printing compiler bug behind this rule is
   fixed upstream; the style stays because it is right.)
3. `get_character` returns a number code (space is 32, dot 46). Compare
   codes with `==`, whole strings with `string_equals`.
4. `channel` is a reserved word — name channel-holding variables things
   like `control`, `answers`, `the_channel`.
5. Only `start_ern_os.ep` (and each test file) may import.
6. A service thread makes everything it needs before its loop and
   allocates nothing inside it — steady loops own their world.
