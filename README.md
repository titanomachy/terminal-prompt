# TerminalPrompt

Pure-Nim synchronous text, password, confirmation, single-select, and
multi-select prompts.

> [!IMPORTANT]
> Milestones 0 through 4 are complete. All five core prompt types work in
> interactive terminals and with redirected input/output, with compatibility
> coverage on Linux, macOS, and Windows.

## Status

Milestones 0 through 4 are complete. They establish:

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
- reusable scripted I/O capture and POSIX PTY lifecycle coverage;
- Unicode-aware text editing with defaults, placeholders, validation errors,
  and retries;
- masked or no-feedback password entry with validator and debug redaction;
- confirmations with configurable labels, unambiguous initial matching, and
  explicit defaults;
- single-select lists with defaults, disabled choices, optional navigation
  wrapping, resize-aware viewports, and one-based indexed fallback;
- multi-select lists with initial choices, toggle/select-all/clear actions,
  explicit submission, and comma- or space-separated indexed fallback;
- deterministic selection state-machine coverage and a POSIX PTY redraw smoke
  test that preserves surrounding output;
- logical-line fallback input that does not consume data intended for a later
  prompt.
- Linux, macOS, and Windows CI on the Nim 2.0 line and current stable Nim;
- explicit compatibility coverage for ANSI-disabled and redirected streams,
  narrow and resized terminals, Unicode labels, and large selection lists;
- compile-checked interactive and custom-runtime examples, a repeatable
  large-list benchmark, migration notes, and security guidance.

Start with [the public API reference](docs/api.md) and
[prompt behavior](docs/prompts.md). The [contract documentation](docs/contracts.md)
records result and exception policy, while [runtime documentation](docs/runtime.md)
describes session modes, input actions, and redraw behavior. Compatibility,
migration, and credential handling are covered in
[compatibility and performance](docs/compatibility.md),
[migration notes](docs/migration.md), and [security guidance](docs/security.md).
Release work remains tracked in [the implementation plan](PLANS/PLAN1.md).

## Installation

TerminalScreen is not yet listed in Nimble, so TerminalPrompt declares its
pre-release API by GitHub URL. The dependency is pinned to the verified
TerminalScreen revision containing its latest session/CI fixes, and Nimble
resolves it automatically:

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

## Public API

The signatures below are compile-checked by `nimble examples`.

```nim
import terminal_prompt

let name = askText("Project name", default = "my-project")
let secret = askPassword("Token")
let proceed = askConfirm("Continue?", default = false)
let color = askSelect("Color", ["Red", "Green", "Blue"])
let features = askMultiSelect("Features", ["Docs", "Tests", "Examples"])
```

Text prompts treat placeholders as display-only hints and use a configured
default only when the submitted editor is empty. Password prompts never render
the entered value and redact sensitive `PromptResult` debug output.

Single-select prompts use Up/Down and Enter in an interactive terminal.
Multi-select adds Space to toggle, `a` to select all enabled choices, `c` to
clear, and Enter for explicit submission. Home/End jump to the first/last
enabled choice, disabled choices are skipped, and navigation wraps by default.
Redirected input uses one-based choice numbers; multi-select accepts comma- or
space-separated numbers.

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
  choice("HTTPS", 443, hint = "recommended"),
  choice("Legacy", 8080, disabled = true)
], initialIndex = some(1), wrapNavigation = false)

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

See [examples/project_setup.nim](examples/project_setup.nim) for a complete
five-prompt setup flow and [examples/custom_runtime.nim](examples/custom_runtime.nim)
for custom bindings, typed choices, and explicit result handling.

## Compatibility and security

CI exercises Nim 2.0.x and stable Nim on Linux, macOS, and Windows. A prompt
uses interactive mode only when both streams are terminals and raw input plus
ANSI output are available. Otherwise it falls back to plain line-oriented I/O,
so pipes, files, limited consoles, and `TERM=dumb` remain usable.

Password entry does not echo its answer, and password results redact their
debug representation. The returned `.value` is still an ordinary Nim string;
applications must not log it and cannot assume secure erasure. Read the full
[security guidance](docs/security.md) before collecting credentials.

## Development

The supported floor is Nim 2.0.0. The full local check is:

```sh
nimble releaseCheck
```

Individual tasks are `nimble compilePackage`, `nimble test`,
`nimble examples`, `nimble docs`, and `nimble benchmark`. Compiler products and
generated docs are kept under `build/`. The benchmark measures viewport-backed
selection with up to 100,000 choices; filtering remains deferred until real
usage demonstrates that its additional interaction contract is justified.
