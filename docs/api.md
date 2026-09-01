# Public API reference

Applications normally need only `import terminal_prompt`. The facade exports
the five prompt procedures, their option constructors, result helpers, choices,
themes, and key-binding types. Internal session and renderer modules are not
part of the compatibility promise.

## Prompt procedures

| Prompt | Convenience form | Options form | Answer type |
| --- | --- | --- | --- |
| Text | `askText(message, ...)` | `askText(TextPromptOptions)` | `string` |
| Password | `askPassword(message, ...)` | `askPassword(PasswordPromptOptions)` | `string` |
| Confirmation | `askConfirm(message, ...)` | `askConfirm(ConfirmPromptOptions)` | `bool` |
| Single select | `askSelect(message, strings, ...)` | `askSelect(SelectPromptOptions[T])` | `T` |
| Multi-select | `askMultiSelect(message, strings, ...)` | `askMultiSelect(MultiSelectPromptOptions[T])` | `seq[T]` |

Convenience forms are intended for string choices and common defaults. Use an
options form for typed values, disabled choices, initial selections, custom
labels, validation, streams, presentation, or key bindings.

```nim
import std/options
import terminal_prompt

let target = askSelect(initSelectPromptOptions("Target", @[
  choice("Development", 1),
  choice("Staging", 2, hint = "recommended"),
  choice("Production", 3, disabled = true)
], initialIndex = some(1), wrapNavigation = false))
```

## Results

Every prompt returns `PromptResult[T]`. Inspect `status`, use
`isAnswered`/`isCancelled`/`isEndOfInput`, or use `valueOr` when cancellation
and EOF share a fallback. Read `value` only after confirming the result is
answered; otherwise it raises `PromptValueError`.

```nim
case target.status
of promptAnswered:
  echo target.value
of promptCancelled:
  echo "cancelled"
of promptEndOfInput:
  echo "input closed"
```

`answered`, `cancelled`, and `endOfInput` are available when adapting a prompt
result into another API. The string representation of an answered password
result is redacted, but `value` deliberately returns the secret.

## Shared options

Every options object contains:

- `presentation`, created with `defaultPresentation(helpText, theme)`;
- `runtime`, created with `defaultRuntimeOptions(input, output, keyBindings)`.

`PromptTheme` maps question, answer, selection, error, hint, and placeholder
roles to TerminalStyle values. `PromptKeyBindings` groups one or more exact
`PromptKeyBinding` values by action. A text binding includes its text payload
and modifiers, so Ctrl+S is represented as:

```nim
keyBinding(keyText, "s", {modifierCtrl})
```

Configured `File` streams are borrowed. TerminalPrompt flushes output but does
not close either file.

## Validation and choices

A `Validator[T]` returns `""` to accept or a user-facing message to retry.
Validator exceptions indicate application failures and propagate after prompt
cleanup. Password validators use stricter diagnostic handling; see
[security.md](security.md).

`choice(label, value, hint, disabled)` associates a display label with any
answer type. `initialIndex` and `initiallySelected` use zero-based indices,
while redirected users enter the one-based numbers displayed by the prompt.

For detailed state-machine behavior, see [prompts.md](prompts.md). Runtime
fallback and redraw rules are in [runtime.md](runtime.md), and the exception
contract is in [contracts.md](contracts.md).
