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
