# Session, input, and display runtime

Milestone 1 provides the internal runtime used by all concrete prompt engines.
These modules are intentionally absent from the public `terminal_prompt`
facade; applications configure them through each prompt's runtime options.

## Session modes and fallback

A session selects `promptInteractiveMode` only when all of the following are
true:

- raw mode was requested;
- both input and output are terminals;
- raw input is supported;
- ANSI output is supported.

Any missing capability selects `promptLineMode`. Line-mode sessions disable raw
mode, cursor hiding, resize monitoring, and ANSI output. They read one logical
line directly from the borrowed `File` instead of opening TerminalScreen's raw
event decoder; this prevents one one-shot prompt from reading ahead into lines
intended for later prompts. Redirected input, redirected output, and `TERM=dumb`
therefore remain usable without cursor controls or terminal mode changes.

Fallback is the default: `defaultPromptSessionOptions()` sets
`requireTerminal` to `false`. Internal callers can set it to `true` when a
strict terminal requirement is appropriate; redirected streams then raise
`PromptIOError` through the adapter.

## Normalized input actions

`PromptInputEngine` reads only from an injected `PromptIO`. Key events are
matched exactly against `PromptKeyBindings`, including their text payload and
modifier set. Cancellation has first precedence, followed by submission,
movement, deletion, and toggling. The default bindings recognize:

- Enter for submission;
- Escape and Ctrl+C for cancellation;
- arrows and Home/End for movement;
- Backspace/Delete for deletion;
- Space for toggling.

Unbound events are preserved rather than discarded. This includes text, Tab,
Backtab, Ctrl+D, Insert, Page Up/Down, and unknown escape sequences. Resize,
timeout, and EOF also remain distinct engine events. A concrete prompt can
therefore interpret Space as text or Ctrl+D as forward deletion/EOF when its
own state requires that behavior.

## Redraw and cleanup

`PromptDisplay` owns a single transient frame. In interactive mode, every
redraw clears the preceding physical rows and redraws from the frame's first
row. Row counts use TerminalStyle's ANSI-aware, Unicode cell-aware
`displayWidth`, the current terminal width, and explicit newlines. Resize
events can update the stored width before the next redraw.

Line mode never emits ANSI. Repeated frames are retained as separate lines,
which produces readable logs for pipes and files rather than simulated
in-place output.

`withPromptDisplay` and `withPromptSession` both use `finally`. Display cleanup
runs before session cleanup when the guards are nested, and both `close`
operations are idempotent. A finished frame can be replaced with one permanent
output line; cancellation or an exception clears an interactive transient
frame and leaves line-mode history intact.

## Deterministic testing

`tests/support/scripted_session.nim` implements all session contracts with a
scripted event queue, captured output, counters, configurable capabilities and
geometry, and injected read/write/flush/close failures. Unit tests cover action
resolution, redirected fallback, redraw output, and exceptional cleanup
without process-global streams.

On POSIX, a PTY integration test additionally verifies that a real Ctrl+C byte
becomes a cancellation action and that terminal flags are restored after an
injected exception. TerminalPrompt delegates platform-specific decoding and
restoration to TerminalScreen, including its Windows backend.

The concrete text, password, and confirmation behavior built on this runtime is
documented in [prompts.md](prompts.md).
