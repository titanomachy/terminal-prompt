# Migration notes

TerminalPrompt 0.1.0 is the first public release, so there is no earlier
TerminalPrompt API to upgrade from. These notes cover the common move from
direct `stdin` reads or prompt libraries that return a bare value.

## Handle cancellation and EOF explicitly

Replace code that treats an empty line as cancellation:

```nim
# Before
stdout.write "Name: "
let name = stdin.readLine()
if name.len == 0:
  quit("cancelled")

# With TerminalPrompt
let name = askText("Name")
case name.status
of promptAnswered:
  echo "Hello ", name.value # an empty answer remains valid
of promptCancelled:
  quit("cancelled")
of promptEndOfInput:
  quit("input closed")
```

Use `valueOr` only when cancellation and EOF intentionally have the same
meaning. Do not access `value` unconditionally.

## Move advanced arguments into options

The convenience overloads cover common string prompts. Migrate typed choices,
disabled entries, defaults, validators, custom streams, themes, and bindings to
the matching `init*PromptOptions` constructor. Selection defaults are
zero-based indices; line-mode answers remain one-based user input.

## Preserve non-interactive workflows

Code that previously accepted piped input does not need a separate prompt
path. Pass the desired `File` streams through `defaultRuntimeOptions`, or use
the default stdin/stdout streams. TerminalPrompt automatically switches to a
plain, line-oriented mode when either stream is redirected or ANSI/raw mode is
unavailable.

Each prompt consumes one logical line per attempt. Supply one line for each
prompt in scripts, including retries. Single-select expects one number and
multi-select accepts numbers separated by commas, spaces, or tabs.

## Treat password values as secrets

Replace echoed line input with `askPassword`. Do not log the returned `.value`,
interpolate it into exceptions, or retain it longer than needed. Review the
validator caveats and process-level limitations in [security.md](security.md).
