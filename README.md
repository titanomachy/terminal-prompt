# TerminalPrompt

Pure-Nim contracts for synchronous text, password, confirmation, single-select,
and multi-select prompts.

> [!IMPORTANT]
> Milestones 0 and 1 define and test the API contracts, safe session/input
> engine, line-mode fallback, and cursor-safe display lifecycle. The concrete
> prompt editors are not implemented yet; calling an `ask*` proc currently
> raises `PromptNotImplementedError`.

## Status

Milestones 0 and 1 are complete. They establish:

- explicit answered, cancelled, and end-of-input results;
- options-based and convenience prompt signatures;
- injectable I/O, renderer, key-event, and terminal-session contracts;
- an internal adapter for
  [TerminalScreen](https://github.com/titanomachy/terminal-screen);
- semantic themes backed directly by
  [TerminalStyle](https://github.com/titanomachy/terminal-style);
- compile-checked public API examples and deterministic contract tests;
- automatic plain line-mode fallback for redirected or limited terminals;
- binding-aware normalized input for editing, navigation, cancellation, EOF,
  timeout, and resize events;
- cell-aware in-place redraw with exception-safe display/session cleanup;
- reusable scripted I/O capture and POSIX PTY lifecycle coverage.

See [the contract documentation](docs/contracts.md) for the exception policy
and internal boundaries, and [the runtime documentation](docs/runtime.md) for
session modes, input actions, and redraw behavior. The remaining work is
tracked in [the implementation plan](PLANS/PLAN1.md).

## Installation

TerminalScreen is not yet listed in Nimble, so TerminalPrompt declares it by
GitHub URL. Because the repository has no `v0.1.0` tag yet, the dependency is
pinned to the verified 0.1.0 API commit instead of following a moving `HEAD`.
Nimble resolves it automatically:

```sh
nimble install https://github.com/titanomachy/terminal-prompt
```

For a source checkout, install dependencies before running the checks:

```sh
nimble install --depsOnly
nimble releaseCheck
```

During suite development, sibling checkouts can instead be linked with
`nimble develop`.

## Public API direction

The signatures below are compile-checked by `nimble examples`. They document
the API being implemented in Milestones 2 and 3.

```nim
import terminal_prompt

let name = askText("Project name", default = "my-project")
let secret = askPassword("Token")
let proceed = askConfirm("Continue?", default = false)
let color = askSelect("Color", ["Red", "Green", "Blue"])
let features = askMultiSelect("Features", ["Docs", "Tests", "Examples"])
```

Every call returns `PromptResult[T]`:

```nim
case name.status
of promptAnswered:
  echo name.value
of promptCancelled:
  echo "cancelled"
of promptEndOfInput:
  echo "input closed"
```

Cancellation and EOF are normal, separate outcomes. Requesting `.value` from
either raises `PromptValueError`; `.valueOr(fallback)` handles both without an
exception.

Typed options support validators, help text, themes, defaults, labels, typed
choices, custom `File` streams, and key bindings:

```nim
import std/options
import terminal_prompt

let portOptions = initSelectPromptOptions("Port", @[
  choice("HTTP", 80),
  choice("HTTPS", 443, hint = "recommended")
], initialIndex = some(1))

let port: PromptResult[int] = askSelect(portOptions)
```

Runtime settings remain backend-neutral even though the default implementation
uses TerminalScreen internally:

```nim
var bindings = defaultPromptKeyBindings()
bindings.submit.add keyBinding(keyText, "s", {modifierCtrl})

let options = initTextPromptOptions(
  "Name",
  runtime = defaultRuntimeOptions(
    input = stdin,
    output = stderr,
    keyBindings = bindings
  )
)
```

## Development

The supported floor is Nim 2.0.0. The full local check is:

```sh
nimble releaseCheck
```

Individual tasks are `nimble compilePackage`, `nimble test`,
`nimble examples`, and `nimble docs`. Compiler products and generated docs are
kept under `build/`.
