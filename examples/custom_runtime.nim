## Options, custom bindings, and explicit result handling.
##
## This example is runnable. The examples task uses ``nim check``, so CI checks
## it without waiting for terminal input.

import std/options

import terminal_prompt

when isMainModule:
  var bindings = defaultPromptKeyBindings()
  bindings.submit.add keyBinding(keyText, "s", {modifierCtrl})

  let runtime = defaultRuntimeOptions(
    input = stdin,
    output = stderr,
    keyBindings = bindings
  )
  let promptOptions = initSelectPromptOptions("Deployment target", @[
    choice("Staging", "staging", hint = "safe default"),
    choice("Production", "production")
  ], initialIndex = some(0), wrapNavigation = false,
    presentation = defaultPresentation("Ctrl+S also submits"),
    runtime = runtime)

  let response = askSelect(promptOptions)
  case response.status
  of promptAnswered:
    echo "target: ", response.value
  of promptCancelled:
    echo "cancelled"
  of promptEndOfInput:
    echo "input closed"
