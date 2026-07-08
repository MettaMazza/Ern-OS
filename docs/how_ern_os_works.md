# How Ern-OS works

## The one rule

**Only the hal touches the host machine.** Everything else — the kernel,
the shell, every future app — lives entirely inside the world the hal
provides. `tests/run_all_tests.sh` enforces this with the layer lint; a
build fails if anything above the hal calls the host.

```
userland   system/shell/*.ep     may use: kernel
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

Answer codes: kernel actions that change things return a small number —
1 it worked, 2 not allowed, 3 bad name, 4 no such thing, 5 folder not
empty, 6 already exists. The shell turns these into sentences.

Passwords are never stored. A record keeps `salt` (16 random bytes) and
`secret` — SHA-256 folded 100,000 times over salt + password. The record
also names its `scheme`, so a stronger scheme can arrive later and old
records can be migrated at login.

### userland — the conversation

| file | its job |
|---|---|
| `understand_command.ep` | sentence → command (verb, target, extra) |
| `do_command.ep` | command → kernel calls → answer in English |
| `help_text.ep` | the help |
| `the_shell.ep` | login and the listen–understand–do–answer loop |

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

1. Annotate string parameters `as Str` — untyped parameters are inferred
   as numbers and printed/kept wrong.
2. Never `display` a parameter or list element directly; go through
   `say`, or normalize with `concat(x and "")` first.
3. `get_character` returns a number code (space is 32, dot 46). Compare
   codes with `==`, whole strings with `string_equals`.
4. Keep long-lived text in lists, not structure fields — the garbage
   collector currently loses strings stored in struct fields (bug filed
   in the language repo; sessions and commands are lists for this reason).
5. Only `start_ern_os.ep` (and each test file) may import.
