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

This rule is the whole plan for bare metal: when Ern-OS one day boots on
real hardware, the four hal files are rewritten to drive the hardware
directly, and nothing above them changes.

## The layers

### hal — the hardware abstraction layer

| file | what it hides |
|---|---|
| `the_terminal.ep` | the screen and the keyboard (`say`, `ask`) |
| `the_disk.ep` | where bytes live; the only file that knows about `disk/` |
| `the_clock.ep` | what time it is |
| `the_machine.ep` | the computer itself (its name, powering off) |

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
empty, 6 already exists. The shell turns these into sentences.

Passwords are never stored. A record keeps `salt` (16 random bytes) and
`secret` — SHA-256 folded 100,000 times over salt + password. The record
also names its `scheme`, so a stronger scheme can arrive later and old
records can be migrated at login.

### the glass (graphical) desktop

| file | its job |
|---|---|
| `hal/the_glass.ep` | the ONLY window-server touchpoint: raylib loaded at run time, wrapped in plain-English brushes (a box, a line of writing, the mouse, the keys) |
| `desktop/glass_painting.ep` | pure layout: bar heights, dock-button rectangles, hit-testing, the colour palette — all testable |
| `desktop/glass_desktop.ep` | the frame loop: menu bar, conversation window, text line, dock; graphical login; runs sentences through the same perform_command |

The graphical face reuses everything the terminal face built. `say` still
files output into the transcript (capture mode); the glass paints that
transcript in a window each frame. Apps ask for input through a second
hook beside M3's repaint hook — an **input hook**: `ask`/`ask_secret`, when
one is installed, pull the typed line from the on-screen text line instead
of the keyboard, so notes/files/monitor run in the window **unchanged**.
raylib is the one optional dependency; the boot picks the graphical face
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
The suite proves the loop every run: two consecutive self-rebuilds must
emit byte-identical C. `run_command` returns a program's printed output,
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

Apps run in the foreground, in the same program: opening one hands it
the conversation until it says done. There is at most one at a time,
one owner of the terminal, and no way to lose data in a handoff.

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
one folder.

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
