# Contributing to TerminalPrompt

Thank you for helping improve TerminalPrompt. The package is part of the Nim
Terminal Suite and is intended to remain focused on short, one-shot prompts.
Persistent TUI widgets and unrelated rendering features should be proposed in
the corresponding suite package.

## Requirements

- Nim `2.0.0` or newer while that remains the constraint in
  `terminal_prompt.nimble`;
- Nimble (included with a normal Nim installation);
- Git.

## Local setup

Clone the repository, enter its directory, and let Nimble validate the package:

```sh
nimble install --depsOnly
nimble check
nimble compilePackage
nimble test
nimble testMemoryManagers
nimble examples
nimble docs
nimble benchmark
```

Compiler products and cache files are written beneath `build/`. Do not commit
that directory.

## Development guidelines

- Keep the public API in `src/terminal_prompt.nim`; split implementations into
  focused modules under `src/terminal_prompt/`.
- Prefer Nim's standard library. Declare suite or third-party packages by their
  Nimble package name with an explicit compatible version constraint. If a
  package is not listed yet, use its canonical repository URL with a compatible
  tagged version constraint.
- Keep terminal input, state transitions, and rendering separable so tests can
  use scripted input instead of a live TTY.
- Restore raw mode, cursor visibility, and other terminal state on every exit
  path, including cancellation and exceptions.
- Treat passwords and other secret input as sensitive: never echo or include
  them in diagnostics.
- Add `##` doc comments to exported symbols.
- Follow the style of surrounding Nim code and run `nimpretty` on changed Nim
  files when formatting is needed.

## Tests

Add focused `std/unittest` coverage for each change. Test success, validation
failure, cancellation, EOF, and terminal-cleanup behavior where applicable.
Keep tests deterministic and independent of the developer's terminal.

Run the complete local checks before submitting a change:

```sh
nimble releaseCheck
```

CI repeats release checks with Nim 2.0.x and stable Nim on Linux, macOS, and
Windows, then runs the portable suite with ARC and ORC on stable Nim/Linux.
Use `nimble testArc` or `nimble testOrc` to reproduce one memory-manager job.
Platform-specific tests should use compile-time guards only where the underlying
operating-system facility is genuinely unavailable; behavioral state-machine
coverage should remain portable.

For selection changes, run `nimble benchmark` and compare like-for-like
release builds. Treat timing as diagnostic evidence rather than a fixed test
threshold because developer and CI machines vary.

## Changes and pull requests

1. Keep each change focused and explain its user-visible behavior.
2. Add or update tests and documentation with the implementation.
3. Add a concise entry under `Unreleased` in `CHANGELOG.md` for user-visible
   changes.
4. Avoid breaking public APIs without discussing the migration path first.
5. Confirm that generated files and local planning documents are not staged.

Bug reports should include the Nim version, operating system, terminal emulator,
minimal reproduction, expected behavior, and actual behavior. Do not include
passwords, tokens, or other secrets in logs or examples.
