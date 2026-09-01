## Options, custom bindings, and explicit result handling.
##
## The procedure is compile-checked but not called, so examples can be checked
## in CI without waiting for terminal input.

import std/options

import terminal_prompt

proc customRuntimeExample() {.used.} =
  var bindings = defaultPromptKeyBindings()
  bindings.submit.add keyBinding(keyText, "s", {modifierCtrl})

  let runtime = defaultRuntimeOptions(
    input = stdin,
    output = stderr,
    keyBindings = bindings
  )
  let options = initSelectPromptOptions("Deployment target", @[
    choice("Staging", "staging", hint = "safe default"),
    choice("Production", "production")
  ], initialIndex = some(0), wrapNavigation = false,
    presentation = defaultPresentation("Ctrl+S also submits"),
    runtime = runtime)

  let response = askSelect(options)
  case response.status
  of promptAnswered:
    echo "target: ", response.value
  of promptCancelled:
    echo "cancelled"
  of promptEndOfInput:
    echo "input closed"
