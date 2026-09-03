# TerminalPrompt

Pure-Nim synchronous text, password, confirmation, single-select, and
multi-select prompts.

## Platform support
`terminal_prompt` has been tested on Linux and Windows. On Windows I tested with the Terminal app which comes with Windows, other terminals may or may not work. It should also work on macOS through its standard POSIX terminal and ANSI/VT support, but macOS has not yet been tested directly.

## Requirements
- Nim 2.0.0 or newer
- [terminal_style](https://github.com/titanomachy/terminal-style) 0.1.1 or newer
- [terminal_screen](https://github.com/titanomachy/terminal-screen) 0.1.1 or newer
- No runtime dependencies beyond terminal_style

## Installation

Nimble installs both dependencies [terminal_style](https://github.com/titanomachy/terminal-screen) and [terminal_screen](https://github.com/titanomachy/terminal-screen) automatically:

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
for custom bindings, typed choices, and explicit result handling. Additional
examples cover [custom themes](examples/custom_theme.nim) and
[redirected automation](examples/redirected_workflow.nim).

## Documentation

- [Public API reference](docs/api.md)
- [Prompt behavior](docs/prompts.md)
- [Runtime, fallback, and cleanup](docs/runtime.md)
- [Compatibility and performance](docs/compatibility.md)
- [Migration notes](docs/migration.md)
- [Security guidance](docs/security.md)

## Compatibility and security

CI exercises Nim 2.0.x and stable Nim on Linux, macOS, and Windows using the
compiler's default memory manager, plus ARC and ORC on stable Nim/Linux. A
prompt uses interactive mode only when both streams are terminals and raw input
plus ANSI output are available. Otherwise it falls back to plain line-oriented
I/O, so pipes, files, limited consoles, and `TERM=dumb` remain usable. On
Windows, interactive mode uses native console events plus VT output; older or
limited consoles fall back to line mode.

Password entry does not echo its answer, and password results redact their
debug representation. The returned `.value` is still an ordinary Nim string;
applications must not log it and cannot assume secure erasure. Read the full
[security guidance](docs/security.md) before collecting credentials.

## Development

The supported floor is Nim 2.0.0. The full local check is:

```sh
nimble releaseCheck
```

Individual tasks are `nimble compilePackage`, `nimble test`, `nimble testArc`,
`nimble testOrc`, `nimble testMemoryManagers`, `nimble examples`, `nimble docs`,
and `nimble benchmark`. Compiler products and generated docs are kept under
`build/`; the test suite also checks the output location, source-tree
cleanliness, dependency constraints, and package exclusions. The benchmark
measures viewport-backed selection with up to 100,000 choices; filtering
remains deferred until real usage demonstrates that its additional interaction
contract is justified.
