## Compile-checked examples of the public API.
##
## This procedure is deliberately not called so compile checks remain
## non-interactive.

import std/options

import terminal_prompt

proc publicApiContracts() {.used.} =
  let name = askText("Project name", default = "my-project")
  let secret = askPassword("Token")
  let proceed = askConfirm("Continue?", default = false)
  let color = askSelect("Color", ["Red", "Green", "Blue"])
  let features = askMultiSelect("Features", ["Docs", "Tests", "Examples"])

  discard name.status
  discard secret.isCancelled
  discard proceed.valueOr(false)
  discard color.isEndOfInput
  discard features.status

  let validator: Validator[string] = proc(value: string): string =
    if value.len < 3: "Use at least three characters" else: ""

  var bindings = defaultPromptKeyBindings()
  bindings.submit.add keyBinding(keyText, "s", {modifierCtrl})

  let textOptions = initTextPromptOptions(
    "Package name",
    defaultValue = some("terminal-app"),
    placeholder = "my-package",
    validator = validator,
    presentation = defaultPresentation("Used in generated files"),
    runtime = defaultRuntimeOptions(input = stdin, output = stderr,
      keyBindings = bindings)
  )
  discard askText(textOptions)

  let selectOptions = initSelectPromptOptions("Port", @[
    choice("HTTP", 80),
    choice("HTTPS", 443, hint = "recommended"),
    choice("Legacy", 8080, disabled = true)
  ], initialIndex = some(1), wrapNavigation = false)
  let port: PromptResult[int] = askSelect(selectOptions)
  discard port

  let featureOptions = initMultiSelectPromptOptions("Features", @[
    choice("Documentation", "docs"),
    choice("Tests", "tests"),
    choice("Examples", "examples")
  ], initiallySelected = @[0, 1])
  let selected: PromptResult[seq[string]] = askMultiSelect(featureOptions)
  discard selected
