# Stabilization guarantees

This is the contract established before Ern-OS grows more services, apps or
bare-metal code. It describes what the implementation and tests now enforce,
not an aspirational design.

## User data and I/O

- Test and Windows smoke boots run in unique disposable directories. The
  self-rebuild test copies only source and build inputs into its own worktree;
  it never moves or removes the checkout's `disk/`.
- The health probe uses a UUID-named file, checks create/write/read/remove
  results, and removes only that exact probe. A pre-existing similarly named
  user file is covered by a regression test.
- HAL mutations return the real host result. Kernel virtual-file operations
  preserve it as answer code 7; the shell explains the storage failure. Log
  calls have checked forms that display a warning when the diary cannot be
  updated.
- `disk_write` stages complete content at `<file>.ern-new` and atomically
  replaces the final name. Recovery keeps an existing final over a stale
  stage, or promotes an orphan stage when no final exists. Account records,
  notes and boot state all take this path.

Atomic rename protects against torn application-level content. It is not a
transaction across multiple files, and it is not a substitute for backups or
filesystem durability guarantees after sudden hardware failure.

## Authentication and crypto

- New records use `ernos-stretched-sha256-v2`, an operating-system CSPRNG
  salt, 200,000 rounds and the runtime's internal SHA-256.
- The stored round count is honored only within a defensive 10,000–1,000,000
  range. Secret comparison does not exit on the first differing character.
- Legacy `stretched-sha256` records are verified with their real legacy
  algorithm and rewritten to v2 after a successful login.
- Passwords are at least eight characters, masked in every face and never
  logged. Unknown-user and wrong-password paths are delayed.
- OpenSSL is neither loaded nor linked. Windows randomness is
  `BCryptGenRandom`; supported Unix paths use the native OS CSPRNG. There is
  no `rand()` fallback.

This is a strengthened local password scheme, not a claim that a custom
SHA-256 KDF is preferable to Argon2id for a high-risk network service. A
future account-record scheme can add Argon2id without breaking migration.

## Sessions and shutdown

Logout clears the graphical session identity and transcript before returning
to login, so one person's visible conversation cannot leak to the next.
Window close and shutdown use an out-of-band signal that nested notes/files
input checks and propagates; no fake command string is injected into an app.

## Verification matrix

| environment | enforced checks |
|---|---|
| local/macOS | full suite, graphical layout compile, health check, no OpenSSL linkage inspection during release review |
| GitHub Linux | clean build, full suite, isolated byte-identical self-rebuild, no project-root disk |
| GitHub Windows | clean native build, generated-runtime inspection, isolated create/write/restart/password/recovery/collision/self-rebuild smoke, no project-root disk |

The test suite also covers interrupted-write recovery, real I/O failure,
health-probe collisions, account migration, persistence across restart,
session faces, and generated-system self-checks. A CI workflow is evidence
only when it has run green for the commit under discussion.

## Hosted versus bare metal

Ern-OS is a self-contained, self-rebuilding **hosted visual OS** today. Its
OS sources are Ernos and it owns its shell, accounts, virtual disk, services,
apps and graphical/terminal faces. clang, libc, host threads/files/windows and
optionally raylib remain underneath it. It is therefore not yet a
complete freestanding bare-metal OS. The first x86_64 boot/long-mode/serial/
allocator milestone now lives under `baremetal/`; moving the Ernos kernel and
userland onto it remains tracked in `road_to_bare_metal.md`.
