# TerminalPrompt contracts

This document records the contract decisions that later prompt engines must
preserve. The shared runtime behavior is described in [runtime.md](runtime.md).

## Result and exception policy

Every public prompt returns `PromptResult[T]` with exactly one normal outcome:

| Status | Meaning | Contains a value |
| --- | --- | --- |
| `promptAnswered` | The user submitted an answer. | Yes |
| `promptCancelled` | The user explicitly cancelled, for example with Escape or Ctrl+C. | No |
| `promptEndOfInput` | The configured input stream ended before submission. | No |

An empty string can therefore remain a valid submitted answer. Cancellation
and EOF are never represented by an empty value and do not use exceptions for
control flow.

`.value` raises `PromptValueError` when the status is not `promptAnswered`.
`.valueOr(fallback)` is the non-raising convenience form.

Exceptions are reserved for failures rather than normal user outcomes:

- `PromptConfigurationError` for invalid options known before interaction;
- `PromptIOError` for input, output, and terminal backend failures;
- `PromptStateError` for misuse of an internal runtime contract;
- `PromptNotImplementedError` is reserved for a future API deliberately
  declared before its engine exists; every current prompt API is implemented.

Validators return an empty string on success and a user-facing validation
message on failure. Validation failures are rendered and retried; they are not
exceptions. Password prompts additionally redact their submitted value from
validator messages and library-owned debug output.

## Internal boundaries

The public facade exports only prompt API and public data types. In particular,
it does not expose TerminalScreen sessions or events.

The implementation contracts are split by responsibility:

- `keys.nim` owns backend-neutral key, resize, timeout, and EOF events;
- `io.nim` owns the overridable `readEvent`, `write`, and `flush` operations;
- `session.nim` adds capabilities, terminal geometry, and idempotent cleanup;
- `render.nim` converts semantic prompt segments into strings without touching
  a stream;
- `input_engine.nim` resolves normalized keys against prompt action bindings;
- `display.nim` owns transient redraw and output-position cleanup;
- `terminal_screen_adapter.nim` maps TerminalScreen types onto those internal
  contracts.

Prompt engines must accept these contracts internally so unit tests can use a
scripted session and captured output. They must not read process-global
`stdin` or write process-global `stdout` directly.

Selection choices carry a user-facing label, typed value, optional hint, and a
disabled flag. Single-select defaults identify one enabled choice by index.
Multi-select defaults are unique enabled indices, and answers are returned in
choice-list order independent of toggle order.

## Terminal lifecycle

`withPromptSession` closes its session from `finally`, on both normal and
exceptional exits. Implementations of `close` must be idempotent. The
TerminalScreen adapter delegates raw-mode and cursor restoration to
TerminalScreen's exception-safe session guard and converts backend failures to
`PromptIOError`. The adapter records whether the opened session selected
interactive or line mode so later engines do not repeat capability decisions.

## Theme mapping

`PromptTheme` contains one TerminalStyle value for each semantic role:
question, answer, selection, error, hint, and placeholder. The default semantic
renderer selects a style by role. With ANSI disabled it strips control
sequences and emits the same text content.

Keeping roles semantic lets consumers replace a complete theme while allowing
TerminalStyle to remain the single source of truth for colors and attributes.

## Streams and key bindings

Every options-based prompt includes `PromptRuntimeOptions`. It holds borrowed
input/output `File` values and a backend-neutral `PromptKeyBindings` value.
Constructors default to `stdin`, `stdout`, and conventional terminal keys, but
callers can replace any of them explicitly.

Bindings describe prompt actions rather than TerminalScreen events. A binding
contains a `PromptKey`, optional text payload, and modifier set, which is enough
to represent both dedicated keys and combinations such as Ctrl+S. The
TerminalScreen adapter is responsible for translating its normalized key
events before an engine compares them with these bindings. Matching is exact
for key, text payload, and modifiers. Accordingly, the defaults represent
TerminalScreen's normalized Space payload and Ctrl+C modifier explicitly.
Selection prompts additionally use `selectAll` and `clearSelection`; their
defaults are the unmodified text keys `a` and `c`.

## Dependency versions

TerminalPrompt supports Nim 2.0.0 or newer. It requires tagged TerminalScreen
releases starting at 0.1.0 through the canonical GitHub `.git` URL and resolves
TerminalStyle 0.1.1 or newer by its Nimble package name. Both use compatible
version constraints in `terminal_prompt.nimble`.
