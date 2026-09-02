# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project intends to follow [Semantic Versioning](https://semver.org/).

## v0.1.1 - 2026-09-01

### Added

- Dedicated ARC and ORC test tasks and stable-Nim Linux CI jobs.
- Complete normalized-key adapter coverage and deterministic lifecycle tests
  proving that all five prompt types close their sessions after success,
  cancellation, EOF, and injected I/O failures.
- Build-policy regression coverage for compiler output isolation, source-tree
  cleanliness, package exclusions, and dependency constraints.
- Runnable custom-theme and redirected-workflow examples, with automatic
  compile-check discovery for every Nim file under `examples/`.

### Fixed

- Preserve printable Windows AltGr text after key-binding resolution.
- Preserve POSIX output newline behavior while raw input is active, and prevent
  inherited terminal translations from discarding or remapping Enter.
- Correct stale dependency documentation and clarify the public/internal split
  in generated module documentation.

### Changed

- Rename milestone-numbered test files by responsibility: runtime, line
  prompts, selection prompts, and cross-platform compatibility.
- Complete the `0.1.0` definition-of-done audit, record its clean-archive
  release-check evidence, and close the Windows fallback decision in favor of
  native console events with VT output or capability-driven line mode.
- Fall back to plain line mode when interactive terminal setup fails and strict
  terminal operation was not requested, including on Windows consoles that
  cannot enable VT output.
- Mark the implementation plan's test-strategy matrix complete and document
  how each supported compiler, platform, and memory-manager configuration is
  exercised.
- Resolve TerminalStyle by its Nimble package name and replace TerminalScreen's
  pre-release commit pin with a compatible constraint on tagged releases
  starting at `0.1.0`.

## v0.1.0 - 2026-09-01

### Added

- Initial Nimble library project for `terminal_prompt`.
- Architecture and implementation roadmap for the package.
- Contributor guidance.
- Nim and Nimble configuration that keeps compiler output under `build/`.
- Explicit `PromptResult[T]` contracts for answered, cancelled, and
  end-of-input outcomes, plus the prompt error policy.
- Public option types and signatures for text, password, confirmation,
  single-select, and multi-select prompts, including custom streams and key
  bindings.
- Injectable I/O, key-event, renderer, and terminal-session interfaces.
- Internal TerminalScreen 0.1.0 adapter and semantic TerminalStyle theme.
- Compile-checked API examples, deterministic contract tests, generated API
  documentation task, and a combined release-check task.
- Automatic interactive/line session selection with a plain fallback for
  redirected or limited terminals.
- A binding-aware normalized input engine covering prompt actions, raw keys,
  resize events, timeouts, and EOF without losing backend event data.
- Unicode cell-aware transient redraw, line-mode output, and idempotent display
  cleanup guards.
- Reusable scripted session/output capture and POSIX PTY integration coverage
  for cancellation and raw-mode restoration after failures.
- A Unicode- and terminal-cell-aware shared line editor with grapheme-safe
  insertion, movement, Backspace, Delete, Home, and End operations.
- Text prompts with visual placeholders, empty-submission defaults, validators,
  retained interactive corrections, and fresh line-mode retries.
- Password prompts with configurable one-grapheme or no-feedback masking,
  validator-message redaction, generic validator-failure diagnostics, and
  sensitive `PromptResult` debug representations.
- Confirmation prompts with configurable labels and defaults, case-insensitive
  full-label matching, and unambiguous initial shortcuts.
- Deterministic Milestone 2 coverage for interactive editing, validation,
  cancellation, EOF, resize, password secrecy, and redirected public APIs.
- Single-select prompts with arrow/Home/End navigation, optional wrapping,
  disabled-choice skipping, initial choices, terminal-height viewports, and
  resize-aware focus visibility.
- Multi-select prompts with initial selections, Space toggling, configurable
  select-all/clear bindings, disabled-choice protection, and explicit Enter
  submission.
- Plain line-mode selection using one-based indices, including comma- or
  space-separated multi-select input, validation retries, and documented empty
  list behavior.
- Deterministic Milestone 3 state-machine tests and a POSIX PTY smoke test for
  redraws that preserve output surrounding a selection prompt.
- A Linux, macOS, and Windows CI matrix covering the Nim 2.0 release line and
  current stable Nim.
- Milestone 4 compatibility tests for ANSI-disabled rendering, redirected
  workflows across all five prompts, narrow/resized terminals, Unicode labels,
  and viewport-bounded 10,000-choice lists.
- Compile-checked project-setup and custom-runtime examples, a public API
  reference, migration notes, security guidance, and a compatibility guide.
- A repeatable release-mode benchmark for interactive selection lists from 100
  through 100,000 choices.

### Changed

- Use the suite-wide Nim 2.0.0 minimum and declare suite dependencies by
  GitHub URL, pinning the not-yet-tagged/not-yet-listed TerminalScreen API to a
  verified commit.
- Default prompt sessions to safe fallback behavior while retaining an opt-in
  strict terminal requirement.
- Match the default Space and Ctrl+C bindings to TerminalScreen's normalized
  text payload and modifier data.
- Read redirected input one logical line per prompt so a session cannot consume
  input intended for subsequent one-shot prompts.
- Implement the previously declared single-select and multi-select APIs and add
  navigation wrapping plus select-all/clear fields to their option contracts.
- Replace the invalid TerminalScreen `#@head` selector with a reproducible pin
  to the latest verified session/CI fix revision.
- Qualify confirmation label normalization to compile without an ambiguous
  `strip` overload on the supported Nim 2.0 floor.
- Document the completed compatibility milestone and defer selection filtering
  until benchmark or application evidence justifies its interaction cost.
- Use the explicit `.git` form of the pinned TerminalScreen dependency URL so
  fresh Nimble caches can classify and clone the exact revision.
- Isolate API documentation generation from the package-wide compiler output
  directory so Nim 2.0's documentation helper works on macOS ARM runners.


`[v0.1.0]`: [https://github.com/titanomachy/terminal-prompt/releases/tag/v0.1.0](https://github.com/titanomachy/terminal-prompt/releases/tag/v0.1.0)
