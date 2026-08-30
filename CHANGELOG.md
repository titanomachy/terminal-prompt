# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project intends to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

### Changed

- Use the suite-wide Nim 2.0.0 minimum and declare suite dependencies by
  GitHub URL, pinning the not-yet-tagged/not-yet-listed TerminalScreen API to a
  verified commit.
- Default prompt sessions to safe fallback behavior while retaining an opt-in
  strict terminal requirement.
- Match the default Space and Ctrl+C bindings to TerminalScreen's normalized
  text payload and modifier data.

[Unreleased]: https://github.com/titanomachy/terminal-prompt/compare/v0.1.0...HEAD
