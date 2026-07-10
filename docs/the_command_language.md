# The command language

Ern-OS listens in plain English. Padding words — please, the, a, my, just —
are ignored, and most verbs have friendly synonyms. Whatever follows
**saying** is kept exactly as you typed it.

## Finding your way

| say | it means |
|---|---|
| `where am i` | which folder you are standing in |
| `show my files` (or `look`, `list`, `see`, `ls`) | what is in this folder |
| `look in letters` | what is in another folder |
| `go to letters` (or `enter`, `cd`, `visit`) | step into a folder |
| `go up` / `go back` | step out to the folder above |
| `go home` | back to your home folder |

## Making and changing things

| say | it means |
|---|---|
| `make a folder called letters` (or `create`, `new`) | a new folder |
| `write a note called hello saying good morning` | write a note |
| `read hello` (or `open`) | show what a note says |
| `move hello to greeting` (or `rename`) | move or rename |
| `remove hello` (or `delete`, `erase`, `trash`) | throw away |

Notes and folders can be named with several words: `make a folder called
summer plans`. Names may use letters, digits, spaces, dots, dashes and
underscores. Paths written with a slash work anywhere a name does:
`read letters/hello`, `look in /home/maria`.

## Apps and services

| say | it means |
|---|---|
| `open notes` | a small editor — change a note line by line |
| `open files` | walk your folders by number |
| `open monitor` | how the system is doing |
| `open welcome` | the first-day tour again |
| `what is running` | services and the apps you can open |
| `start the heartbeat service` | admins only |
| `stop the heartbeat service` | admins only |

Inside **notes**: `list`, `edit <name>`, then `add <words>`,
`change <number> to <words>`, `remove <number>`, `show`, `save`, `done`.
Inside **files**: say a door number to open it, or `up`, `home`, `done`.

## The desktop

By default Ern-OS boots into a full-screen desktop: a menu bar across the
top with the clock and who is signed in, your conversation in a window on
the left, a live panel on the right, and a taskbar along the bottom
listing the apps and the heartbeat. You still talk to it in the same
sentences — the desktop is only the face.

- **Tab** flips the right-hand panel between *at a glance* (you, where you
  are, uptime, beats), *notes here* (what is in this folder), and *the
  diary* (the latest lines of the system log).
- Passwords you type show as `*` and never appear on screen.
- `start ern_os --plain` skips the desktop and gives the sentence-only
  shell — handy over a plain pipe, and what the tests drive.

## People (admins only)

| say | it means |
|---|---|
| `add a person called finn` | a new member (you choose their password) |
| `list people` | everyone with an account |
| `remove the person called finn` | their account goes; their notes stay |

## About you and the system

| say | it means |
|---|---|
| `who am i` | your name, role, and when you signed in |
| `what time is it` | the clock |
| `help` | the list of commands |
| `log out` (or `sign out`) | let someone else use the machine |
| `shut down` (or `power off`, `quit`, `exit`) | stop Ern-OS |

## Who may do what

- **Members** may change things only inside their own home folder. They can
  walk anywhere and read anything, but the system and other homes are fenced.
- **Admins** may change anything, including `/system`.
- Everyone's actions are written to the system diary at
  `/system/log/system.log`.

## Known small print (M1)

- Passwords are typed in the open at the prompt (no hidden input yet).
- Names lose padding words: a folder cannot be called "my letters" —
  the "my" is treated as padding.
- Text is ASCII for now; accented letters are politely refused in names.
