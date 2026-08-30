# Text, password, and confirmation prompts

Milestone 2 implements the three editable one-line prompts. Each public call
opens an isolated session, uses the configured streams and key bindings, and
returns an answered, cancelled, or end-of-input `PromptResult`.

## Shared editing behavior

Interactive prompts support Unicode- and terminal-grapheme-aware insertion,
Left/Right, Home/End, Backspace, Delete, submission, and cancellation. Resize
events update redraw width without changing the edited value. Ctrl+D acts as
forward Delete when text follows the cursor and as end-of-input when the editor
is empty.

In line mode, one logical input line is consumed for each attempt. This avoids
reading ahead into input intended for a later one-shot prompt. Invalid input
renders an error and starts a fresh line; interactive mode retains invalid text
so it can be corrected in place. Neither mode treats cancellation or EOF as an
empty answer.

All prompt-owned displays and terminal sessions close from `finally`, including
after validators or I/O backends raise.

## Text prompts

Submitting non-empty text returns it unchanged. Submitting an empty editor uses
`defaultValue` when one is configured; the default is validated just like typed
input. Without a default, an empty string is a valid answer unless a validator
rejects it.

A placeholder is visual only and is never submitted. When both a default and a
placeholder are configured, the default is shown because it describes what an
empty submission will return.

Validators return an empty string to accept a value or a user-facing error to
retry. Text validator exceptions propagate after display and terminal cleanup.

## Password prompts

Password prompts never render entered text. The configured mask is repeated
once per terminal grapheme; an empty mask enables no-feedback entry. A mask may
contain at most one terminal grapheme and cannot contain control characters.

Successful `PromptResult[string]` values still provide the password through
`.value`, but their `$` debug representation prints `[redacted]`. Validator
messages have exact occurrences of the submitted password replaced with
`[redacted]`. If a password validator raises, TerminalPrompt raises a generic
`PromptError` without retaining the validator exception as a parent, preventing
its message from exposing the input.

Applications remain responsible for treating the deliberately requested
`.value` as sensitive and for ensuring validators do not disclose transformed
or derived secret data.

## Confirmation prompts

Confirmation prompts display both configured labels and the configured
default. An empty submission selects that default. Input accepts either full
label without case sensitivity or its first terminal grapheme when the two
labels have distinct initials. If initials are ambiguous, only full labels are
accepted. Other input renders `Enter <yesLabel> or <noLabel>.` and retries.

Labels must be non-empty, distinct without case sensitivity, valid UTF-8, and
free of control characters.
